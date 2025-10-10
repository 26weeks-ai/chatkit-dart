import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_flutter/chatkit_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CoachDemoApp());
}

class CoachDemoApp extends StatelessWidget {
  const CoachDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatKit Coach Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const CoachDemoScreen(),
    );
  }
}

class CoachDemoScreen extends StatefulWidget {
  const CoachDemoScreen({super.key});

  @override
  State<CoachDemoScreen> createState() => _CoachDemoScreenState();
}

class _CoachDemoScreenState extends State<CoachDemoScreen> {
  late final ChatKitController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatKitController(_buildOptions());
  }

  ChatKitOptions _buildOptions() {
    return ChatKitOptions(
      api: const CustomApiConfig(
        url: 'http://localhost:8000/chatkit',
      ),
      history: const HistoryOption(
        enabled: true,
        showDelete: true,
        showRename: true,
      ),
      threadItemActions: const ThreadItemActionsOption(
        feedback: true,
        retry: true,
        share: true,
      ),
      startScreen: const StartScreenOption(
        greeting: 'What can Coach help you with today?',
        prompts: [
          const StartScreenPrompt(
            label: 'Plan a workout',
            prompt: 'Create a 30 minute HIIT session using body weight only.',
            icon: 'sparkle',
          ),
          const StartScreenPrompt(
            label: 'Healthy dinner ideas',
            prompt: 'Suggest three quick dinners under 600 calories.',
            icon: 'book-open',
          ),
        ],
      ),
      disclaimer: const DisclaimerOption(
        text:
            'Coach is a demo experience. Review any generated plan for accuracy before sharing.',
      ),
      composer: const ComposerOption(
        placeholder: 'Ask Coach anything…',
        attachments: const ComposerAttachmentOption(enabled: false),
        tools: const [
          ToolOption(
            id: 'browser',
            label: 'Browser',
            description: 'Search the web for current information',
            shortLabel: 'Web',
            placeholderOverride: 'Search the web for…',
          ),
          ToolOption(
            id: 'calendar',
            label: 'Calendar',
            description: 'Schedule sessions and reminders',
            shortLabel: 'Calendar',
          ),
        ],
        models: const [
          ModelOption(
            id: 'gpt-4o',
            label: 'GPT-4o',
            description: 'High quality reasoning',
            defaultSelected: true,
          ),
          ModelOption(
            id: 'gpt-4o-mini',
            label: 'GPT-4o mini',
            description: 'Faster, lower-latency responses',
          ),
        ],
      ),
      entities: EntitiesOption(
        onTagSearch: (query) async => _demoEntities
            .where(
              (entity) =>
                  entity.title.toLowerCase().contains(query.toLowerCase()),
            )
            .toList(),
        onClick: (entity) {
          debugPrint('Entity tapped: ${entity.title}');
        },
        onRequestPreview: (entity) async => EntityPreview(
          preview: _buildEntityPreview(entity),
        ),
      ),
      widgets: WidgetsOption(
        onAction: (action, widgetItem) async {
          debugPrint(
            'Widget action "${action.type}" from widget ${widgetItem.id}',
          );
        },
      ),
    );
  }

  static const List<Entity> _demoEntities = [
    Entity(
      id: 'client_ada',
      title: 'Ada Lovelace',
      group: 'Clients',
      data: {
        'kind': 'client',
        'description': 'Marathon trainee · weekly strength sessions',
      },
    ),
    Entity(
      id: 'plan_strength_01',
      title: 'Strength Plan · Phase 1',
      group: 'Plans',
      data: {
        'kind': 'plan',
        'description': '4 week foundational cycle',
      },
    ),
    Entity(
      id: 'resource_recovery',
      title: 'Recovery Guide',
      group: 'Resources',
      data: {
        'kind': 'resource',
        'description': 'Stretching and mobility routines',
      },
    ),
  ];

  static Map<String, Object?> _buildEntityPreview(Entity entity) {
    final description = entity.data['description'] as String?;
    return {
      'type': 'card',
      'children': [
        {
          'type': 'text',
          'value': entity.title,
          'size': 'lg',
          'weight': 'bold',
        },
        if (description != null)
          {
            'type': 'text',
            'value': description,
            'size': 'sm',
          },
        {
          'type': 'progress',
          'value': 0.6,
          'label': 'Completion progress',
        },
        {
          'type': 'button.group',
          'children': [
            {
              'type': 'button',
              'label': 'Open',
              'variant': 'solid',
              'action': {
                'type': 'open_entity',
                'payload': {'id': entity.id},
              },
            },
            {
              'type': 'button',
              'label': 'Assign',
              'variant': 'outline',
              'action': {
                'type': 'assign_entity',
                'payload': {'id': entity.id},
              },
            },
          ],
        },
      ],
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChatKitView(controller: _controller),
    );
  }
}
