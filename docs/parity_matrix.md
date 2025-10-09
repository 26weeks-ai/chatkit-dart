# ChatKit JS ↔ Dart Parity Matrix

This matrix captures the current parity status between the official
[`chatkit-js`](https://github.com/openai/chatkit-js) client and the Dart/Flutter
port that powers this repository.

| Surface | JS Reference | Dart Status | Notes |
| --- | --- | --- | --- |
| Controller methods & events | [Methods](https://openai.github.io/chatkit-js/guides/methods), [Events](https://openai.github.io/chatkit-js/guides/events) | ✅ Complete | `ChatKitController` exposes the full JS API surface, including composer helpers, retries, entity tagging, and `ChatKitEvent` stream. |
| Streaming transport | [Server Integration](https://openai.github.io/chatkit-python/server/) | ✅ Complete | SSE backoff + jitter, server `retry` hints, heartbeat keepalive, hosted-mode hooks. Verified via `sse_client_test.dart` and `transport_retry_test.dart`. |
| Widgets DSL renderer | [Widgets](https://openai.github.io/chatkit-python/widgets/) | ✅ Complete | All widget families (cards, transitions, forms, timelines, tables, charts, overlays, carousel, wizard, status) render natively. Golden coverage in `widget_dsl_golden_test.dart`. |
| Layout semantics | [Customization](https://openai.github.io/chatkit-js/guides/theming-customization) | ✅ Complete | `align`, `justify`, `gap`, `flex`, `padding`, `margin`, `border`, `radius`, `background`, `aspectRatio` are honoured for Box/Row/Col/List variations. |
| History panel | [Coach UI](https://openai.github.io/chatkit-js/guides/methods#history) | ✅ Complete | Sections (Pinned/Recent/Shared), search/filter, pinned threads, infinite scroll skeletons, share modal parity. See `chatkit_view_test.dart`. |
| Entity picker & tagging | [Entities](https://openai.github.io/chatkit-js/guides/entities) | ✅ Complete | Keyboard navigation, hover tooltips, inline previews, streaming suggestions, keyboard reorder/remove. |
| Attachment & share UX | [Custom Backends](https://openai.github.io/chatkit-js/guides/custom-backends) | ✅ Complete | Drag/drop, validation, upload retry, clipboard + custom share targets, share modal toasts. Tested in `chatkit_view_test.dart`. |
| Composer enhancements | [Client Tools](https://openai.github.io/chatkit-js/guides/client-tools) | ✅ Complete | Inline tag autocomplete, keyboard chip nav, pinned tool trays, hosted banners, retry/backoff. |
| Theming & localization | [Theming](https://openai.github.io/chatkit-js/guides/theming-customization), [Localization](https://openai.github.io/chatkit-js/guides/localization) | ✅ Complete | Token overrides, gradients/elevation, responsive breakpoints, `ColorSchemeOption.system`, dynamic bundle loader, interpolation. |
| Documentation & testing | — | ✅ Complete | Golden/widget tests, SSE fixtures, integration suites, and usage guides available under `docs/`. |

Legend: ✅ complete · ⚠️ partial · ⏳ planned
