# ChatKit Flutter

`chatkit_flutter` provides native Flutter widgets built on top of `chatkit_core`, rendering the ChatKit widget DSL without a WebView. It targets feature parity with ChatKit JS so existing backend integrations (e.g. `chatkit-python`) work out of the box.

## Highlights

- Drop-in `ChatKitView` with history, start screen, composer, attachments, and thread actions
- Full widget renderer for cards, stacks, buttons, forms, metadata, tables, streaming text, etc.
- Entity tagging experiences (search, chips, previews) with customizable callbacks
- Model and tool selectors, retry/feedback/share controls, share-to-clipboard helper
- Hooks for widget actions (`widgets.onAction`) and client tools
- Rich theming surface (accent/grayscale/surface tokens, typography, shape radius)
- Localization bundles + default locale fallbacks matching the JS SDK
- Hosted-mode resilience with SSE keepalive handling, rate limit banners, and composer disable/enable on auth changes

## Install

```yaml
dependencies:
  chatkit_flutter:
    git:
      url: https://github.com/diwakarmoturu/chatkit-dart
      path: packages/chatkit_flutter
```

Install dependencies with `flutter pub get`.

## Usage

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: const CustomApiConfig(url: 'https://your-backend/chatkit'),
    history: const HistoryOption(enabled: true, showRename: true),
    threadItemActions: const ThreadItemActionsOption(
      feedback: true,
      retry: true,
      share: true,
    ),
    composer: ComposerOption(
      attachments: const ComposerAttachmentOption(enabled: true),
      tools: const [
        ToolOption(
          id: 'browser',
          label: 'Browser',
          description: 'Search the web',
          placeholderOverride: 'Search the web for…',
        ),
      ],
      models: const [
        ModelOption(id: 'gpt-4o', label: 'GPT-4o', defaultSelected: true),
        ModelOption(id: 'gpt-4o-mini', label: 'GPT-4o mini'),
      ],
    ),
    theme: const ThemeOption(
      color: ThemeColorOptions(
        accent: AccentColorOptions(primary: '#2563eb'),
        surface: SurfaceColorOptions(tertiary: '#f5f5f5'),
      ),
      shapes: ThemeShapeOptions(radius: 16),
    ),
    localization: const LocalizationOption(
      defaultLocale: 'en',
      bundles: {
        'es': {
          'history_title': 'Historial',
          'composer_add_tag': 'Añadir etiqueta',
        },
      },
    ),
    entities: EntitiesOption(
      onTagSearch: (query) async => fetchEntities(query),
      onClick: (entity) => debugPrint('Tapped ${entity.title}'),
    ),
    widgets: WidgetsOption(
      onAction: (action, context) async {
        debugPrint('Widget action: ${action.type}');
      },
    ),
  ),
);

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.controller});
  final ChatKitController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChatKitView(controller: controller),
    );
  }
}
```

See [`packages/examples/coach_demo`](../examples/coach_demo) for a runnable app that demonstrates history, entity tagging, model/tool selectors, and widget previews.

## Testing

```
flutter test packages/chatkit_flutter
```

Golden baselines live under `test/golden/goldens`. Regenerate them with:

```
flutter test test/golden/widget_dsl_golden_test.dart --update-goldens
```

Key suites:

- `chatkit_view_test.dart` – history, entities, share, attachment, and composer flows.
- `golden/widget_dsl_golden_test.dart` – visual parity for complex widget layouts.
- `localizations_test.dart` – interpolation and overrides.

## Documentation

- [Parity matrix](../../docs/parity_matrix.md)
- [Usage guides](../../docs/usage_guides.md)
- [Widget property coverage](../../docs/widget_property_coverage.md)

## License

Apache-2.0 © Diwakar Moturu
