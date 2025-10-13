import 'dart:async';
import 'dart:io';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:test/test.dart';

class _FakeChatKitApiClient extends ChatKitApiClient {
  _FakeChatKitApiClient({
    this.failuresBeforeSuccess = 0,
    this.serverUserMessageType = 'user_message',
    this.serverUserMessageRole = 'user',
    this.emitPendingEcho = false,
    this.pendingIdResolver,
    List<Map<String, Object?>>? serverUserMessageContent,
  })  : serverUserMessageContent = serverUserMessageContent ??
            const [
              {'type': 'input_text', 'text': 'hello'},
            ],
        super(apiConfig: const CustomApiConfig(url: 'https://fake.local'));

  int failuresBeforeSuccess;
  final String serverUserMessageType;
  final String? serverUserMessageRole;
  final bool emitPendingEcho;
  final Future<String?> Function()? pendingIdResolver;
  final List<Map<String, Object?>> serverUserMessageContent;
  int streamingInvocations = 0;

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    if (request.type == 'threads.get_by_id') {
      final now = DateTime.now().toUtc().toIso8601String();
      final threadId = request.params['thread_id'] as String? ?? 'thread';
      return {
        'id': threadId,
        'title': 'Thread $threadId',
        'created_at': now,
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
    streamingInvocations += 1;
    if (streamingInvocations <= failuresBeforeSuccess) {
      throw const SocketException('offline');
    }

    if (request.type == 'threads.add_user_message') {
      final threadId = request.params['thread_id'] as String? ?? 'thread';
      if (emitPendingEcho) {
        final pendingId = await pendingIdResolver?.call();
        if (pendingId != null) {
          await onEvent(
            ThreadItemAddedEvent(
              item: ThreadItem(
                id: pendingId,
                threadId: threadId,
                createdAt: DateTime.now(),
                type: 'user_message',
                role: 'user',
                content: serverUserMessageContent,
                attachments: const [],
                metadata: const {'pending': true},
                raw: const {'pending': true},
              ),
            ),
          );
        }
      }
      await onEvent(
        ThreadItemAddedEvent(
          item: ThreadItem(
            id: 'msg_$streamingInvocations',
            threadId: threadId,
            createdAt: DateTime.now(),
            type: serverUserMessageType,
            role: serverUserMessageRole,
            content: serverUserMessageContent,
            attachments: const [],
            metadata: const {},
            raw: const {},
          ),
        ),
      );
    }
    onDone?.call();
  }
}

void main() {
  group('ChatKitController offline queue', () {
    test('queues streaming request and flushes when connectivity returns',
        () async {
      final apiClient = _FakeChatKitApiClient(failuresBeforeSuccess: 5);
      final controller = ChatKitController(
        const ChatKitOptions(api: CustomApiConfig(url: 'https://fake.local')),
        apiClient: apiClient,
      );
      addTearDown(controller.dispose);

      await controller.setThreadId('thread_1');
      expect(controller.threadItems, isEmpty);

      await controller.sendUserMessage(text: 'hello');

      expect(apiClient.streamingInvocations, greaterThanOrEqualTo(1));
      expect(controller.threadItems.length, greaterThanOrEqualTo(1));

      // Restore connectivity so the queued request can succeed.
      apiClient.failuresBeforeSuccess = 0;

      // Allow the queued request to retry.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(apiClient.streamingInvocations, greaterThanOrEqualTo(2));
      expect(
        controller.threadItems
            .where((item) => item.metadata['pending'] == true),
        isEmpty,
      );
      expect(
        controller.threadItems.where((item) => item.type == 'user_message'),
        isNotEmpty,
      );
    });
  });

  test(
      'removes pending placeholder when server emits generic user message type',
      () async {
    final apiClient = _FakeChatKitApiClient(serverUserMessageType: 'message');
    final controller = ChatKitController(
      const ChatKitOptions(api: CustomApiConfig(url: 'https://fake.local')),
      apiClient: apiClient,
    );
    addTearDown(controller.dispose);

    await controller.setThreadId('thread_generic_type');
    expect(controller.threadItems, isEmpty);

    await controller.sendUserMessage(text: 'hi');

    expect(
      controller.threadItems.where((item) => item.metadata['pending'] == true),
      isEmpty,
    );
    expect(
      controller.threadItems.where((item) => item.type == 'message'),
      isNotEmpty,
    );
  });

  test('removes pending placeholder when server omits user role', () async {
    final apiClient = _FakeChatKitApiClient(
      serverUserMessageRole: null,
      serverUserMessageContent: const [
        {'type': 'input_text', 'text': 'hi'},
      ],
    );
    final controller = ChatKitController(
      const ChatKitOptions(api: CustomApiConfig(url: 'https://fake.local')),
      apiClient: apiClient,
    );
    addTearDown(controller.dispose);

    await controller.setThreadId('thread_missing_role');
    expect(controller.threadItems, isEmpty);

    await controller.sendUserMessage(text: 'hi');

    expect(
      controller.threadItems.where((item) => item.metadata['pending'] == true),
      isEmpty,
    );
    expect(
      controller.threadItems.where((item) => item.role == null),
      isNotEmpty,
    );
  });

  test(
      'keeps pending placeholder until confirmed user message replaces it',
      () async {
    final pendingIdCompleter = Completer<String>();
    final apiClient = _FakeChatKitApiClient(
      emitPendingEcho: true,
      pendingIdResolver: () => pendingIdCompleter.future,
    );
    final controller = ChatKitController(
      const ChatKitOptions(api: CustomApiConfig(url: 'https://fake.local')),
      apiClient: apiClient,
    );
    addTearDown(controller.dispose);

    controller.events.listen((event) {
      if (pendingIdCompleter.isCompleted) {
        return;
      }
      if (event is ChatKitThreadEvent) {
        final streamEvent = event.streamEvent;
        if (streamEvent is ThreadItemAddedEvent &&
            streamEvent.item.metadata['pending'] == true) {
          pendingIdCompleter.complete(streamEvent.item.id);
        }
      }
    });

    await controller.setThreadId('thread_pending_echo');
    await controller.sendUserMessage(text: 'hello');

    final items = controller.threadItems;
    expect(
      items.where((item) => item.metadata['pending'] == true),
      isEmpty,
    );
    expect(
      items.where((item) => item.type == apiClient.serverUserMessageType),
      hasLength(1),
    );
  });

  test('removes correct pending placeholder when confirmations reorder',
      () async {
    final apiClient = _ImmediateDoneApiClient();
    final controller = ChatKitController(
      const ChatKitOptions(api: CustomApiConfig(url: 'https://fake.local')),
      apiClient: apiClient,
    );
    addTearDown(controller.dispose);

    await controller.setThreadId('thread_reorder');
    await controller.sendUserMessage(text: 'first');
    await controller.sendUserMessage(text: 'second');

    final pending = controller.threadItems
        .where((item) => item.metadata['pending'] == true)
        .toList();
    expect(pending, hasLength(2));
    final firstPending = pending[0];
    final secondPending = pending[1];

    controller.debugHandleStreamEvent(
      ThreadItemAddedEvent(
        item: ThreadItem(
          id: 'confirmed-second',
          threadId: secondPending.threadId,
          createdAt: DateTime.now(),
          type: 'user_message',
          role: 'user',
          content: secondPending.content,
          attachments: secondPending.attachments,
          metadata: const {},
          raw: const {},
        ),
      ),
    );

    controller.debugHandleStreamEvent(
      ThreadItemAddedEvent(
        item: ThreadItem(
          id: 'confirmed-first',
          threadId: firstPending.threadId,
          createdAt: DateTime.now(),
          type: 'user_message',
          role: 'user',
          content: firstPending.content,
          attachments: firstPending.attachments,
          metadata: const {},
          raw: const {},
        ),
      ),
    );

    expect(
      controller.threadItems.where((item) => item.metadata['pending'] == true),
      isEmpty,
    );
    expect(
      controller.threadItems
          .where((item) => item.type == 'user_message' && item.id.startsWith('confirmed-')),
      hasLength(2),
    );
  });
}

class _ImmediateDoneApiClient extends ChatKitApiClient {
  _ImmediateDoneApiClient()
      : super(apiConfig: const CustomApiConfig(url: 'https://fake.local'));

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    if (request.type == 'threads.get_by_id') {
      final threadId = request.params['thread_id'] as String? ?? 'thread';
      final now = DateTime.now().toUtc().toIso8601String();
      return {
        'id': threadId,
        'title': 'Thread $threadId',
        'created_at': now,
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
    onDone?.call();
  }
}
