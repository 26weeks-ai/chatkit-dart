import 'dart:async';
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
  })  : _apiConfig = apiConfig,
        _httpClient = httpClient ?? http.Client(),
        _sseClient = SseClient(httpClient: httpClient ?? http.Client());

  final ChatKitApiConfig _apiConfig;
  final http.Client _httpClient;
  final SseClient _sseClient;

  String? _currentClientSecret;

  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    final uri = await _buildUri();
    final httpRequest = http.Request('POST', uri)
      ..headers[HttpHeaders.contentTypeHeader] = 'application/json'
      ..body = jsonEncode({
        ...request.toJson(),
        ...bodyOverrides,
      });

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
    try {
      await _sseClient.post(
        uri,
        body: {
          ...request.toJson(),
          ...bodyOverrides,
        },
        sendOverride: (req) => _sendRequest(req),
        keepAliveTimeout: keepAliveTimeout,
        onKeepAliveTimeout: onKeepAliveTimeout,
        onRetrySuggested: onRetrySuggested,
        onMessage: (message) async {
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
        onError: onError,
        onDone: onDone,
      );
    } on SocketException catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      rethrow;
    }
  }

  Future<void> close() async {
    _httpClient.close();
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
      case HostedApiConfig(:final getClientSecret):
        _currentClientSecret =
            await Future.value(getClientSecret(_currentClientSecret));
        request.headers['authorization'] = 'Bearer $_currentClientSecret';
      default:
        break;
    }
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
}
