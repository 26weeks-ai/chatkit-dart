import 'dart:convert';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:chatkit_flutter/src/widgets/widget_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopApiClient extends ChatKitApiClient {
  _NoopApiClient()
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com'),
        );
}

Map<String, Object?> _deepCopy(Map<String, Object?> value) {
  return (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
}

final Map<String, Object?> _dashboardWidget = <String, Object?>{
  'id': 'weekly_summary',
  'type': 'card',
  'size': 'lg',
  'padding': 'lg',
  'background': '#FFFFFF',
  'children': <Map<String, Object?>>[
    <String, Object?>{
      'type': 'row',
      'gap': 'md',
      'align': 'center',
      'justify': 'space_between',
      'wrap': 'wrap',
      'children': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'column',
          'gap': 'xs',
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'text',
              'value': 'Training overview',
              'size': 'lg',
              'weight': 'semibold',
            },
            <String, Object?>{
              'type': 'text',
              'value': 'Week 5 · 4 sessions completed',
              'size': 'sm',
              'weight': 'medium',
            },
          ],
        },
        <String, Object?>{
          'type': 'button.group',
          'gap': 'sm',
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'button',
              'label': 'Open dashboard',
              'variant': 'solid',
              'action': <String, Object?>{'type': 'open_dashboard'},
            },
            <String, Object?>{
              'type': 'button',
              'label': 'Share recap',
              'variant': 'outline',
              'action': <String, Object?>{'type': 'share_recap'},
            },
          ],
        },
      ],
    },
    <String, Object?>{
      'type': 'progress',
      'value': 0.75,
      'label': 'Goal completion',
    },
    <String, Object?>{
      'type': 'timeline',
      'alignment': 'start',
      'lineStyle': 'dashed',
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Tempo run debrief',
          'subtitle': 'Added cadence drills',
          'timestamp': '2024-06-10T09:00:00Z',
          'status': <String, Object?>{'type': 'success'},
        },
        <String, Object?>{
          'title': 'Nutrition check-in',
          'subtitle': 'Updated macros',
          'timestamp': '2024-06-11T13:00:00Z',
          'status': <String, Object?>{'type': 'info'},
        },
        <String, Object?>{
          'title': 'Draft workout plan',
          'subtitle': 'Preview next block',
          'timestamp': '2024-06-12T18:00:00Z',
          'status': <String, Object?>{'type': 'pending'},
        },
      ],
    },
    <String, Object?>{
      'type': 'list',
      'gap': 'sm',
      'children': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'list.item',
          'title': 'Focus',
          'subtitle': 'Aerobic base & recovery',
          'badge': 'Pinned',
          'icon': 'flag',
        },
        <String, Object?>{
          'type': 'list.item',
          'title': 'Next milestone',
          'subtitle': 'Half marathon tune up',
          'icon': 'bolt',
        },
      ],
    },
  ],
};

final Map<String, Object?> _formWidget = <String, Object?>{
  'id': 'plan_form_card',
  'type': 'card',
  'padding': 'lg',
  'background': '#FFFFFF',
  'children': <Map<String, Object?>>[
    <String, Object?>{
      'type': 'text',
      'value': 'Create training block',
      'size': 'lg',
      'weight': 'semibold',
    },
    <String, Object?>{
      'type': 'form',
      'children': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'row',
          'gap': 'md',
          'wrap': 'wrap',
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'input',
              'name': 'plan_name',
              'label': 'Plan name',
              'placeholder': 'Enter a title',
              'required': true,
              'errorText': 'Required field',
              'helperText': 'Visible to clients',
            },
            <String, Object?>{
              'type': 'select.single',
              'name': 'coach',
              'label': 'Assign coach',
              'defaultValue': 'coach_ada',
              'options': <Map<String, Object?>>[
                <String, Object?>{
                  'label': 'Ada Lovelace',
                  'value': 'coach_ada',
                },
                <String, Object?>{
                  'label': 'Grace Hopper',
                  'value': 'coach_grace',
                },
              ],
            },
          ],
        },
        <String, Object?>{
          'type': 'textarea',
          'name': 'notes',
          'label': 'Notes',
          'rows': 3,
          'helperText': 'Include warmups and cooldowns',
          'defaultValue': 'Focus on even pacing and recovery.',
        },
        <String, Object?>{
          'type': 'checkbox.group',
          'name': 'focus',
          'label': 'Focus areas',
          'options': <Map<String, Object?>>[
            <String, Object?>{'label': 'Conditioning', 'value': 'conditioning'},
            <String, Object?>{'label': 'Strength', 'value': 'strength'},
            <String, Object?>{'label': 'Mobility', 'value': 'mobility'},
          ],
          'defaultValue': <String>['conditioning', 'mobility'],
        },
        <String, Object?>{
          'type': 'chips',
          'name': 'tags',
          'label': 'Tags',
          'options': <Map<String, Object?>>[
            <String, Object?>{'label': 'Week 5', 'value': 'w5'},
            <String, Object?>{'label': 'Recovery', 'value': 'recovery'},
            <String, Object?>{'label': 'Power', 'value': 'power'},
          ],
          'defaultValue': <String>['w5', 'power'],
        },
      ],
      'onSubmitAction': <String, Object?>{
        'type': 'save_plan',
        'label': 'Save plan',
      },
    },
  ],
};

final Map<String, Object?> _insightsWidget = <String, Object?>{
  'id': 'insights_panel',
  'type': 'card',
  'padding': 'lg',
  'background': '#FFFFFF',
  'children': <Map<String, Object?>>[
    <String, Object?>{
      'type': 'accordion',
      'id': 'insights_accordion',
      'allowMultiple': false,
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Recent wins',
          'subtitle': 'Week of June 10',
          'expanded': true,
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'status',
              'level': 'success',
              'message': 'Long run completed with negative split.',
            },
            <String, Object?>{
              'type': 'list',
              'gap': 'sm',
              'children': <Map<String, Object?>>[
                <String, Object?>{
                  'type': 'list.item',
                  'title': 'Mileage',
                  'subtitle': '42 km (target 40 km)',
                  'badge': '+5%',
                  'children': <Map<String, Object?>>[
                    <String, Object?>{
                      'type': 'text',
                      'value': '84% of monthly goal',
                      'size': 'sm',
                    },
                  ],
                },
                <String, Object?>{
                  'type': 'list.item',
                  'title': 'Sleep quality',
                  'subtitle': 'Average 7h 25m',
                  'icon': 'moon',
                },
              ],
            },
          ],
        },
        <String, Object?>{
          'title': 'Risks',
          'subtitle': 'Monitor closely',
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'status',
              'level': 'warning',
              'message': 'Right hamstring tightness flagged twice last week.',
            },
            <String, Object?>{
              'type': 'markdown',
              'value':
                  '- Add extra mobility after sessions\n- Reduce intensity if soreness > 4/10',
            },
          ],
        },
      ],
    },
    <String, Object?>{
      'type': 'tabs',
      'tabs': <Map<String, Object?>>[
        <String, Object?>{
          'label': 'Metrics',
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'chart',
              'height': 240,
              'datasets': <Map<String, Object?>>[
                <String, Object?>{
                  'label': 'Mileage',
                  'type': 'line',
                  'color': '#2563eb',
                  'data': <Map<String, Object?>>[
                    {'x': 'Mon', 'y': 5},
                    {'x': 'Tue', 'y': 7},
                    {'x': 'Wed', 'y': 6},
                    {'x': 'Thu', 'y': 8},
                    {'x': 'Fri', 'y': 4},
                    {'x': 'Sat', 'y': 12},
                    {'x': 'Sun', 'y': 0},
                  ],
                },
                <String, Object?>{
                  'label': 'Pace',
                  'type': 'bar',
                  'color': '#f59e0b',
                  'data': <Map<String, Object?>>[
                    {'x': 'Mon', 'y': 5.2},
                    {'x': 'Tue', 'y': 5.1},
                    {'x': 'Wed', 'y': 5.3},
                    {'x': 'Thu', 'y': 5.0},
                    {'x': 'Fri', 'y': 5.6},
                    {'x': 'Sat', 'y': 4.8},
                    {'x': 'Sun', 'y': 0},
                  ],
                },
              ],
            },
          ],
        },
        <String, Object?>{
          'label': 'Notes',
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'markdown',
              'value':
                  'Coach reminder: prioritise recovery nutrition and hydration on double days.',
            },
          ],
        },
      ],
    },
    <String, Object?>{
      'type': 'carousel',
      'id': 'insights_carousel',
      'height': 200,
      'showIndicators': true,
      'showControls': true,
      'loop': false,
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Day 1 · Strength',
          'subtitle': 'Lower body focus',
          'badge': 'New',
          'tags': <String>['Gym', 'Mobility'],
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'box',
              'background': '#E0F2FE',
              'padding': 'lg',
              'radius': 20,
              'children': <Map<String, Object?>>[
                {
                  'type': 'text',
                  'value':
                      'Focus on Z2 mileage, mobility drills, and posterior-chain strength.',
                  'size': 'sm',
                },
              ],
            },
          ],
        },
        <String, Object?>{
          'title': 'Day 3 · Speed',
          'subtitle': 'Track intervals',
          'description': '6 × 400m at 5k pace, 200m float recoveries.',
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'box',
              'background': '#FEE2E2',
              'padding': 'lg',
              'radius': 20,
              'children': <Map<String, Object?>>[
                {
                  'type': 'text',
                  'value':
                      'Include 15 minute warm-up, drills, strides, then intervals with full recovery.',
                  'size': 'sm',
                },
              ],
            },
          ],
        },
        <String, Object?>{
          'title': 'Day 5 · Long run',
          'subtitle': 'Z2 endurance',
          'tags': <String>['Road', 'Fuel plan'],
          'children': <Map<String, Object?>>[
            <String, Object?>{
              'type': 'box',
              'background': '#DCFCE7',
              'padding': 'lg',
              'radius': 20,
              'children': <Map<String, Object?>>[
                {
                  'type': 'text',
                  'value':
                      'Negative split the final 20 minutes and practice race-day fueling.',
                  'size': 'sm',
                },
              ],
            },
          ],
        },
      ],
    },
  ],
};

final Map<String, Object?> _workflowWidget = <String, Object?>{
  'id': 'workflow_card',
  'type': 'card',
  'padding': 'lg',
  'background': '#FAFAFA',
  'children': <Map<String, Object?>>[
    <String, Object?>{
      'type': 'wizard',
      'id': 'plan_wizard',
      'nextLabel': 'Continue',
      'previousLabel': 'Back',
      'finishLabel': 'Launch plan',
      'steps': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Review goals',
          'children': <Map<String, Object?>>[
            {'type': 'text', 'value': 'Target race: Valencia Marathon'},
            {
              'type': 'definition.list',
              'items': <Map<String, Object?>>[
                {'label': 'A-goal', 'value': 'Sub 3:00'},
                {'label': 'Start date', 'value': '2024-06-24'},
              ],
            },
          ],
        },
        <String, Object?>{
          'title': 'Configure block',
          'children': <Map<String, Object?>>[
            {
              'type': 'list',
              'children': <Map<String, Object?>>[
                {
                  'type': 'list.item',
                  'title': 'Intensity split',
                  'subtitle': '75% easy / 25% quality',
                },
                {
                  'type': 'list.item',
                  'title': 'Fuel reminders',
                  'subtitle': 'Before workout & mid-run',
                  'badge': 'Coach note',
                },
              ],
            },
          ],
        },
        <String, Object?>{
          'title': 'Preview timeline',
          'children': <Map<String, Object?>>[
            {
              'type': 'timeline',
              'alignment': 'start',
              'lineStyle': 'solid',
              'items': <Map<String, Object?>>[
                {
                  'title': 'Kickoff sync',
                  'timestamp': '2024-06-25T09:00:00Z',
                  'status': {'type': 'info'},
                },
                {
                  'title': 'First assessment',
                  'timestamp': '2024-07-01T15:00:00Z',
                  'status': {'type': 'pending'},
                },
                {
                  'title': 'Deload week',
                  'timestamp': '2024-08-05T08:00:00Z',
                  'status': {'type': 'success'},
                },
              ],
            },
          ],
        },
      ],
    },
    <String, Object?>{
      'type': 'modal',
      'title': 'Coach tips',
      'trigger': {'label': 'Open preparation tips'},
      'actions': const [
        {'label': 'Mark as read', 'type': 'noop'},
      ],
      'children': <Map<String, Object?>>[
        {
          'type': 'markdown',
          'value':
              '**Hydration**: target 500ml per hour.\n\n**Mobility**: dedicate 10 minutes after each run.',
        },
      ],
    },
  ],
};

final Map<String, Object?> _carouselOnlyWidget = <String, Object?>{
  'id': 'progress_carousel',
  'type': 'carousel',
  'height': 180,
  'showIndicators': true,
  'showControls': true,
  'loop': false,
  'items': <Map<String, Object?>>[
    <String, Object?>{
      'title': 'Week 1',
      'subtitle': 'Foundation',
      'tags': <String>['Base', 'Mobility'],
      'children': <Map<String, Object?>>[
        {'type': 'text', 'value': 'Focus on Z2 mileage and drills.'},
      ],
    },
    <String, Object?>{
      'title': 'Week 2',
      'subtitle': 'Introduce strides',
      'tags': <String>['Speed'],
      'children': <Map<String, Object?>>[
        {'type': 'text', 'value': 'Add 6 × 20s strides post easy run.'},
      ],
    },
    <String, Object?>{
      'title': 'Week 3',
      'subtitle': 'Progressive long run',
      'tags': <String>['Threshold'],
      'children': <Map<String, Object?>>[
        {'type': 'text', 'value': 'Last 6 km at marathon effort.'},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('dashboard widget layout golden', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
      ),
      apiClient: _NoopApiClient(),
    );
    addTearDown(controller.dispose);

    final widgetJson = _deepCopy(_dashboardWidget);
    final item = ThreadItem(
      id: 'assistant_dashboard',
      threadId: 'thread_ui',
      createdAt: DateTime.utc(2024, 1, 1),
      type: 'assistant_message',
      role: 'assistant',
      content: const [
        {'type': 'output_text', 'text': 'Preview'},
      ],
      attachments: const [],
      metadata: const {},
      raw: {
        'widget': _deepCopy(_dashboardWidget),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Center(
            child: SizedBox(
              width: 720,
              child: ChatKitWidgetRenderer(
                widgetJson: widgetJson,
                controller: controller,
                item: item,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChatKitWidgetRenderer),
      matchesGoldenFile('goldens/dashboard_widget.png'),
    );
  });

  testWidgets('form widget layout golden', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
      ),
      apiClient: _NoopApiClient(),
    );
    addTearDown(controller.dispose);

    final widgetJson = _deepCopy(_formWidget);
    final item = ThreadItem(
      id: 'assistant_form',
      threadId: 'thread_ui',
      createdAt: DateTime.utc(2024, 1, 1),
      type: 'assistant_message',
      role: 'assistant',
      content: const [
        {'type': 'output_text', 'text': 'Form preview'},
      ],
      attachments: const [],
      metadata: const {},
      raw: {
        'widget': _deepCopy(_formWidget),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: SizedBox(
              width: 560,
              child: ChatKitWidgetRenderer(
                widgetJson: widgetJson,
                controller: controller,
                item: item,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChatKitWidgetRenderer),
      matchesGoldenFile('goldens/form_widget.png'),
    );
  });

  testWidgets('insights widget layout golden', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
      ),
      apiClient: _NoopApiClient(),
    );
    addTearDown(controller.dispose);

    final widgetJson = _deepCopy(_insightsWidget);
    final item = ThreadItem(
      id: 'insights_item',
      threadId: 'thread_ui',
      createdAt: DateTime.utc(2024, 1, 1),
      type: 'assistant_message',
      role: 'assistant',
      content: const [
        {'type': 'output_text', 'text': 'Insights preview'},
      ],
      raw: {
        'widget': _deepCopy(_insightsWidget),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Center(
            child: SizedBox(
              width: 880,
              child: ChatKitWidgetRenderer(
                widgetJson: widgetJson,
                controller: controller,
                item: item,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChatKitWidgetRenderer),
      matchesGoldenFile('goldens/insights_widget.png'),
    );
  });

  testWidgets('workflow widget layout golden', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1100);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
      ),
      apiClient: _NoopApiClient(),
    );
    addTearDown(controller.dispose);

    final widgetJson = _deepCopy(_workflowWidget);
    final item = ThreadItem(
      id: 'workflow_item',
      threadId: 'thread_ui',
      createdAt: DateTime.utc(2024, 1, 1),
      type: 'assistant_message',
      role: 'assistant',
      content: const [
        {'type': 'output_text', 'text': 'Workflow preview'},
      ],
      raw: {
        'widget': _deepCopy(_workflowWidget),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: SizedBox(
              width: 720,
              child: ChatKitWidgetRenderer(
                widgetJson: widgetJson,
                controller: controller,
                item: item,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChatKitWidgetRenderer),
      matchesGoldenFile('goldens/workflow_widget.png'),
    );
  });

  testWidgets('carousel keyboard navigation updates slide index',
      (tester) async {
    final controller = ChatKitController(
      const ChatKitOptions(
        api: CustomApiConfig(url: 'https://example.com'),
      ),
      apiClient: _NoopApiClient(),
    );
    addTearDown(controller.dispose);

    final widgetJson = _deepCopy(_carouselOnlyWidget);
    final item = ThreadItem(
      id: 'carousel_item',
      threadId: 'thread_ui',
      createdAt: DateTime.utc(2024, 1, 1),
      type: 'assistant_message',
      role: 'assistant',
      content: const [],
      raw: {
        'widget': _deepCopy(_carouselOnlyWidget),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: ChatKitWidgetRenderer(
                widgetJson: widgetJson,
                controller: controller,
                item: item,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(ChatKitWidgetRenderer)) as dynamic;
    state.debugRequestFocusForCarousel('progress_carousel');
    await tester.pump();

    final pageController =
        state.debugCarouselController('progress_carousel') as PageController;
    expect(pageController.page ?? pageController.initialPage.toDouble(), 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(pageController.page?.round(), 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(pageController.page?.round(), 0);
  });
}
