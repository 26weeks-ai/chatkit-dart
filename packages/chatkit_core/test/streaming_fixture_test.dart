import 'dart:async';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:test/test.dart';

import 'fixtures/streaming_fixture.dart';

class _NoopApiClient extends ChatKitApiClient {
  _NoopApiClient()
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com'),
        );
}

void main() {
  test('applies streaming fixture updates and emits response lifecycle events',
      () async {
    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
      ),
      apiClient: _NoopApiClient(),
    );
    addTearDown(controller.dispose);

    final events = <ChatKitEvent>[];
    final sub = controller.events.listen(events.add);
    addTearDown(() => sub.cancel());

    for (final json in streamingFixtureEvents()) {
      controller.debugHandleStreamEvent(ThreadStreamEvent.fromJson(json));
    }

    await Future<void>.delayed(Duration.zero);

    final assistant = controller.threadItemById('msg_assistant');
    expect(assistant, isNotNull);

    final firstContent =
        assistant!.content.isNotEmpty ? assistant.content.first : null;
    expect(firstContent, isNotNull);
    expect(firstContent!['text'], 'Hello athlete! Here is your summary.');

    final annotations = firstContent['annotations'];
    expect(annotations, isA<List>());
    final annotationIds = (annotations as List)
        .whereType<Map>()
        .map((entry) => entry['file_id'])
        .toList();
    expect(annotationIds, contains('file_weekly_plan'));

    final widgetJson = (assistant.raw['widget'] as Map).cast<String, Object?>();
    final children = (widgetJson['children'] as List)
        .map((child) => (child as Map).cast<String, Object?>())
        .toList();
    final streamText = children.firstWhere(
      (child) => child['id'] == 'stream_text',
      orElse: () => {},
    );
    expect(
      streamText['value'],
      'Focus: Recovery mobility\nNext: Long run Saturday',
    );
    expect(streamText['streaming'], isFalse);

    final responseStartIndex =
        events.indexWhere((event) => event is ChatKitResponseStartEvent);
    final responseEndIndex =
        events.indexWhere((event) => event is ChatKitResponseEndEvent);
    expect(responseStartIndex, isNot(-1));
    expect(responseEndIndex, isNot(-1));
    expect(responseStartIndex, lessThan(responseEndIndex));

    final progressEvents = events
        .whereType<ChatKitThreadEvent>()
        .map((event) => event.streamEvent)
        .whereType<ProgressUpdateEvent>()
        .toList();
    expect(progressEvents, hasLength(1));
    expect(progressEvents.first.text, 'Summaries compiled');
  });

  test('workflow task updates mutate workflow structure', () async {
    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
      ),
      apiClient: _NoopApiClient(),
    );
    addTearDown(controller.dispose);

    for (final json in workflowFixtureEvents()) {
      controller.debugHandleStreamEvent(ThreadStreamEvent.fromJson(json));
    }

    final item = controller.threadItemById('workflow_item');
    expect(item, isNotNull);

    final workflow = (item!.raw['workflow'] as Map?)?.cast<String, Object?>();
    expect(workflow, isNotNull);

    final tasks = (workflow!['tasks'] as List?)?.cast<Map<String, Object?>>();
    expect(tasks, isNotNull);
    expect(tasks, isNotEmpty);

    final task = tasks!.first;
    expect(task['id'], 'task_collect_inputs');
    expect(task['status'], 'complete');
    expect(task['notes'], 'All questionnaires answered.');
  });
}
