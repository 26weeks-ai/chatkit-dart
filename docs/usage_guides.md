# Usage Guides

This document collects the most commonly requested configuration patterns for
the Dart/Flutter port of ChatKit. Each section mirrors behaviour documented for
the JS SDK and highlights the equivalent Dart surface.

## Localization & Theming

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: const CustomApiConfig(url: 'https://example.com/chatkit'),
    localization: const LocalizationOption(
      defaultLocale: 'en',
      bundles: {
        'es': {
          'history_title': 'Historial',
          'share_option_copy': 'Copiar al portapapeles',
        },
      },
      loader: loadLocaleBundle, // async loader for additional locales
      pluralResolver: resolvePlural, // optional plural rules
    ),
    theme: const ThemeOption(
      color: ThemeColorOptions(
        accent: AccentColorOptions(primary: '#2563eb'),
        surface: SurfaceColorOptions(tertiary: '#f8fafc'),
      ),
      typography: ThemeTypographyOptions(
        fontFamily: 'Inter',
        codeFontFamily: 'JetBrains Mono',
      ),
      components: ThemeComponentOptions(
        composer: ComponentThemeOptions(
          radius: 16,
          elevation: 2,
        ),
      ),
      breakpoints: ThemeBreakpointOptions(
        compactMaxWidth: 520,
        mediumMaxWidth: 960,
      ),
      colorScheme: ColorSchemeOption.system,
    ),
  ),
);
```

- `LocalizationOption.loader` lets you lazy-load bundles; decoded strings flow
  through `ChatKitLocalizations` and support interpolation (`{placeholder}`).
- `ChatKitOptions.locale` is forwarded as the `Accept-Language` header on API
  requests so server-side rendering and strings stay in sync with the active
  Flutter locale.
- When `colorScheme` is `ColorSchemeOption.system`, the view automatically
  tracks the platform brightness and rebinds colors in real time.
- Component tokens (`ComponentThemeOptions`) provide a single place to override
  radius, elevation, and palettes for individual surfaces (composer, cards,
  banners, etc.).

## History, Entities & Composer

```dart
final controller = ChatKitController(
  ChatKitOptions(
    history: const HistoryOption(
      enabled: true,
      showDelete: true,
      showRename: true,
      sections: [
        HistorySection.pinned,
        HistorySection.recent,
        HistorySection.shared,
      ],
    ),
    entities: EntitiesOption(
      onTagSearch: fetchEntities,
      onClick: (entity) => debugPrint('Tapped ${entity.title}'),
      onRequestPreview: (entity) async => EntityPreview(
        preview: buildEntityPreview(entity),
      ),
      keyboardShortcuts: const EntityKeyboardShortcuts(
        focusComposer: 'meta+k',
        openPicker: 'meta+e',
      ),
    ),
    composer: ComposerOption(
      attachments: const ComposerAttachmentOption(
        enabled: true,
        accept: ['application/pdf', 'image/*'],
        maxFiles: 6,
      ),
      models: const [
        ModelOption(id: 'gpt-4o', label: 'GPT-4o', defaultSelected: true),
        ModelOption(id: 'gpt-4o-mini', label: 'GPT-4o mini'),
      ],
      tools: const [
        ToolOption(
          id: 'browser',
          label: 'Browser',
          description: 'Search the web for updated info',
          placeholderOverride: 'Search for…',
        ),
      ],
    ),
  ),
);
```

- History sections (Pinned/Recent/Shared) mirror JS behaviour, including search,
  infinite scroll skeletons, and pinned threads.
- Entity picker supports keyboard navigation (`↑/↓/Enter`), tooltip previews,
  streaming suggestions, and keyboard reorder/remove events by default.
- Composer chips inherit keyboard shortcuts and pin front-of-row tool trays like
  the JS client. Inline tag suggestions appear as you type `@`.

## Attachments & Share Targets

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: CustomApiConfig(
      url: 'https://example.com/chatkit',
      uploadStrategy: const TwoPhaseUploadStrategy(),
      headersBuilder: (request) => {'x-team': 'coach'},
    ),
    threadItemActions: ThreadItemActionsOption(
      share: true,
      shareActions: ShareActionsOption(
        targets: const [
          ShareTargetOption(
            id: 'copy',
            label: 'Copy to clipboard',
            type: ShareTargetType.copy,
          ),
          ShareTargetOption(
            id: 'handoff',
            label: 'Send to CRM',
            description: 'Create a follow-up task',
            type: ShareTargetType.custom,
            toast: 'Sent to CRM.',
          ),
        ],
        onSelectTarget: handleCustomShare,
      ),
    ),
  ),
);
```

- Drag-and-drop, type validation, progress indicators, retry, and cancel state
  match JS parity. The default copy/share flows surface SnackBars consistent
  with `share_toast_*` localization entries.
- For drag/drop heavy canvases (desktop/iPad) set
  `ComposerAttachmentOption(dropTarget: true)` to tighten the overlay radius.
- Share targets fall back to the default copy/system targets when no custom
  list is supplied. Use `onSelectTarget` to dispatch to your own integrations.

## Hosted Mode Resilience

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: HostedApiConfig(
      clientToken: initialClientToken,
      getClientSecret: fetchClientSecret,
    ),
    hostedHooks: HostedHooksOption(
      onAuthExpired: () => showBanner('Session expired. Sign in again.'),
      onAuthRestored: () => hideBanner(),
      onStaleClient: refreshState,
    ),
    transport: const TransportOption(
      keepAliveTimeout: Duration(seconds: 20),
      initialBackoff: Duration(milliseconds: 200),
      maxBackoff: Duration(seconds: 2),
    ),
  ),
);
```

- `onAuthExpired` and `onAuthRestored` mirror JS hosted-mode hooks and automatically
  disable/enable the composer. The controller also emits `ChatKitAuthExpiredEvent`.
- Server-issued `retry` hints (SSE `retry:` lines) are honoured and surfaced via
  `ChatKitLogEvent(name: 'transport.retry', data: {'server_hint_ms': ...})`.
- The hosted mode banner queue renders rate-limit notices, stale client handshakes,
  and unauthorized states using the same strings as JS.
- You can observe the structured `chatkit.log` channel via the new
  `ChatKitOptions.onLog` callback in addition to listening to `ChatKitLogEvent`
  on the controller `events` stream.

## Testing Recipes

- Golden/widget coverage lives in
  `packages/chatkit_flutter/test/golden/widget_dsl_golden_test.dart` with baselines
  under `test/golden/goldens/`.
- SSE fixture permutations are defined in
  `packages/chatkit_core/test/fixtures/streaming_fixture.dart` and exercised by
  `streaming_fixture_test.dart` and `sse_client_test.dart`.
- Transport retry, offline queue, and share workflows are verified end-to-end in
  `transport_retry_test.dart`, `offline_queue_test.dart`, and
  `chatkit_view_test.dart`.
