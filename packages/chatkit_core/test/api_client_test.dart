import 'dart:async';
import 'dart:convert';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:chatkit_core/src/api/sse_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('ChatKitApiClient', () {
    test('refreshes hosted client secret once on 401 and retries request',
        () async {
      var attempts = 0;
      final observedAuthHeaders = <String>[];
      final client = MockClient((request) async {
        attempts += 1;
        observedAuthHeaders.add(request.headers['authorization'] ?? '');
        if (attempts == 1) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'auth_expired'}
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      var secretCalls = 0;
      final apiClient = ChatKitApiClient(
        apiConfig: HostedApiConfig(
          clientToken: 'secret-initial',
          getClientSecret: (current) async {
            secretCalls += 1;
            return 'secret-$secretCalls';
          },
        ),
        httpClient: client,
      );

      final response =
          await apiClient.send(const ChatKitRequest(type: 'noop_test'));

      expect(response, equals({'ok': true}));
      expect(attempts, 2);
      expect(secretCalls, 1);
      expect(
        observedAuthHeaders,
        equals(['Bearer secret-initial', 'Bearer secret-1']),
      );
    });

    test('attaches accept-language header when configured', () async {
      String? seenLanguage;
      final client = MockClient((request) async {
        seenLanguage = request.headers['accept-language'];
        return http.Response('{}', 200);
      });

      final apiClient = ChatKitApiClient(
        apiConfig: const CustomApiConfig(url: 'https://example.com/chat'),
        httpClient: client,
      );
      apiClient.acceptLanguage = 'fr-FR';

      await apiClient.send(const ChatKitRequest(type: 'noop_test'));

      expect(seenLanguage, 'fr-FR');
    });

    test('deduplicates streaming events by SSE id', () async {
      final received = <ProgressUpdateEvent>[];
      final sseClient = _FakeSseClient(({
        required Map<String, Object?> body,
        required SseMessageHandler onMessage,
        void Function(Object error, StackTrace stackTrace)? onError,
        void Function()? onDone,
        Duration? keepAliveTimeout,
        void Function()? onKeepAliveTimeout,
        void Function(Duration duration)? onRetrySuggested,
        Future<http.StreamedResponse> Function(http.Request request)?
            sendOverride,
      }) async {
        await onMessage(
          SseMessage(
            id: 'evt_1',
            data: jsonEncode({'type': 'progress_update', 'text': 'first'}),
          ),
        );
        await onMessage(
          SseMessage(
            id: 'evt_1',
            data: jsonEncode({'type': 'progress_update', 'text': 'ignored'}),
          ),
        );
        await onMessage(
          SseMessage(
            id: 'evt_2',
            data: jsonEncode({'type': 'progress_update', 'text': 'second'}),
          ),
        );
        onDone?.call();
      });

      final apiClient = ChatKitApiClient(
        apiConfig: const CustomApiConfig(url: 'https://example.com/chat'),
        sseClient: sseClient,
      );

      await apiClient.sendStreaming(
        const ChatKitRequest(type: 'threads.create'),
        onEvent: (event) {
          if (event is ProgressUpdateEvent) {
            received.add(event);
          }
        },
      );

      expect(received.length, 2);
      expect(received.first.text, 'first');
      expect(received.last.text, 'second');
    });
  });
}

class _FakeSseClient extends SseClient {
  _FakeSseClient(
    this.handler,
  ) : super(httpClient: http.Client());

  final Future<void> Function({
    required Map<String, Object?> body,
    required SseMessageHandler onMessage,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
    Duration? keepAliveTimeout,
    void Function()? onKeepAliveTimeout,
    void Function(Duration duration)? onRetrySuggested,
    Future<http.StreamedResponse> Function(http.Request request)? sendOverride,
  }) handler;

  @override
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
  }) {
    return handler(
      body: body,
      onMessage: onMessage,
      onError: onError,
      onDone: onDone,
      keepAliveTimeout: keepAliveTimeout,
      onKeepAliveTimeout: onKeepAliveTimeout,
      onRetrySuggested: onRetrySuggested,
      sendOverride: sendOverride,
    );
  }
}
