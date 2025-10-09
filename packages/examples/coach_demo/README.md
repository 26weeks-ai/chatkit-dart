# Coach Demo (Flutter)

This example application wires `chatkit_core` + `chatkit_flutter` into a simple "Coach" experience that talks to a ChatKit-compatible backend (for example [`chatkit-python`](https://github.com/openai/chatkit-python)). It showcases:

- History panel with rename/delete/new chat
- Entity tagging with autocomplete, preview, and click handlers
- Model and tool selectors with composer state syncing
- Assistant feedback/retry/share controls
- Widget renderer previews (via entity preview dialog)

## Prerequisites

- Flutter 3.19 or later
- A ChatKit-compatible backend (e.g. FastAPI sample from `chatkit-python`) running at `http://localhost:8000/chatkit`

## Running

```bash
flutter pub get
flutter run
```

Update the endpoint or upload options in `lib/main.dart` to match your backend configuration.

## Highlights

- `ChatKitController` created with rich options (history, composer tools/models, entities, widgets, thread actions)
- `ChatKitView` renders the full native UI (no WebView)
- Demo entity search/preview data is stubbed locally so you can explore the UI even without a backend connection

## Customising

- Replace the `CustomApiConfig.url` with your own endpoint.
- Enable attachments by providing an upload strategy and returning upload URLs from your backend.
- Hook widget actions (`widgets.onAction`) or client tools (`onClientTool`) to drive bespoke app logic.

