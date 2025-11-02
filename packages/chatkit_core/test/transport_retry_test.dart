import 'dart:async';
import 'dart:io';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:test/test.dart';

class _RetryingApiClient extends ChatKitApiClient {
  _RetryingApiClient()
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com'),
        );

  final List<Duration> retryHints = [];
  int callCount = 0;

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    if (request.type == 'threads.get_by_id') {
      final threadId = request.params['thread_id'] as String? ?? 'thread_retry';
      return {
        'id': threadId,
        'title': 'Retry thread',
        'created_at': '2024-06-01T00:00:00Z',
        'status': {'type': 'active'},
        'items': {
          'data': <Map<String, Object?>>[],
          'after': null,
          'has_more': false,
        },
      };
    }
    return const {};
  }

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
    callCount += 1;
    if (callCount == 1) {
      const hint = Duration(milliseconds: 1500);
      onRetrySuggested?.call(hint);
      retryHints.add(hint);
      throw const SocketException('offline');
    }

    final item = ThreadItem(
      id: 'assistant_retry',
      threadId: 'thread_retry',
      createdAt: DateTime.utc(2024, 6, 2, 12),
      type: 'assistant_message',
      role: 'assistant',
      content: const [
        {'type': 'output_text', 'text': 'Retry succeeded.'},
      ],
      attachments: const [],
      metadata: const {},
      raw: const {
        'type': 'assistant_message',
        'content': [
          {'type': 'output_text', 'text': 'Retry succeeded.'},
        ],
      },
    );
    await onEvent(ThreadItemAddedEvent(item: item));
    await onEvent(ThreadItemDoneEvent(item: item));
    onDone?.call();
  }
}

void main() {
  test('sendUserMessage retries with server hint and logs retry details',
      () async {
    final client = _RetryingApiClient();
    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
        transport: TransportOption(
          initialBackoff: Duration(milliseconds: 20),
          maxBackoff: Duration(milliseconds: 40),
        ),
      ),
      apiClient: client,
    );
    addTearDown(controller.dispose);

    final events = <ChatKitEvent>[];
    final sub = controller.events.listen(events.add);
    addTearDown(() => sub.cancel());

    await controller.setThreadId('thread_retry');
    await controller.sendUserMessage(text: 'hello from dart');

    expect(client.callCount, 2);
    expect(client.retryHints, contains(const Duration(milliseconds: 1500)));

    final retryLogs = events.whereType<ChatKitLogEvent>().where(
          (event) =>
              event.name == 'transport.retry' &&
              event.data['server_hint_ms'] == 1500,
        );
    expect(retryLogs, isNotEmpty);

    final retryItem = controller.threadItemById('assistant_retry');
    expect(retryItem, isNotNull);
    expect(retryItem!.content.first['text'], 'Retry succeeded.');
  });

  test('sendUserMessage logs streaming latency metrics', () async {
    final client = _LatencyApiClient();
    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
      ),
      apiClient: client,
    );
    addTearDown(controller.dispose);

    final logEvents = <ChatKitLogEvent>[];
    final sub = controller.events.listen((event) {
      if (event is ChatKitLogEvent) {
        logEvents.add(event);
      }
    });
    addTearDown(() => sub.cancel());

    await controller.setThreadId('thread_latency');
    await controller.sendUserMessage(text: 'measure me');
    await Future<void>.delayed(Duration.zero);

    final names = logEvents.map((event) => event.name).toList();
    expect(names, contains('transport.streaming.start'));
    expect(names, contains('transport.streaming.first_event'));
    expect(names, contains('transport.streaming.complete'));

    final startLog = logEvents.lastWhere(
      (event) => event.name == 'transport.streaming.start',
    );
    final firstEventLog = logEvents.lastWhere(
      (event) => event.name == 'transport.streaming.first_event',
    );
    final completeLog = logEvents.lastWhere(
      (event) => event.name == 'transport.streaming.complete',
    );

    expect(startLog.data['request_type'], 'threads.add_user_message');
    expect(firstEventLog.data['request_type'], 'threads.add_user_message');
    expect(
      (completeLog.data['event_count'] as num?)?.toInt(),
      greaterThanOrEqualTo(2),
    );
    expect(
      (completeLog.data['duration_ms'] as num?)?.toInt(),
      greaterThanOrEqualTo(0),
    );
    expect(completeLog.data['status'], anyOf('success', 'queued'));
  });
}

class _LatencyApiClient extends ChatKitApiClient {
  _LatencyApiClient()
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com'),
        );

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    if (request.type == 'threads.get_by_id') {
      final threadId = request.params['thread_id'] as String? ?? 'thread_latency';
      return {
        'id': threadId,
        'title': 'Latency thread',
        'created_at': '2024-06-02T00:00:00Z',
        'status': {'type': 'active'},
        'items': {
          'data': <Map<String, Object?>>[],
          'after': null,
          'has_more': false,
        },
      };
    }
    return const {};
  }

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
    final item = ThreadItem(
      id: 'assistant_latency',
      threadId: 'thread_latency',
      createdAt: DateTime.utc(2024, 6, 2, 12),
      type: 'assistant_message',
      role: 'assistant',
      content: const [
        {'type': 'output_text', 'text': 'Latency measurement'},
      ],
      attachments: const [],
      metadata: const {},
      raw: const {
        'type': 'assistant_message',
        'content': [
          {'type': 'output_text', 'text': 'Latency measurement'},
        ],
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await onEvent(ThreadItemAddedEvent(item: item));
    await onEvent(ThreadItemDoneEvent(item: item));
    onDone?.call();
  }
}
