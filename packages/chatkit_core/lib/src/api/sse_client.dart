import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class SseMessage {
  SseMessage({
    this.event,
    this.id,
    this.data,
    this.retry,
  });

  final String? event;
  final String? id;
  final String? data;
  final Duration? retry;
}

typedef SseMessageHandler = FutureOr<void> Function(SseMessage message);

class SseClient {
  SseClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<void> post(
    Uri uri, {
    required Map<String, Object?> body,
    Map<String, String>? headers,
    required SseMessageHandler onMessage,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
    Duration? keepAliveTimeout,
    void Function()? onKeepAliveTimeout,
    void Function(Duration duration)? onRetrySuggested,
    Future<http.StreamedResponse> Function(http.Request request)? sendOverride,
  }) async {
    final request = http.Request('POST', uri)
      ..headers.addAll({
        HttpHeaders.contentTypeHeader: 'application/json',
        if (headers != null) ...headers,
      })
      ..body = jsonEncode(body);

    http.StreamedResponse? response;
    try {
      if (sendOverride != null) {
        response = await sendOverride(request);
      } else {
        response = await _httpClient.send(request);
      }
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      rethrow;
    }

    final contentType = response.headers[HttpHeaders.contentTypeHeader];
    if (contentType == null || !contentType.contains('text/event-stream')) {
      final bytes = await response.stream.toBytes();
      final text = utf8.decode(bytes);
      onError?.call(
        HttpException(
          'Expected text/event-stream response, got $contentType with body: $text',
          uri: uri,
        ),
        StackTrace.current,
      );
      return;
    }

    final controller = StreamController<SseMessage>();
    Timer? keepAliveTimer;
    bool streamClosed = false;

    void cancelTimer() {
      keepAliveTimer?.cancel();
      keepAliveTimer = null;
    }

    late final StreamSubscription<String> responseSubscription;

    void resetTimer() {
      if (keepAliveTimeout == null) {
        return;
      }
      cancelTimer();
      keepAliveTimer = Timer(keepAliveTimeout, () {
        final timeout = TimeoutException(
          'SSE keepalive timed out after ${keepAliveTimeout.inSeconds}s',
          keepAliveTimeout,
        );
        onKeepAliveTimeout?.call();
        if (!controller.isClosed) {
          controller.addError(timeout, StackTrace.current);
          _builder = _SseMessageBuilder();
          controller.close();
        }
        unawaited(responseSubscription.cancel());
      });
    }

    responseSubscription = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        resetTimer();
        _handleLine(line, controller);
      },
      onError: (Object error, StackTrace stackTrace) {
        cancelTimer();
        onError?.call(error, stackTrace);
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
          controller.close();
        }
        unawaited(responseSubscription.cancel());
      },
      onDone: () {
        cancelTimer();
        final message = _builder.build();
        if (message != null) {
          controller.add(message);
        }
        _builder = _SseMessageBuilder();
        streamClosed = true;
        controller.close();
        onDone?.call();
      },
      cancelOnError: true,
    );

    resetTimer();

    await controller.stream.listen(
      (message) async {
        if (message.retry != null) {
          onRetrySuggested?.call(message.retry!);
        }
        final eventName = message.event?.toLowerCase();
        final data = message.data?.trim().toLowerCase();
        if (eventName == 'ping' ||
            eventName == 'heartbeat' ||
            data == 'ping' ||
            data == 'pong' ||
            data == 'heartbeat') {
          return;
        }
        await Future<void>.value(onMessage(message));
      },
      onError: (error, stackTrace) {
        cancelTimer();
        onError?.call(error, stackTrace);
      },
      onDone: () {
        cancelTimer();
        if (!streamClosed) {
          controller.close();
        }
      },
      cancelOnError: true,
    ).asFuture<void>();

    await responseSubscription.cancel();
    cancelTimer();
  }

  void _handleLine(String line, StreamController<SseMessage> controller) {
    if (line.isEmpty) {
      final message = _builder.build();
      if (message != null) {
        controller.add(message);
      }
      _builder = _SseMessageBuilder();
      return;
    }

    if (line.startsWith(':')) {
      return;
    }

    final separatorIndex = line.indexOf(':');
    String field;
    String value;
    if (separatorIndex == -1) {
      field = line;
      value = '';
    } else {
      field = line.substring(0, separatorIndex);
      value = line.substring(separatorIndex + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
    }

    switch (field) {
      case 'event':
        _builder.event = value;
        break;
      case 'data':
        _builder.addData(value);
        break;
      case 'id':
        _builder.id = value;
        break;
      case 'retry':
        final retry = int.tryParse(value);
        if (retry != null) {
          _builder.retry = Duration(milliseconds: retry);
        }
        break;
    }
  }

  _SseMessageBuilder _builder = _SseMessageBuilder();
}

class _SseMessageBuilder {
  String? event;
  String? id;
  Duration? retry;
  final StringBuffer _data = StringBuffer();

  void addData(String value) {
    if (_data.isNotEmpty) {
      _data.write('\n');
    }
    _data.write(value);
  }

  SseMessage? build() {
    if (event == null && id == null && _data.isEmpty) {
      return null;
    }
    return SseMessage(
      event: event,
      id: id,
      data: _data.isEmpty ? null : _data.toString(),
      retry: retry,
    );
  }
}
