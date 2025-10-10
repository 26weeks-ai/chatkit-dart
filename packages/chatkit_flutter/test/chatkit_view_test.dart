import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:chatkit_core/src/utils/json.dart';
import 'package:chatkit_flutter/chatkit_flutter.dart';
import 'package:chatkit_flutter/src/widgets/widget_renderer.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChatKitView renders start screen by default', (tester) async {
    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com/chatkit'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 600,
              width: 400,
              child: ChatKitView(controller: controller),
            ),
          ),
        ),
      ),
    );

    expect(find.text('What can I help with today?'), findsOneWidget);
    await controller.dispose();
  });

  testWidgets('History panel shows pinned section and search filters',
      (tester) async {
    final threads = <ThreadMetadata>[
      _thread(
        id: 'thread_pinned',
        title: 'Pinned Brainstorm',
        createdAt: DateTime(2024, 6, 10, 9),
        metadata: {
          'pinned': true,
          'keywords': ['brainstorm', 'roadmap'],
        },
      ),
      _thread(
        id: 'thread_recent',
        title: 'Quarterly Planning',
        createdAt: DateTime(2024, 6, 11, 12),
        metadata: {
          'keywords': ['planning'],
        },
      ),
      _thread(
        id: 'thread_shared',
        title: 'Shared Quarterly Update',
        createdAt: DateTime(2024, 6, 12, 8),
        metadata: {
          'shared': true,
          'keywords': ['shared update'],
        },
      ),
      _thread(
        id: 'thread_archived',
        title: 'Legacy Support',
        createdAt: DateTime(2024, 6, 1, 10),
        status: ThreadStatus.fromJson({'type': 'closed'}),
        metadata: {
          'keywords': ['legacy'],
        },
      ),
    ];

    final controller = _FakeChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
        history: HistoryOption(enabled: true),
        header: HeaderOption(),
      ),
      threads: threads,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 700,
              width: 900,
              child: ChatKitView(controller: controller),
            ),
          ),
        ),
      ),
    );

    // Open the history panel.
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Pinned Brainstorm'), findsOneWidget);
    expect(find.text('Legacy Support'), findsNothing);

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search conversations',
    );
    await tester.enterText(searchField, 'shared');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Shared Quarterly Update'), findsOneWidget);
    expect(find.text('Pinned Brainstorm'), findsNothing);

    await controller.dispose();
  });

  testWidgets('Entity picker supports keyboard navigation and selection',
      (tester) async {
    final entities = <Entity>[
      const Entity(
        id: 'entity_acme',
        title: 'Acme Inc.',
        data: {'description': 'Key account'},
      ),
      const Entity(
        id: 'entity_globex',
        title: 'Globex Corp',
        data: {'description': 'Supplier'},
      ),
      const Entity(
        id: 'entity_initech',
        title: 'Initech',
        data: {'description': 'Manufacturing partner'},
      ),
    ];

    final controller = ChatKitController(
      ChatKitOptions(
        api: const CustomApiConfig(url: 'https://example.com'),
        entities: EntitiesOption(
          onTagSearch: (query) => entities
              .where(
                (entity) =>
                    entity.title.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(),
        ),
        history: const HistoryOption(enabled: false),
      ),
      apiClient: _NoopApiClient(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 700,
              width: 900,
              child: ChatKitView(controller: controller),
            ),
          ),
        ),
      ),
    );

    // Open the entity picker via the composer shortcut button.
    await tester.tap(find.byTooltip('Add tag'));
    await tester.pumpAndSettle();

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search entities',
    );
    await tester.tap(searchField);
    await tester.pump();
    await tester.enterText(searchField, 'c');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    final acmeTile = find.widgetWithText(ListTile, 'Acme Inc.');
    expect(tester.widget<ListTile>(acmeTile).selected, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    final globexTile = find.widgetWithText(ListTile, 'Globex Corp');
    expect(tester.widget<ListTile>(acmeTile).selected, isFalse);
    expect(tester.widget<ListTile>(globexTile).selected, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(InputChip, 'Globex Corp'), findsOneWidget);

    await controller.dispose();
  });

  testWidgets('custom share target invokes handler and shows toast',
      (tester) async {
    ShareTargetInvocation? invocation;
    final controller = ChatKitController(
      ChatKitOptions(
        api: const CustomApiConfig(url: 'https://example.com'),
        threadItemActions: ThreadItemActionsOption(
          share: true,
          shareActions: ShareActionsOption(
            targets: const [
              ShareTargetOption(
                id: 'crm',
                label: 'Send to CRM',
                type: ShareTargetType.custom,
                toast: 'Shared to CRM.',
              ),
            ],
            onSelectTarget: (event) {
              invocation = event;
            },
          ),
        ),
      ),
      apiClient: _NoopApiClient(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatKitView(controller: controller),
        ),
      ),
    );

    final item = ThreadItem(
      id: 'item_1',
      threadId: 'thread_1',
      createdAt: DateTime(2024),
      type: 'assistant_message',
      role: 'assistant',
      content: const [
        {'type': 'output_text', 'text': 'Hello world'},
      ],
    );
    controller.debugHandleStreamEvent(ThreadItemAddedEvent(item: item));
    await tester.pump();

    final state = tester.state(find.byType(ChatKitView)) as dynamic;
    final target = const ShareTargetOption(
      id: 'crm',
      label: 'Send to CRM',
      type: ShareTargetType.custom,
      toast: 'Shared to CRM.',
    );

    await state.debugPerformShareTarget(
      target: target,
      shareText: 'Hello world',
      shareActions: ShareActionsOption(
        onSelectTarget: (event) {
          invocation = event;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(invocation, isNotNull);
    expect(invocation!.targetId, 'crm');
    expect(find.text('Shared to CRM.'), findsOneWidget);

    await controller.dispose();
  });

  testWidgets('default share workflow copies content and toasts',
      (tester) async {
    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
        threadItemActions: ThreadItemActionsOption(share: true),
      ),
      apiClient: _NoopApiClient(),
    );
    final events = <ChatKitEvent>[];
    final subscription = controller.events.listen(events.add);
    const channel = SystemChannels.platform;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );

    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await subscription.cancel();
      await controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatKitView(controller: controller),
        ),
      ),
    );

    final item = ThreadItem(
      id: 'share_item',
      threadId: 'thread_share',
      createdAt: DateTime(2024),
      type: 'assistant_message',
      role: 'assistant',
      content: const [
        {'type': 'text', 'text': 'Shareable insight about training.'},
      ],
    );
    controller.debugHandleStreamEvent(ThreadItemAddedEvent(item: item));
    await tester.pump();

    controller.shareItem(item.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      events.any(
        (event) => event is ChatKitShareEvent && event.itemId == item.id,
      ),
      isTrue,
    );

    var foundCopy = false;
    for (var i = 0; i < 10 && !foundCopy; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      foundCopy = find.text('Copy to clipboard').evaluate().isNotEmpty;
    }
    if (!foundCopy) {
      final debugTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .toList();
      // ignore: avoid_print
      print('available texts: ' + debugTexts.join(' | '));
    }
    expect(foundCopy, isTrue);
    await tester.tap(find.text('Copy to clipboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Message copied to clipboard.'), findsOneWidget);
  });

  testWidgets('Form submission nests payload keys', (tester) async {
    final controller = _CapturingController();
    final widgetJson = {
      'type': 'form',
      'onSubmitAction': {
        'type': 'form.submit',
        'label': 'Submit',
      },
      'children': [
        {
          'type': 'input',
          'name': 'profile.name',
          'label': 'Name',
        },
        {
          'type': 'input',
          'name': 'profile[address][city]',
          'label': 'City',
        },
        {
          'type': 'input',
          'name': 'phones[0]',
          'label': 'Primary Phone',
        },
        {
          'type': 'checkbox',
          'name': 'flags[marketing]',
          'label': 'Marketing Opt-in',
        },
      ],
    };

    final item = ThreadItem(
      id: 'item_form',
      threadId: 'thread_form',
      createdAt: DateTime(2024),
      type: 'widget',
      content: const [],
      attachments: const <ChatKitAttachment>[],
      metadata: const {},
      raw: {'widget': widgetJson},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ChatKitWidgetRenderer(
              widgetJson: widgetJson,
              controller: controller,
              item: item,
            ),
          ),
        ),
      ),
    );

    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Name',
    );
    final cityField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'City',
    );
    final phoneField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Primary Phone',
    );

    await tester.enterText(nameField, 'Alice');
    await tester.enterText(cityField, 'Paris');
    await tester.enterText(phoneField, '+33123456789');

    final marketingCheckbox =
        find.widgetWithText(CheckboxListTile, 'Marketing Opt-in');
    await tester.tap(marketingCheckbox);

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();

    final action = controller.lastAction;
    expect(action, isNotNull);
    final payload = castMap(action!['payload']);
    final form = castMap(payload['form']);
    final profile = castMap(form['profile']);
    final address = castMap(profile['address']);
    expect(profile['name'], 'Alice');
    expect(address['city'], 'Paris');

    final phones = (form['phones'] as List?)?.cast<Object?>() ?? const [];
    expect(phones, equals(['+33123456789']));

    final flags = castMap(form['flags']);
    expect(flags['marketing'], isTrue);

    final flat = castMap(payload['formFlat']);
    expect(flat['profile.name'], 'Alice');
    expect(flat['profile[address][city]'], 'Paris');

    await controller.dispose();
  });

  testWidgets('attachment ingestion and retry update composer state',
      (tester) async {
    final controller = _StubUploadController();
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChatKitView(controller: controller),
      ),
    );

    final state = tester.state(find.byType(ChatKitView)) as dynamic;
    state.debugSuppressSnackbars = true;
    await state.debugAddAttachment(
      name: 'sample.txt',
      bytes: Uint8List.fromList('hello'.codeUnits),
      mimeType: 'text/plain',
    );
    await tester.pump();

    expect(controller.composerState.attachments.length, 1);
    expect(controller.composerState.attachments.first.name, 'sample.txt');

    controller.failNextUpload = true;
    await state.debugAddAttachment(
      name: 'retry.txt',
      bytes: Uint8List.fromList('retry'.codeUnits),
      mimeType: 'text/plain',
    );
    await tester.pump();

    expect(controller.composerState.attachments.length, 1);
    expect(find.text('Attachment upload failed.'), findsOneWidget);
    expect(find.text('Retry upload'), findsOneWidget);

    controller.failNextUpload = false;
    final pendingUpload = (state.debugPendingUploads as List)
        .cast<dynamic>()
        .firstWhere((upload) => upload.error != null);
    await state.debugRetryUpload(pendingUpload);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(controller.composerState.attachments.length, 2);
    expect(
      controller.composerState.attachments.last.name,
      'retry.txt',
    );

    await controller.dispose();
  }, skip: true);
}

ThreadMetadata _thread({
  required String id,
  required String title,
  required DateTime createdAt,
  ThreadStatus? status,
  Map<String, Object?> metadata = const {},
}) {
  return ThreadMetadata(
    id: id,
    title: title,
    createdAt: createdAt,
    status: status ?? ThreadStatus.fromJson({'type': 'active'}),
    metadata: metadata,
  );
}

class _NoopApiClient extends ChatKitApiClient {
  _NoopApiClient()
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com'),
        );

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    throw UnimplementedError('Network calls are not supported in widget tests');
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
    throw UnimplementedError(
        'Streaming calls are not supported in widget tests');
  }

  @override
  Future<void> close() async {}
}

class _CapturingController extends ChatKitController {
  _CapturingController()
      : super(
          const ChatKitOptions(
            api: CustomApiConfig(url: 'https://example.com'),
          ),
          apiClient: _NoopApiClient(),
        );

  Map<String, Object?>? lastAction;
  String? lastItemId;

  @override
  Future<void> sendCustomAction(
    Map<String, Object?> action, {
    String? itemId,
  }) async {
    lastAction = action;
    lastItemId = itemId;
  }
}

class _FakeChatKitController extends ChatKitController {
  _FakeChatKitController(
    ChatKitOptions options, {
    required List<ThreadMetadata> threads,
  })  : _threads = threads,
        super(options, apiClient: _NoopApiClient());

  List<ThreadMetadata> _threads;

  @override
  Future<Page<ThreadMetadata>> listThreads({
    int limit = 20,
    String? after,
    String order = 'desc',
    String? section,
    String? query,
    bool? pinnedOnly,
    Map<String, Object?> metadata = const {},
  }) async {
    Iterable<ThreadMetadata> filtered = _threads;

    if (section != null && section.isNotEmpty) {
      final normalized = section.toLowerCase();
      filtered = filtered.where((thread) {
        final statusType = thread.status.type;
        if (normalized == 'archived') {
          return statusType == 'closed';
        }
        if (normalized == 'shared') {
          return _isShared(thread);
        }
        if (normalized == 'recent') {
          return statusType != 'closed';
        }
        return true;
      });
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((thread) {
        if ((thread.title ?? '').toLowerCase().contains(q)) {
          return true;
        }
        if (thread.id.toLowerCase().contains(q)) {
          return true;
        }
        final keywords = thread.metadata['keywords'];
        if (keywords is List) {
          for (final keyword in keywords) {
            if (keyword is String && keyword.toLowerCase().contains(q)) {
              return true;
            }
          }
        }
        final description = thread.metadata['description'];
        if (description is String && description.toLowerCase().contains(q)) {
          return true;
        }
        return false;
      });
    }

    if (pinnedOnly == true) {
      filtered = filtered.where(_isPinned);
    }

    final sorted = filtered.toList();
    if (order == 'desc') {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    if (after != null) {
      final index = sorted.indexWhere((thread) => thread.id == after);
      if (index != -1 && index + 1 < sorted.length) {
        sorted.removeRange(0, index + 1);
      } else if (index != -1) {
        sorted.clear();
      }
    }

    final items = sorted.take(limit).toList();
    final hasMore = sorted.length > limit;
    final nextAfter = hasMore ? items.last.id : null;

    return Page<ThreadMetadata>(
      data: items,
      hasMore: hasMore,
      after: nextAfter,
    );
  }

  bool _isPinned(ThreadMetadata thread) {
    final pinned = thread.metadata['pinned'];
    return _truthy(pinned);
  }

  bool _isShared(ThreadMetadata thread) {
    final shared = thread.metadata['shared'];
    if (_truthy(shared)) {
      return true;
    }
    final visibility = thread.metadata['visibility'];
    return visibility is String && visibility.toLowerCase() == 'shared';
  }

  bool _truthy(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'y';
    }
    return false;
  }
}

class _StubUploadController extends ChatKitController {
  _StubUploadController()
      : super(
          const ChatKitOptions(
            api: const CustomApiConfig(url: 'https://example.com'),
            composer: const ComposerOption(
              attachments: ComposerAttachmentOption(enabled: true),
            ),
          ),
          apiClient: _NoopApiClient(),
        );

  bool failNextUpload = false;

  @override
  Future<ChatKitAttachment> registerAttachment({
    required String name,
    required List<int> bytes,
    required String mimeType,
    int? size,
    void Function(int sentBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (failNextUpload) {
      failNextUpload = false;
      throw Exception('upload failed');
    }
    return FileAttachment(
      id: 'attachment_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      mimeType: mimeType,
      size: size,
    );
  }
}
