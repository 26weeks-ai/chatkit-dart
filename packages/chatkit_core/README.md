# ChatKit Core (Dart)

`chatkit_core` is a pure-Dart client that mirrors the [ChatKit JS](https://github.com/openai/chatkit-js) API surface so Flutter, Dart, and server-side apps can integrate with ChatKit-compatible backends such as `chatkit-python`.

## Features

- Streaming transport (SSE) + JSON fallbacks
- Streaming transport (SSE) + JSON fallbacks with automatic retry/backoff
- Offline queue for user messages with optimistic placeholders
- Thread lifecycle helpers (create, list, rename, delete, retry)
- Attachment registration with direct or two-phase upload flows
- Client tool dispatch and result submission
- Entity tagging, history, model/tool selection, and user composer state events
- Rich event stream carrying the same payloads as the JS SDK

## Install

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  chatkit_core:
    git:
      url: https://github.com/diwakarmoturu/chatkit-dart
      path: packages/chatkit_core
```

Run `dart pub get`.

## Quick start

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: const CustomApiConfig(
      url: 'https://your-backend/chatkit',
      domainKey: 'your-domain-key',
      uploadStrategy: const TwoPhaseUploadStrategy(),
    ),
    history: const HistoryOption(enabled: true),
    threadItemActions: const ThreadItemActionsOption(feedback: true),
    entities: EntitiesOption(
      onTagSearch: (query) async => fetchEntities(query),
    ),
  ),
);

controller.events.listen((event) {
  if (event is ChatKitResponseStartEvent) {
    // Update UI or metrics when the assistant starts streaming.
  }
});

await controller.sendUserMessage(text: 'Hello world');
```

See the [Coach Demo](../../examples/coach_demo) for a full Flutter integration.

### Localization

To register additional translation bundles or change the default fallback locale, provide the optional `localization` option:

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: const CustomApiConfig(url: 'https://your-backend/chatkit'),
    localization: const LocalizationOption(
      defaultLocale: 'en',
      bundles: {
        'es': {
          'history_title': 'Historial',
          'history_load_more': 'Cargar más',
        },
      },
    ),
  ),
);
```

You can still override individual strings at runtime via `localizationOverrides`.

## API parity

- Methods: `focusComposer`, `setThreadId`, `setComposerValue`, `sendUserMessage`, `sendCustomAction`, `fetchUpdates`, `retryAfterItem`, `submitFeedback`, `deleteThread`, `listThreads`, `renameThread`, `shareItem`, `registerAttachment`.
- Events: `chatkit.thread.change`, `chatkit.response.start`, `chatkit.response.end`, `chatkit.error`, `chatkit.log`, `chatkit.composer.change`, `chatkit.composer.focus`, `chatkit.message.share`, and raw thread stream events identical to ChatKit JS.

## Testing

```
dart test packages/chatkit_core
```

This command exercises:

- `fixtures/streaming_fixture.dart` via `streaming_fixture_test.dart` (mixed widget/text deltas).
- Transport retry/backoff semantics via `transport_retry_test.dart`.
- SSE parsing, heartbeat filtering, and retry hints via `sse_client_test.dart`.

## Documentation

- [Parity matrix](../../docs/parity_matrix.md) – JS ↔ Dart feature coverage.
- [Usage guides](../../docs/usage_guides.md) – hosted mode, localization, theming, history/entities, and attachments.
- [Widget property coverage](../../docs/widget_property_coverage.md) – per-widget property support and notes.

## License

Apache-2.0 © Diwakar Moturu
