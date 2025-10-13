import 'dart:async';
import 'dart:io';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:test/test.dart';

class _FakeChatKitApiClient extends ChatKitApiClient {
  _FakeChatKitApiClient({this.failuresBeforeSuccess = 0})
      : super(apiConfig: const CustomApiConfig(url: 'https://fake.local'));

  int failuresBeforeSuccess;
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
      await onEvent(
        ThreadItemAddedEvent(
          item: ThreadItem(
            id: 'msg_$streamingInvocations',
            threadId: threadId,
            createdAt: DateTime.now(),
            type: 'user_message',
            role: 'user',
            content: const [],
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
}
