import 'package:chatkit_core/chatkit_core.dart';
import 'package:flutter/material.dart';

import '../theme/chatkit_theme.dart';
import '../widgets/widget_renderer.dart';

class ChatKitGallery extends StatefulWidget {
  const ChatKitGallery({
    super.key,
    this.brightness = Brightness.light,
  });

  final Brightness brightness;

  @override
  State<ChatKitGallery> createState() => _ChatKitGalleryState();
}

class _ChatKitGalleryState extends State<ChatKitGallery> {
  late final ChatKitController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatKitController(
      ChatKitOptions(
        api: const CustomApiConfig(
          url: 'https://preview.chatkit.invalid',
        ),
        widgets: const WidgetsOption(),
        theme: ThemeOption(
          colorScheme: widget.brightness == Brightness.dark
              ? ColorSchemeOption.dark
              : ColorSchemeOption.light,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ThreadItem _mockItem(String id) {
    return ThreadItem(
      id: 'gallery_item_$id',
      threadId: 'gallery',
      createdAt: DateTime.utc(2024, 01, 01),
      type: 'widget',
      raw: {'id': id, 'type': 'widget'},
    );
  }

  Widget _renderer(String id, Map<String, Object?> json) {
    return ChatKitWidgetRenderer(
      key: ValueKey('gallery_$id'),
      widgetJson: json,
      controller: _controller,
      item: _mockItem(id),
    );
  }

  List<_GallerySection> _buildSections() {
    return [
      _GallerySection(
        title: 'Buttons',
        description: 'Solid, soft, outline, and ghost variants.',
        child: _renderer('buttons', {
          'type': 'button.group',
          'gap': 'sm',
          'children': [
            {'type': 'button', 'label': 'Primary', 'variant': 'solid'},
            {'type': 'button', 'label': 'Soft', 'variant': 'soft'},
            {'type': 'button', 'label': 'Outline', 'variant': 'outline'},
            {'type': 'button', 'label': 'Ghost', 'variant': 'ghost'},
            {
              'type': 'button',
              'label': 'Danger',
              'variant': 'solid',
              'tone': 'danger',
            },
          ],
        }),
      ),
      _GallerySection(
        title: 'Form Controls',
        description: 'Text fields, selects, and helper text states.',
        child: _renderer('forms', {
          'type': 'form',
          'children': [
            {
              'type': 'input',
              'name': 'project_name',
              'label': 'Project name',
              'placeholder': 'Atlas redesign',
              'iconStart': 'sparkle',
            },
            {
              'type': 'textarea',
              'name': 'notes',
              'label': 'Notes',
              'placeholder': 'Add context for collaborators…',
              'helperText': 'Visible to your workspace',
            },
            {
              'type': 'select',
              'name': 'assignee',
              'label': 'Assign to',
              'defaultValue': 'ada',
              'options': [
                {'value': 'ada', 'label': 'Ada Lovelace', 'icon': 'profile'},
                {'value': 'niko', 'label': 'Nikola Tesla', 'icon': 'agent'},
                {'value': 'grace', 'label': 'Grace Hopper', 'icon': 'write'},
              ],
            },
            {
              'type': 'select.multi',
              'name': 'tags',
              'label': 'Tags',
              'defaultValue': ['backend', 'ml'],
              'options': [
                {'value': 'backend', 'label': 'Backend'},
                {'value': 'ml', 'label': 'Machine Learning'},
                {'value': 'docs', 'label': 'Docs'},
              ],
            },
          ],
        }),
      ),
      _GallerySection(
        title: 'Card',
        description: 'Card with status, progress, and actions.',
        child: _renderer('card', {
          'type': 'card',
          'status': {'level': 'success', 'message': 'On track'},
          'children': [
            {
              'type': 'text',
              'value': 'Training plan',
              'size': 'lg',
              'weight': 'semibold',
            },
            {
              'type': 'text',
              'value': 'Week 4 check-in · Intermediate',
              'size': 'sm',
              'tone': 'subtle',
            },
            {
              'type': 'progress',
              'value': 0.72,
              'label': 'Goal completion',
            },
            {
              'type': 'button.group',
              'align': 'end',
              'children': [
                {
                  'type': 'button',
                  'label': 'Share',
                  'variant': 'outline',
                  'icon': 'share',
                },
                {
                  'type': 'button',
                  'label': 'Continue',
                  'variant': 'solid',
                  'icon': 'sparkle',
                },
              ],
            },
          ],
        }),
      ),
      _GallerySection(
        title: 'Timeline',
        description: 'Milestones with badges and meta data.',
        child: _renderer('timeline', {
          'type': 'timeline',
          'alignment': 'start',
          'items': [
            {
              'title': 'Kickoff',
              'subtitle': 'Mon · 9:00 AM',
              'badge': 'Done',
              'color': 'success',
              'children': [
                {
                  'type': 'text',
                  'value': 'Aligned on scope and success metrics.',
                  'size': 'sm',
                },
              ],
            },
            {
              'title': 'Prototype review',
              'subtitle': 'Wed · 1:30 PM',
              'badge': 'Today',
              'color': 'info',
              'children': [
                {
                  'type': 'text',
                  'value': 'Gather feedback from the design council.',
                  'size': 'sm',
                },
              ],
            },
            {
              'title': 'Launch',
              'subtitle': 'Fri · 4:00 PM',
              'badge': 'Upcoming',
              'color': 'warning',
              'children': [
                {
                  'type': 'text',
                  'value': 'Finalize release notes and roll-out plan.',
                  'size': 'sm',
                },
              ],
            },
          ],
        }),
      ),
      _GallerySection(
        title: 'Table',
        description: 'Striped table with numeric column and caption.',
        child: _renderer('table', {
          'type': 'table',
          'striped': true,
          'columns': [
            {'label': 'Plan', 'dataKey': 'plan'},
            {'label': 'Focus', 'dataKey': 'focus'},
            {'label': 'Hours', 'dataKey': 'hours', 'align': 'end'},
          ],
          'rows': [
            {
              'values': {
                'plan': 'Base phase',
                'focus': 'Aerobic foundation',
                'hours': 4.5,
              },
            },
            {
              'values': {
                'plan': 'Build',
                'focus': 'Strength & tempo',
                'hours': 6.0,
              },
            },
            {
              'values': {
                'plan': 'Peak',
                'focus': 'Race pace',
                'hours': 7.2,
              },
            },
          ],
          'caption': 'Training load by macrocycle.',
        }),
      ),
      _GallerySection(
        title: 'Activity Chart',
        description: 'Bar + line chart illustrating weekly volume.',
        child: _renderer('chart', {
          'type': 'chart',
          'height': 220,
          'datasets': [
            {
              'label': 'Completed',
              'type': 'bar',
              'data': [
                {'x': 'Mon', 'y': 3},
                {'x': 'Tue', 'y': 4},
                {'x': 'Wed', 'y': 5},
                {'x': 'Thu', 'y': 4.5},
                {'x': 'Fri', 'y': 3.5},
                {'x': 'Sat', 'y': 6},
                {'x': 'Sun', 'y': 4},
              ],
            },
            {
              'label': 'Target',
              'type': 'line',
              'data': [
                {'x': 'Mon', 'y': 4},
                {'x': 'Tue', 'y': 4},
                {'x': 'Wed', 'y': 4},
                {'x': 'Thu', 'y': 4},
                {'x': 'Fri', 'y': 4},
                {'x': 'Sat', 'y': 6},
                {'x': 'Sun', 'y': 4},
              ],
            },
          ],
        }),
      ),
      _GallerySection(
        title: 'Status & Badges',
        description: 'Inline messaging for asynchronous updates.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _renderer('status', {
              'type': 'status',
              'level': 'warning',
              'message': 'Model update pending approval.',
            }),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _renderer('badge-primary', {
                  'type': 'badge',
                  'label': 'Live',
                  'variant': 'solid',
                }),
                _renderer('badge-soft', {
                  'type': 'badge',
                  'label': 'Beta',
                  'variant': 'soft',
                }),
                _renderer('badge-outline', {
                  'type': 'badge',
                  'label': 'Feedback',
                  'variant': 'outline',
                }),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = widget.brightness == Brightness.dark
        ? ThemeData(
            brightness: Brightness.dark,
            useMaterial3: false,
          )
        : ThemeData(
            brightness: Brightness.light,
            useMaterial3: false,
          );
    final themeData = ChatKitThemeData.fromOptions(
      base: baseTheme,
      option: _controller.options.resolvedTheme,
      platformBrightness: widget.brightness,
    );
    final sections = _buildSections();

    return ChatKitTheme(
      data: themeData,
      child: Theme(
        data: themeData.materialTheme,
        child: Material(
          color: themeData.palette.background,
          child: ListView.separated(
            padding: EdgeInsets.all(themeData.spacing.xl),
            itemBuilder: (context, index) => sections[index],
            separatorBuilder: (context, index) =>
                SizedBox(height: themeData.spacing.xl),
            itemCount: sections.length,
          ),
        ),
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatKitTheme.of(context);
    final spacing = chatTheme.spacing;
    final palette = chatTheme.palette;
    final radii = chatTheme.radii;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description != null && description!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.onSurfaceMuted,
              ),
            ),
          ),
        SizedBox(height: spacing.md),
        Material(
          color: palette.surface,
          elevation: 0,
          borderRadius: BorderRadius.circular(radii.card),
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
