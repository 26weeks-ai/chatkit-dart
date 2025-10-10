import 'dart:async';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:test/test.dart';

void main() {
  group('ChatKitController', () {
    test('fetchUpdates reloads active thread even when id is unchanged',
        () async {
      final responses = [
        _threadResponse(
          id: 'thr_1',
          itemId: 'item_initial',
          createdAt: '2024-01-01T00:00:00Z',
          text: 'first',
        ),
        _threadResponse(
          id: 'thr_1',
          itemId: 'item_updated',
          createdAt: '2024-01-01T00:00:01Z',
          text: 'second',
        ),
      ];
      final apiClient = _RecordingApiClient(responses);
      final controller = ChatKitController(
        ChatKitOptions(
          api: const CustomApiConfig(url: 'https://example.com/chat'),
        ),
        apiClient: apiClient,
      );

      await controller.setThreadId('thr_1');
      expect(apiClient.requestTypes, ['threads.get_by_id']);
      expect(
        controller.threadItems.first.content.first['text'],
        equals('first'),
      );

      apiClient.requestTypes.clear();
      await controller.fetchUpdates();
      expect(apiClient.requestTypes, ['threads.get_by_id']);
      expect(
        controller.threadItems.first.content.first['text'],
        equals('second'),
      );

      await controller.dispose();
    });

    test('setThreadId throws ChatKitBusyException while streaming', () async {
      final apiClient = _BlockingApiClient();
      final controller = ChatKitController(
        ChatKitOptions(
          api: const CustomApiConfig(url: 'https://example.com/chat'),
        ),
        apiClient: apiClient,
      );

      final sendFuture = controller.sendUserMessage(text: 'hi');
      await apiClient.started.future;

      await expectLater(
        controller.setThreadId('thr_2'),
        throwsA(isA<ChatKitStreamingInProgressException>()),
      );

      apiClient.complete();
      await expectLater(sendFuture, completes);
      await controller.dispose();
    });

    test('backgrounding prevents new streaming requests', () async {
      final controller = ChatKitController(
        ChatKitOptions(
          api: const CustomApiConfig(url: 'https://example.com/chat'),
        ),
        apiClient: _RecordingApiClient(const []),
      );

      controller.handleAppBackgrounded();
      await expectLater(
        controller.sendUserMessage(text: 'hi'),
        throwsA(isA<ChatKitBusyException>()),
      );

      controller.handleAppForegrounded(forceRefresh: true);
      await controller.dispose();
    });

    test('foreground triggers debounced fetch after backgrounding', () async {
      final responses = [
        _threadResponse(
          id: 'thr_foreground',
          itemId: 'item_1',
          createdAt: '2024-01-01T00:00:00Z',
          text: 'hello',
        ),
      ];
      final apiClient = _RecordingApiClient(responses);
      final controller = ChatKitController(
        ChatKitOptions(
          api: const CustomApiConfig(url: 'https://example.com/chat'),
        ),
        apiClient: apiClient,
      );

      final thread = Thread(
        metadata: ThreadMetadata(
          id: 'thr_foreground',
          title: 'Foreground test',
          createdAt: DateTime(2024),
          status: ThreadStatus.fromJson({'type': 'active'}),
        ),
        items: const [],
        after: null,
        hasMore: false,
      );
      controller.debugHandleStreamEvent(ThreadCreatedEvent(thread: thread));

      controller.handleAppBackgrounded();
      controller.handleAppForegrounded();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(apiClient.requestTypes, contains('threads.get_by_id'));

      apiClient.requestTypes.clear();
      controller.handleAppForegrounded();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(apiClient.requestTypes, isEmpty);

      await controller.dispose();
    });

    test('backgrounding cancels active stream via api client', () async {
      final apiClient = _CancelableApiClient();
      final controller = ChatKitController(
        ChatKitOptions(
          api: const CustomApiConfig(url: 'https://example.com/chat'),
        ),
        apiClient: apiClient,
      );

      controller.handleAppBackgrounded();

      expect(apiClient.cancelled, isTrue);

      await controller.dispose();
    });
  });
}

class _RecordingApiClient extends ChatKitApiClient {
  _RecordingApiClient(this._responses)
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com/chat'),
        );

  final List<Map<String, Object?>> _responses;
  final List<String> requestTypes = [];
  int _cursor = 0;

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    requestTypes.add(request.type);
    final response = _responses[_cursor];
    if (_cursor < _responses.length - 1) {
      _cursor += 1;
    }
    return response;
  }
}

class _BlockingApiClient extends ChatKitApiClient {
  _BlockingApiClient()
      : started = Completer<void>(),
        _finish = Completer<void>(),
        super(
          apiConfig: const CustomApiConfig(url: 'https://example.com/chat'),
        );

  final Completer<void> started;
  final Completer<void> _finish;

  @override
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
    if (!started.isCompleted) {
      started.complete();
    }
    await _finish.future;
    onDone?.call();
  }

  void complete() {
    if (!_finish.isCompleted) {
      _finish.complete();
    }
  }
}

class _CancelableApiClient extends ChatKitApiClient {
  _CancelableApiClient()
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com/chat'),
        );

  bool cancelled = false;

  @override
  void cancelActiveStream() {
    cancelled = true;
    super.cancelActiveStream();
  }
}

Map<String, Object?> _threadResponse({
  required String id,
  required String itemId,
  required String createdAt,
  required String text,
}) {
  return {
    'id': id,
    'created_at': createdAt,
    'status': {'type': 'active'},
    'items': {
      'data': [
        {
          'id': itemId,
          'thread_id': id,
          'created_at': createdAt,
          'type': 'assistant_message',
          'role': 'assistant',
          'content': [
            {'type': 'output_text', 'text': text},
          ],
        },
      ],
      'after': null,
      'has_more': false,
    },
  };
}
