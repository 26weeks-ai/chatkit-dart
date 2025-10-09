import 'dart:async';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/actions/client_tools.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:chatkit_core/src/models/request.dart';
import 'package:test/test.dart';

import 'fixtures/streaming_fixture.dart';

class _ClientToolApiClient extends ChatKitApiClient {
  _ClientToolApiClient({required this.onSubmit})
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com'),
        );

  final void Function(ChatKitRequest request) onSubmit;
  int submissionCount = 0;

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    if (request.type == 'threads.get_by_id') {
      final threadId = request.params['thread_id'] as String? ?? 'thread_tool';
      return {
        'id': threadId,
        'title': 'Tool thread',
        'created_at': DateTime(2024).toUtc().toIso8601String(),
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
    if (request.type == 'threads.add_client_tool_output') {
      submissionCount += 1;
      onSubmit(request);
      onDone?.call();
      return;
    }
    onDone?.call();
  }
}

void main() {
  test('client tool invocation dispatches handler and submits result', () async {
    Map<String, Object?>? submittedPayload;
    String? submittedThreadId;
    final apiClient = _ClientToolApiClient(
      onSubmit: (request) {
        submittedThreadId = request.params['thread_id'] as String?;
        final resultParam = request.params['result'];
        if (resultParam is Map<String, Object?>) {
          submittedPayload = Map<String, Object?>.from(resultParam);
        }
      },
    );

    var handlerInvoked = false;
    final controller = ChatKitController(
      ChatKitOptions(
        api: const CustomApiConfig(url: 'https://example.com'),
        onClientTool: (invocation) async {
          handlerInvoked = true;
          expect(invocation.name, 'browser');
          expect(invocation.params['location'], 'Valencia');
          return {
            'status': 'ok',
            'summary': 'Fetched latest weather.',
          };
        },
      ),
      apiClient: apiClient,
    );
    addTearDown(controller.dispose);

    await controller.setThreadId('thread_tool');

    for (final json in clientToolFixtureEvents()) {
      controller.debugHandleStreamEvent(ThreadStreamEvent.fromJson(json));
    }

    // Allow async handler to complete.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(handlerInvoked, isTrue);
    expect(apiClient.submissionCount, 1);
    expect(submittedThreadId, 'thread_tool');
    expect(submittedPayload, isNotNull);
    expect(submittedPayload!['type'], 'success');
    final data = submittedPayload!['data'] as Map<String, Object?>?;
    expect(data, isNotNull);
    expect(data!['status'], 'ok');
    expect(data['summary'], 'Fetched latest weather.');
  });
}
