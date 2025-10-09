# ChatKit Dart

ChatKit Dart is a full port of the [ChatKit JS client](https://github.com/openai/chatkit-js) designed for Flutter and pure Dart environments. It mirrors the JS API surface, integrates with the `chatkit-python` backend, and ships native Flutter UI widgets that render the ChatKit widgets DSL—no WebView required.

## Packages

- [`chatkit_core`](packages/chatkit_core): Protocol models, controller, streaming transport, attachments, client tools, entities, history helpers.
- [`chatkit_flutter`](packages/chatkit_flutter): Native Flutter UI (composer, history, widgets DSL, entity tagging, thread actions).
- [`packages/examples/coach_demo`](packages/examples/coach_demo): Runnable Flutter app demonstrating the full surface against a ChatKit-compatible backend.

## Getting started

### Install from source

Add the packages to your `pubspec.yaml`:

```yaml
dependencies:
  chatkit_core:
    git:
      url: https://github.com/diwakarmoturu/chatkit-dart
      path: packages/chatkit_core
  chatkit_flutter:
    git:
      url: https://github.com/diwakarmoturu/chatkit-dart
      path: packages/chatkit_flutter
```

Fetch dependencies with `flutter pub get` or `dart pub get` depending on the target.

### Quick usage

See the package READMEs for detailed instructions. A minimal Flutter integration looks like:

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: const CustomApiConfig(url: 'https://your-backend/chatkit'),
    history: const HistoryOption(enabled: true),
    threadItemActions: const ThreadItemActionsOption(feedback: true, retry: true, share: true),
  ),
);

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: ChatKitView(controller: controller));
  }
}
```

For a complete app explore the [Coach Demo](packages/examples/coach_demo).

### Migration

Refer to [MIGRATION.md](MIGRATION.md) for a JS -> Dart mapping table covering options, methods, and events.

## Documentation

- [Parity matrix](docs/parity_matrix.md) – current JS ↔ Dart feature coverage.
- [Usage guides](docs/usage_guides.md) – theming, localization, history, entities, attachments, and hosted-mode tips.
- [Widget property coverage](docs/widget_property_coverage.md) – DSL property support mapped to Flutter implementations.

## Development

- Run `dart test packages/chatkit_core`
- Run `flutter test packages/chatkit_flutter`
- Run `dart analyze`

Golden baselines live under `packages/chatkit_flutter/test/golden/goldens`. Update them with:

```sh
flutter test packages/chatkit_flutter/test/golden/widget_dsl_golden_test.dart --update-goldens
```

Additional tasks and roadmap are tracked in [`plan.md`](plan.md).

## License

Apache-2.0. See [LICENSE](LICENSE).
