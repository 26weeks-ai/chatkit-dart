# ChatKit Dart Integration Guide

This guide explains how to integrate the ChatKit Dart port in both pure-Dart
and Flutter environments. It covers the two packages shipped in this repo:

- `chatkit_core` — sometimes nicknamed “chatkit_care” — the headless client
  that mirrors the [chatkit-js](https://openai.github.io/chatkit-js/) API.
- `chatkit_flutter` — the native Flutter UI layer that renders the ChatKit
  widget DSL without a WebView.

The API surface intentionally matches the JS SDK so you can reuse existing
backends such as `chatkit-python` with minimal adjustments.

## Prerequisites

- Dart 3.3+ / Flutter 3.19+ (the examples assume Flutter).
- A ChatKit-compatible backend (for example
  [`chatkit-python`](https://github.com/openai/chatkit-python) or your own
  FastAPI/Express implementation) reachable over HTTPS.
- SSE (server-sent events) enabled on the backend for streaming responses.
- If you depend on attachments, ensure the backend supports direct uploads or
  two-phase uploads (pre-signed URLs).

## Installing the packages

Add the packages to your `pubspec.yaml` from source:

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

Fetch dependencies with `dart pub get` (pure Dart) or `flutter pub get`
(Flutter). You can depend on either package independently.

## Selecting an API configuration

`ChatKitOptions.api` accepts one of two configurations that mirror the JS
client:

### `CustomApiConfig`

Use this when you control the ChatKit-compatible endpoint.

```dart
final options = ChatKitOptions(
  api: CustomApiConfig(
    url: 'https://your-domain/chatkit',
    domainKey: 'optional-domain-verification',
    uploadStrategy: const TwoPhaseUploadStrategy(),
    headersBuilder: (request) => {
      'Authorization': 'Bearer ${authTokenProvider()}',
      'x-app-version': buildNumber,
    },
  ),
);
```

- `uploadStrategy` may be `DirectUploadStrategy` (single POST to a fixed URL) or
  `TwoPhaseUploadStrategy` (request server-signed URLs). If omitted, the server
  controls the upload flow.
- `headersBuilder` runs on every HTTP request, allowing you to inject auth
  tokens or correlation IDs. You can also override the transport entirely via
  `fetchOverride` if you need to proxy requests.

### `HostedApiConfig`

Choose this for hosted deployments where ChatKit manages auth tokens.

```dart
final options = ChatKitOptions(
  api: HostedApiConfig(
    clientToken: initialToken,
    getClientSecret: (current) async {
      return await refreshHostedSecret(current);
    },
  ),
  hostedHooks: HostedHooksOption(
    onAuthExpired: () => banners.show('Session expired. Sign in again.'),
    onAuthRestored: banners.clear,
    onStaleClient: () => controller.fetchUpdates(),
  ),
);
```

At least one of `clientToken` or `getClientSecret` must be supplied. The hosted
hooks mirror the JS lifecycle by disabling the composer on expiry and resuming
when the secret refreshes.

### Transport resilience

For fine-tuning SSE behaviour, provide a `TransportOption`:

```dart
final options = ChatKitOptions(
  api: /* ... */,
  transport: const TransportOption(
    keepAliveTimeout: Duration(seconds: 25),
    initialBackoff: Duration(milliseconds: 250),
    maxBackoff: Duration(seconds: 4),
  ),
);
```

- `keepAliveTimeout` controls when the controller treats the stream as stale.
- Backoff values are applied both to streaming retries and the offline queue.
- Server-provided `retry:` hints are respected and surfaced through
  `ChatKitLogEvent(name: 'transport.retry', data: ...)`.

## Building a shared controller

`chatkit_core` centres around `ChatKitController`. You can share a single
instance between Flutter widgets or use it headlessly on the server.

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: CustomApiConfig(url: 'https://example.com/chatkit'),
    locale: 'en-US',
    history: const HistoryOption(enabled: true, showRename: true),
    startScreen: const StartScreenOption(
      greeting: 'Welcome back!',
      prompts: [
        StartScreenPrompt(
          label: 'Summarize my tickets',
          prompt: 'Summarize the open support tickets.',
          icon: 'sparkles',
        ),
      ],
    ),
    threadItemActions: const ThreadItemActionsOption(
      feedback: true,
      retry: true,
      share: true,
      shareActions: ShareActionsOption(
        targets: [
          ShareTargetOption(
            id: 'copy',
            label: 'Copy to clipboard',
            type: ShareTargetType.copy,
          ),
          ShareTargetOption(
            id: 'crm',
            label: 'Send to CRM',
            description: 'Create a follow-up task',
            toast: 'Pushed to CRM.',
          ),
        ],
      ),
    ),
    composer: ComposerOption(
      placeholder: 'Ask me anything…',
      attachments: const ComposerAttachmentOption(
        enabled: true,
        maxCount: 6,
        maxSize: 25 * 1024 * 1024,
        accept: {
          'application/pdf': ['.pdf'],
          'image/*': ['.png', '.jpg', '.jpeg'],
        },
      ),
      tools: const [
        ToolOption(
          id: 'browser',
          label: 'Browser',
          description: 'Search the live web',
          placeholderOverride: 'Search for…',
          pinned: true,
        ),
      ],
      models: const [
        ModelOption(
          id: 'gpt-4o',
          label: 'GPT-4o',
          defaultSelected: true,
        ),
        ModelOption(
          id: 'gpt-4o-mini',
          label: 'GPT-4o mini',
          description: 'Faster, lower cost',
        ),
      ],
    ),
    disclaimer: const DisclaimerOption(
      text: 'Responses may be inaccurate. Verify critical information.',
      highContrast: true,
    ),
    entities: EntitiesOption(
      onTagSearch: searchEntities,
      onClick: (entity) => analytics.track('Entity clicked', entity.data),
      onRequestPreview: loadEntityPreview,
    ),
    widgets: WidgetsOption(
      onAction: (action, context) async {
        if (action.type == 'open_url') {
          await launchUrl(action.payload['href'] as String);
        }
      },
    ),
    localization: LocalizationOption(
      defaultLocale: 'en',
      bundles: {
        'es': {
          'composer_add_tag': 'Añadir etiqueta',
          'history_title': 'Historial',
        },
      },
      loader: fetchRemoteBundle,
      pluralResolver: resolvePluralForm,
    ),
    localizationOverrides: const {
      'composer_placeholder': 'Type here…',
    },
    theme: const ThemeOption(
      colorScheme: ColorSchemeOption.system,
      color: ThemeColorOptions(
        accent: AccentColorOptions(primary: '#2563eb', onPrimary: '#ffffff'),
        surface: SurfaceColorOptions(tertiary: '#f5f5f5'),
      ),
      typography: ThemeTypographyOptions(
        fontFamily: 'Inter',
        monospaceFontFamily: 'JetBrains Mono',
      ),
      shapes: ThemeShapeOptions(radius: 16),
      breakpoints: ThemeBreakpointOptions(
        compact: 520,
        medium: 960,
        expanded: 1280,
      ),
      backgroundGradient: ThemeGradientOptions(
        colors: ['#111827', '#1f2937'],
        angle: 135,
      ),
      elevations: ThemeElevationOptions(
        surface: 1,
        composer: 4,
        history: 0,
        assistantBubble: 2,
        userBubble: 0,
      ),
      components: ThemeComponentOptions(
        composer: ThemeComponentStyle(
          background: '#ffffff',
          radius: 20,
          elevation: 2,
        ),
      ),
    ),
    header: HeaderOption(
      enabled: true,
      title: const HeaderTitleOption(text: 'Coach'),
      leftAction: HeaderActionOption(
        icon: HeaderIcons.menu,
        onClick: () => scaffoldKey.currentState?.openDrawer(),
      ),
      rightAction: HeaderActionOption(
        icon: HeaderIcons.lightMode,
        onClick: toggleTheme,
      ),
    ),
    onClientTool: (invocation) async {
      final data = await resolveClientTool(invocation);
      return ClientToolSuccessResult(data: data);
    },
    onLog: (name, data) => logger.debug('[chatkit] $name $data'),
  ),
);
```

Everything shown above is optional beyond the `api` configuration—you can start
with a minimal set and add features progressively.

## Understanding `ChatKitOptions`

Each option mirrors the JS SDK. The points below call out integration details
and parity expectations:

- **`history`** — toggles the start pane, rename/delete menu, and history fetches.
  Threads are loaded lazily with infinite scroll (Recent, Archived, Shared).
- **`startScreen`** — controls the greeting and suggested prompts used when no
  active thread is selected.
- **`threadItemActions`** — enables feedback (thumbs up/down), retry, share, and
  customised share targets with optional descriptions, icons, and toasts. When
  `share` is `true`, you can also invoke `controller.shareItem(itemId)` to emit
  a `chatkit.message.share` event with the item payload.
- **`shareActions`** — extend the share modal with custom targets. Use
  `ShareActionsOption.onSelectTarget` to perform a side-effect when a target is
  chosen and provide per-target confirmation toasts via `ShareTargetOption.toast`
  or global fallbacks (`copyToast`, `systemToast`, `defaultToast`).
- **`composer`** — configures the input placeholder, attachment caps, MIME
  filters, tool tray ordering, and model picker defaults. Tool `placeholder`
  overrides match the JS behaviour by swapping the composer prompt while the
  tool is active.
- **`disclaimer`** — injects a dismissible banner at the bottom of the thread,
  matching JS styling. Set `highContrast` to ensure accessibility on busy
  backgrounds.
- **`entities`** — wires the inline tag search, click, and preview callbacks.
  Autocomplete suggestions appear as soon as `onTagSearch` returns results.
- **`widgets`** — surfaces widget-level actions (`widgets.onAction`) whenever
  a DSL element triggers an `action`. Return a future to keep the spinner visible
  while performing async work.
- **`localization`** — registers additional bundles and optionally lazy-loads
  locales on demand. `loader` results are cached and re-used by
  `chatkit_flutter`. `localizationOverrides` is a simple key→string map useful
  for one-off changes.
- **`theme`** — accepts either `ThemeOption` for the full token surface or the
  string presets `'light'`, `'dark'`, `'system'`. Colors should be supplied as
  hex strings (`#rrggbb`).
- **`header`** — shows a top app bar with configurable title and icon buttons.
  The icon values align with the JS `HeaderIcons` registry.
- **`initialThread`** — automatically loads a specific thread when the view
  mounts.
- **`onClientTool`** — handles server-initiated client tool invocations. See
  the section on client tools below for result formats.
- **`locale`** — forwarded as `Accept-Language` so the backend can respond with
  matching translations; the controller also uses it to resolve fallback bundles.

## Working with `chatkit_core`

`chatkit_core` exposes the full controller API for headless usage, automated
tests, or custom UIs.

### Key controller methods

| Method | Purpose |
| --- | --- |
| `focusComposer()` | Emits `chatkit.composer.focus` for UI layers to focus the input. |
| `setThreadId(String? id)` | Load a thread, clear the current session, or reset to the start screen when `null`. |
| `sendUserMessage({text, reply, attachments, newThread, metadata, tags})` | Sends a user message. Tags default to the composer state, attachments can be raw maps or `ChatKitAttachment`. |
| `setComposerValue({text, tags, attachments, toolId, modelId})` | Mutate the composer state programmatically. |
| `fetchUpdates()` | Pull fresh deltas when the stream is idle (used after reconnects). |
| `listThreads({limit, cursor, filter})` | Returns a `Page<ThreadMetadata>` for history panes. |
| `deleteThread(threadId)` / `renameThread(threadId, title)` | Manage history entries. |
| `retryAfterItem(threadId, itemId)` | Replays the assistant response after a failure. |
| `submitFeedback(threadId, itemId, value, [metadata])` | Sends thumbs up/down feedback, mirroring JS semantics. |
| `sendCustomAction(action, {itemId})` / `sendAction(...)` | Dispatches widget or assistant actions back to the server. |
| `shareItem(itemId)` | Emits a `ChatKitShareEvent` containing the item content. |
| `registerAttachment(...)` | Handles upload strategy negotiation and returns a `ChatKitAttachment`. |
| `handleAppBackgrounded()` / `handleAppForegrounded({forceRefresh})` | Coordinate with app lifecycle; automatically cancels/retries the stream. |
| `dispose()` | Cancel timers, active streams, and close the event controller. |

All controller methods perform guard checks to ensure no concurrent streaming
request is active. If violated, a `ChatKitBusyException` or
`ChatKitStreamingInProgressException` is thrown—catch these in testing or ensure
the UI disables buttons while streaming.

### Event stream

Listen to `controller.events` to mirror JS `controller.on(...)` callbacks. The
event types shipped match the official SDK:

- `chatkit.thread.change` (`ChatKitThreadChangeEvent`) — active thread updates.
- `chatkit.thread.load.start` / `chatkit.thread.load.end` — history fetching
  progress, useful for showing skeletons.
- `chatkit.response.start` / `chatkit.response.end` — assistant streaming
  lifecycle; payload includes the `ThreadItem`.
- `chatkit.composer.change` — emitted whenever composer state mutates (text,
  tags, attachments, tool/model selection).
- `chatkit.composer.focus` — see `focusComposer`.
- `chatkit.composer.availability` — indicates whether the composer is enabled,
  with optional `retryAfter`.
- `chatkit.auth.expired` — fired when hosted credentials lapse.
- `chatkit.error` — high-level errors surfaced to the UI, with `allowRetry`
  when a retry button should be shown.
- `chatkit.notice` — informational, warning, or error banners.
- `chatkit.message.share` — share payload for an item; `chatkit_flutter` uses
  this to open the share sheet.
- `chatkit.log` — structured diagnostics. Pair with `ChatKitOptions.onLog`
  for centralized logging.
- `chatkit.thread.*` (raw stream events) — wrapped in `ChatKitThreadEvent`.

Because `chatkit_core` maintains an offline queue, user messages sent while the
transport is down are retained and retried with exponential backoff governed by
`transport.initialBackoff`/`maxBackoff`. Heartbeat detection honours server
keep-alive intervals; backgrounding the app cancels the stream and clears timers.

### Client tools

When the backend invokes a client tool, your handler receives a
`ChatKitClientToolInvocation`:

```dart
controller.options.onClientTool = (invocation) async {
  if (invocation.name == 'get_calendar_events') {
    final events = await calendarApi.fetch(
      start: invocation.params['start'] as String,
      end: invocation.params['end'] as String,
    );
    return ClientToolSuccessResult(data: {'events': events});
  }
  return ClientToolErrorResult(message: 'Unknown tool.');
};
```

Handlers may return:

- `ClientToolSuccessResult(data: {...})`
- `ClientToolErrorResult(message: ..., details: {...})`
- A raw `Map<String, Object?>` (interpreted as success)
- `null` (interpreted as success with an empty payload)

Any other return type throws an argument error.

### Attachments

`registerAttachment` negotiates uploads and returns the attachment metadata to
pass into `sendUserMessage`. Progress callbacks run on both direct and two-phase
flows. Cancel uploads by returning `true` from `isCancelled`. All emitted log
events start with `attachments.*` for easier filtering.

### Thread utilities

- Programmatically switch threads with `setThreadId`, optionally supply
  `newThread: true` in `sendUserMessage` to start a fresh thread.
- Use `listThreads` to implement custom history pickers or background archiving.
- Call `fetchUpdates` after app resume or long idle periods to sync server state.

## Rendering with `chatkit_flutter`

`chatkit_flutter` provides a native, themable UI that mirrors the JS layouts.
Embed `ChatKitView` anywhere in your widget tree:

```dart
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  late final ChatKitController controller;

  @override
  void initState() {
    super.initState();
    controller = ChatKitController(buildOptions());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: ChatKitView(controller: controller),
      ),
    );
  }
}
```

### UI features provided out of the box

- **History panel** — Recent, Archived, and Shared sections with search, infinite
  scrolling, rename/delete, and pinned thread indicators. Controlled by
  `HistoryOption`.
- **Start screen** — Greeting, iconified prompt suggestions, and dynamic banner
  drawing from `StartScreenOption` and `DisclaimerOption`.
- **Composer** — Inline tag suggestions (`@`), chip keyboard navigation,
  tool/model selectors, attachment picker with drag-and-drop (desktop/iPad),
  upload progress, cancel/retry affordances, and inline retry bubbles.
- **Entity tagging** — Reusable chips with previews, click handlers, and
  keyboard shortcuts mirroring chatkit-js behaviour.
- **Widgets renderer** — Cards, stacks, tables, forms, transitions, charts,
  wizard flows, metadata, quick replies, status banners, overlays, and share
  cards are all rendered natively. Golden tests ensure parity.
- **Share modal** — Copy to clipboard, system share sheet, or custom targets
  defined in `ThreadItemActionsOption.shareActions`.
- **Hosted-mode resilience** — Automatic composer disabling, auth banners, rate
  limit notices, and stale-client prompts driven by `HostedHooksOption`.
- **Localization** — `LocalizationOption.loader` is invoked on-demand so you can
  fetch remote bundles. `ChatKitView` caches responses and respects
  `localization.defaultLocale`.
- **Dynamic theming** — Accent/gray/surface tokens, typography, shape, gradient,
  elevation, and per-component overrides are applied live. Set
  `ThemeOption.colorScheme` to `ColorSchemeOption.system` to follow platform
  brightness.
- **Accessibility** — Semantic labels from the JS SDK are mirrored; high
  contrast disclaimers and focus management (via `focusComposer`) are built in.
- **Lifecycle integration** — The view implements `WidgetsBindingObserver` and
  forwards foreground/background events to the controller, so hosted banners and
  offline queue work automatically.

### Handling widget actions

Use `WidgetsOption.onAction` to intercept DSL actions:

```dart
WidgetsOption(
  onAction: (action, context) async {
    switch (action.type) {
      case 'open_url':
        await launchUrl(action.payload['href'] as String);
        break;
      case 'handoff':
        await crm.createTicket(context.id, action.payload);
        break;
      default:
        debugPrint('Unhandled widget action: ${action.type}');
    }
  },
),
```

Because the handler may run on the UI thread, keep long-running tasks async.

### Entity previews

When `EntitiesOption.onRequestPreview` returns an `EntityPreview`, the Flutter
layer presents it in the same modal layout as chatkit-js. Return `null` to fall
back to the default preview card.

### Custom headers and layout

If you enable `HeaderOption`, ensure that any referenced icons come from
`HeaderIcons`. For fully bespoke layouts, wrap `ChatKitView` in your own
Scaffold, navigation rail, or responsive shell—the widget has no layout
constraints besides filling the available space.

## Testing and verification

- Run the core suite: `dart test packages/chatkit_core`
- Run Flutter UI tests: `flutter test packages/chatkit_flutter`
- Update widget goldens when UI changes:\
  `flutter test packages/chatkit_flutter/test/golden/widget_dsl_golden_test.dart --update-goldens`
- Static analysis: `dart analyze`

The example app (`packages/examples/coach_demo`) demonstrates a full integration.
Run it with:

```bash
flutter pub get
flutter run
```

Point the demo at your backend by editing `lib/main.dart`.

## Troubleshooting & diagnostics

- **Streaming stalls** — Inspect `chatkit.log` events with the `transport.*`
  prefix; they include retry hints, SSE heartbeat timing, and cancellation
  reasons.
- **Auth failures** — Hosted deployments raise `chatkit.auth.expired` and trigger
  `HostedHooksOption.onAuthExpired`. Refresh your tokens and call
  `handleAppForegrounded(forceRefresh: true)` to resume the stream.
- **Attachment uploads** — Listen for `attachments.upload.*` log events and
  ensure your backend returns the same JSON schema as chatkit-js. When using
  direct uploads, confirm CORS headers allow the browser-style PUT.
- **Entity search** — Debounce your API calls on the server; the controller waits
  for the promise to resolve before showing suggestions.
- **Custom actions** — `chatkit_flutter` will optimistically disable buttons
  while `sendCustomAction` is in flight. Handle rejected promises on the server
  to show `chatkit.notice` messages.

## Resources

- [chatkit-js documentation](https://openai.github.io/chatkit-js/)
- [`docs/parity_matrix.md`](parity_matrix.md) — JS ↔ Dart coverage status.
- [`docs/usage_guides.md`](usage_guides.md) — Theming, localization, hosted mode.
- [`packages/examples/coach_demo`](../packages/examples/coach_demo) — runnable sample.

With the pieces above you can replicate the full chatkit-js experience in Dart
and Flutter, while keeping parity across transport, UI, and extension points.
