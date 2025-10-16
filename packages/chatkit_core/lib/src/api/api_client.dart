import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../options.dart';
import '../utils/json.dart';
import 'sse_client.dart';

typedef StreamEventCallback = FutureOr<void> Function(ThreadStreamEvent event);

class ChatKitApiClient {
  ChatKitApiClient({
    required ChatKitApiConfig apiConfig,
    http.Client? httpClient,
    SseClient? sseClient,
  })  : _apiConfig = apiConfig,
        _httpClient = httpClient ?? http.Client(),
        _sseClient =
            sseClient ?? SseClient(httpClient: httpClient ?? http.Client()),
        _currentClientSecret = switch (apiConfig) {
          HostedApiConfig(:final clientToken) => clientToken,
          _ => null,
        };

  final ChatKitApiConfig _apiConfig;
  final http.Client _httpClient;
  final SseClient _sseClient;

  String? _currentClientSecret;
  Future<String>? _refreshingClientSecret;
  String? _acceptLanguage;

  String? get acceptLanguage => _acceptLanguage;

  set acceptLanguage(String? value) {
    final trimmed = value?.trim();
    _acceptLanguage = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    final uri = await _buildUri();
    final payload = {
      ...request.toJson(),
      ...bodyOverrides,
    };
    final body = jsonEncode(payload);
    var attemptedAuthRefresh = false;

    while (true) {
      final httpRequest = http.Request('POST', uri)
        ..headers[HttpHeaders.contentTypeHeader] = 'application/json'
        ..body = body;

      try {
        final streamedResponse = await _sendRequest(httpRequest);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ChatKitServerException(
            'Request failed with status ${response.statusCode}',
            statusCode: response.statusCode,
            error: castMap(
              response.body.isNotEmpty ? jsonDecode(response.body) : null,
            ),
          );
        }

        if (response.body.isEmpty) {
          return const {};
        }

        final json = jsonDecode(response.body);
        return castMap(json);
      } on ChatKitServerException catch (error) {
        if (_canAttemptHostedRefresh(error.statusCode) &&
            !attemptedAuthRefresh) {
          attemptedAuthRefresh = true;
          final refreshed = await _tryRefreshHostedSecret();
          if (refreshed) {
            continue;
          }
        }
        rethrow;
      }
    }
  }

  Future<void> sendStreaming(
    ChatKitRequest request, {
    required StreamEventCallback onEvent,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration? keepAliveTimeout,
    void Function()? onKeepAliveTimeout,
    void Function(Duration duration)? onRetrySuggested,
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    final uri = await _buildUri();
    final payload = {
      ...request.toJson(),
      ...bodyOverrides,
    };
    final Set<String> recentEventIds = LinkedHashSet<String>();
    const maxTrackedEventIds = 64;
    var attemptedAuthRefresh = false;

    while (true) {
      var shouldRetryAuth = false;
      try {
        await _sseClient.post(
          uri,
          body: payload,
          sendOverride: (req) => _sendRequest(req),
          keepAliveTimeout: keepAliveTimeout,
          onKeepAliveTimeout: onKeepAliveTimeout,
          onRetrySuggested: onRetrySuggested,
          onMessage: (message) async {
            final eventId = message.id;
            if (eventId != null && eventId.isNotEmpty) {
              final added = recentEventIds.add(eventId);
              if (!added) {
                return;
              }
              if (recentEventIds.length > maxTrackedEventIds) {
                recentEventIds.remove(recentEventIds.first);
              }
            }

            final data = message.data;
            if (data == null || data.isEmpty) {
              return;
            }

            final decoded = jsonDecode(data);
            if (decoded is List) {
              for (final entry in decoded) {
                await onEvent(ThreadStreamEvent.fromJson(castMap(entry)));
              }
            } else if (decoded is Map<String, Object?>) {
              await onEvent(ThreadStreamEvent.fromJson(decoded));
            }
          },
          onError: (error, stackTrace) {
            if (error is ChatKitServerException &&
                _canAttemptHostedRefresh(error.statusCode) &&
                !attemptedAuthRefresh) {
              shouldRetryAuth = true;
              return;
            }
            onError?.call(error, stackTrace);
          },
          onDone: onDone,
        );
      } on SocketException catch (error, stackTrace) {
        onError?.call(error, stackTrace);
        rethrow;
      }

      if (shouldRetryAuth) {
        attemptedAuthRefresh = true;
        recentEventIds.clear();
        final refreshed = await _tryRefreshHostedSecret();
        if (refreshed) {
          continue;
        }
        final unauthorized = ChatKitServerException(
          'Request failed with status 401',
          statusCode: 401,
        );
        onError?.call(unauthorized, StackTrace.current);
      }
      break;
    }
  }

  Future<void> close() async {
    _httpClient.close();
  }

  void cancelActiveStream() {
    _sseClient.cancelActive();
  }

  Future<Uri> _buildUri() async {
    return switch (_apiConfig) {
      CustomApiConfig(:final url) => Uri.parse(url),
      HostedApiConfig() => Uri.parse('https://api.openai.com/v1/chatkit'),
      _ => Uri.parse('https://api.openai.com/v1/chatkit'),
    };
  }

  Future<void> _applyHeaders(http.BaseRequest request) async {
    request.headers.putIfAbsent(
      HttpHeaders.contentTypeHeader,
      () => 'application/json',
    );
    request.headers.putIfAbsent(
      'accept',
      () => 'application/json, text/event-stream',
    );
    request.headers['x-chatkit-sdk'] = 'chatkit-dart';
    final language = _acceptLanguage;
    if (language != null && language.isNotEmpty) {
      request.headers[HttpHeaders.acceptLanguageHeader] = language;
    }

    switch (_apiConfig) {
      case CustomApiConfig(:final domainKey, :final headersBuilder):
        if (domainKey != null) {
          request.headers['x-chatkit-domain-key'] = domainKey;
        }
        if (headersBuilder != null) {
          final extra = await Future.value(headersBuilder(request));
          if (extra.isNotEmpty) {
            request.headers.addAll(extra);
          }
        }
      // fetchOverride handled in _sendRequest
      case HostedApiConfig():
        await _ensureHostedCredentials();
        final secret = _currentClientSecret;
        if (secret == null || secret.isEmpty) {
          throw ChatKitConfigurationException(
            'Hosted API client secret is not available.',
          );
        }
        request.headers['authorization'] = 'Bearer $secret';
        break;
      default:
        break;
    }
  }

  Future<void> _ensureHostedCredentials({bool forceRefresh = false}) async {
    final config = _hostedConfig;
    if (config == null) {
      return;
    }

    if (!forceRefresh &&
        _currentClientSecret != null &&
        _currentClientSecret!.isNotEmpty) {
      return;
    }

    final getter = config.getClientSecret;
    if (getter == null) {
      final token = config.clientToken;
      if (token == null || token.isEmpty) {
        throw ChatKitConfigurationException(
          'HostedApiConfig requires a clientToken or getClientSecret callback.',
        );
      }
      _currentClientSecret = token;
      return;
    }

    if (!forceRefresh && _refreshingClientSecret != null) {
      _currentClientSecret = await _refreshingClientSecret!;
      return;
    }

    final future = Future<String>.value(getter(_currentClientSecret));
    if (!forceRefresh) {
      _refreshingClientSecret = future;
    }

    try {
      final secret = await future;
      if (secret.isEmpty) {
        throw ChatKitConfigurationException(
          'Hosted client secret callback returned an empty value.',
        );
      }
      _currentClientSecret = secret;
    } finally {
      if (!forceRefresh && identical(_refreshingClientSecret, future)) {
        _refreshingClientSecret = null;
      }
    }
  }

  Future<bool> _tryRefreshHostedSecret() async {
    final config = _hostedConfig;
    if (config == null) {
      return false;
    }
    if (config.getClientSecret == null) {
      return false;
    }
    await _ensureHostedCredentials(forceRefresh: true);
    return _currentClientSecret != null && _currentClientSecret!.isNotEmpty;
  }

  bool _canAttemptHostedRefresh(int? statusCode) {
    if (statusCode != 401) {
      return false;
    }
    final config = _hostedConfig;
    if (config == null) {
      return false;
    }
    return config.getClientSecret != null;
  }

  Future<http.StreamedResponse> _sendRequest(http.Request request) async {
    await _applyHeaders(request);
    if (_apiConfig case CustomApiConfig(:final fetchOverride)) {
      if (fetchOverride != null) {
        return await Future.value(fetchOverride(request));
      }
    }
    return _httpClient.send(request);
  }

  HostedApiConfig? get _hostedConfig {
    final config = _apiConfig;
    return config is HostedApiConfig ? config : null;
  }
}
