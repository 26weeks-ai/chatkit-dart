Awesome, Diwakar. Below is a **concrete, end‑to‑end implementation plan** you can hand to Codex (or your engs) to produce a **publishable Dart/Flutter port of ChatKit** that mirrors the JS API, integrates with your **chatkit‑python** backend, and renders the full **widgets** DSL natively—no WebView.

Where I reference specifics of ChatKit’s behavior (methods, events, options, widgets, server SSE), I cite the official docs so the code can follow them precisely.

---

## 0) Objectives & non‑goals

**Objectives**

* Port the ChatKit client to **Dart** with two packages:

  * `chatkit_core` (pure Dart): protocol, models, SSE transport, controller.
  * `chatkit_flutter` (Flutter UI): native chat UI + full **widgets** renderer.
* **API parity** with ChatKit JS **methods** and **events** so app code stays consistent:
  Methods: `focusComposer()`, `setThreadId(threadId)`, `sendUserMessage({ text, reply, attachments, newThread })`, `setComposerValue({...})`, `fetchUpdates()`, `sendCustomAction(action, itemId?)`. ([OpenAI GitHub Pages][1])
  Events: `chatkit.thread.change`, `chatkit.response.start/end`, `chatkit.error`, `chatkit.log`, plus thread load events. ([OpenAI GitHub Pages][2])
* **Transport parity** with the Python SDK server: one **POST** endpoint, returning JSON for non‑streaming or **SSE** for streaming updates. ([OpenAI GitHub Pages][3])
* **Widgets DSL parity** (render all components listed in the Python widgets reference—Card, Text, Markdown, Button, Form, DatePicker, Chart, etc.). ([OpenAI GitHub Pages][4])
* Support **attachments** with **direct** and **two‑phase** strategies, and optional **domain allow‑list key**—same config surface as JS `api.fetch`, `uploadStrategy`, `domainKey`. ([OpenAI GitHub Pages][5])
* Support **Client Tools** (browser/client callbacks) with the same lifecycle as JS (`onClientTool`). ([OpenAI GitHub Pages][6])
* Support **entity tagging** and preview hooks in custom backend mode. ([OpenAI GitHub Pages][7])
* License the Dart port under **Apache‑2.0** to match upstream. ([GitHub][8])

**Non‑goals**

* Hosting the backend; you already run `chatkit-python`.
* Re‑implementing Agents SDK; only consume its streamed events through `chatkit-python`. ([OpenAI GitHub Pages][3])

---

## 1) Repository layout (monorepo)

```
/packages
  /chatkit_core/          # pure Dart library
  /chatkit_flutter/       # Flutter UI + widgets renderer
  /examples/coach_demo/   # minimal app using your FastAPI endpoint
/.github/workflows/ci.yml
/CONTRIBUTING.md
/LICENSE (Apache-2.0)
/README.md
```

**Acceptance**

* Build passes on stable Flutter/Dart (pin exact versions in `pubspec.yaml`).
* `dart format` and `dart analyze` clean.
* CI runs unit, widget, and integration tests on pull requests.

---

## 2) Packages & dependencies

**chatkit_core (Dart)**

* `http` (streaming SSE)
* `meta`, `collection`, `json_annotation`/`build_runner` (optional for codegen)
* `uuid` (optional for client‑side ids)
* No Flutter imports.

**chatkit_flutter (Flutter)**

* `chatkit_core`
* `flutter_markdown`
* `intl` (localization)
* `file_picker`, `image_picker` (attachments)
* `cached_network_image` (image widget previews)

---

## 3) Public API spec (match JS surface)

Create `ChatKitController` + `ChatKitOptions` mirroring JS options and methods:

```dart
// chatkit_core
class ChatKitController {
  ChatKitController(ChatKitOptions options);

  // --- METHODS (parity with JS) ---
  Future<void> focusComposer();                         // no-op in core; UI hooks it
  Future<void> setThreadId(String? threadId);
  Future<void> sendUserMessage({
    required String text,
    Map<String, dynamic>? reply,
    List<Map<String, dynamic>>? attachments,
    bool newThread = false,
  });
  Future<void> setComposerValue({
    String? text,
    Map<String, dynamic>? reply,
    List<Map<String, dynamic>>? attachments,
  });
  Future<void> fetchUpdates();
  Future<void> sendCustomAction(Map<String, dynamic> action, {String? itemId});

  // --- EVENTS (same names as JS docs) ---
  Stream<ChatKitEvent> get events; // emits:
  // ThreadChangeEvent (chatkit.thread.change)
  // ResponseStartEvent / ResponseEndEvent (chatkit.response.start/end)
  // ErrorEvent (chatkit.error)
  // LogEvent (chatkit.log)
}
```

* Provide options to configure **hosted** tokens (`getClientSecret`), **custom backend** (`api.url`, `fetch` to inject headers), **uploadStrategy** (`direct`, `twoPhase`), and **domainKey**. This mirrors JS `CustomApiConfig`. ([OpenAI GitHub Pages][5])

**Definition of Done:** All method names, parameter names, and event semantics align with the JS **Methods** and **Events** docs; attempts to call methods while a response is streaming should be rejected similarly to JS guidance. ([OpenAI GitHub Pages][1])

---

## 4) Transport & protocol

**4.1** Implement SSE client:

* POST to `/chatkit` (your endpoint), send JSON body.
* If response is `text/event-stream`, parse SSE frames; each `data:` line is JSON → decode into `ThreadStreamEvent`.
* If response is `application/json`, decode as a one‑shot result (used for non‑streaming operations e.g., `items.list`).
* Reconnect or error out cleanly on non‑200.

**Why:** Matches Python SDK: **single POST** endpoint, JSON or **SSE** streaming of the `ThreadStreamEvent` union. ([OpenAI GitHub Pages][3])

**4.2** Request payloads (to interop with chatkit‑python)

* Use the server guide’s contract (Python’s `ChatKitServer.process`): you POST the client request; server decides streaming vs JSON. ([OpenAI GitHub Pages][3])
* Provide helper builders for common flows:

  * `threads.create` when no thread id yet, otherwise `threads.add_user_message`.
  * `items.list` to fetch history.
  * `threads.custom_action` for widget actions.
* (These names reflect the typical commands referenced in ChatKit/Agents SDK examples; your backend already handles them via `ChatKitServer` → `respond`/`action`.) ([OpenAI GitHub Pages][3])

**Definition of Done:** SSE parser handles partial lines, multiple `data:` segments per event, and blank-line dispatch; robust to HTTP chunk boundaries.

---

## 5) Data model mapping (Dart)

Create a **strongly typed mirror** of the Python SDK types you’ll receive:

* `ThreadStreamEvent` (discriminator `type`) → subclasses:

  * `ThreadCreatedEvent`, `ThreadUpdatedEvent`
  * `ThreadItemAddedEvent`, `ThreadItemUpdatedEvent`, `ThreadItemDoneEvent`, `ThreadItemRemovedEvent`, `ThreadItemReplacedEvent`
  * `ProgressUpdateEvent`, `ErrorThreadEvent`, `NoticeEvent`
* `ThreadItem` union:

  * `UserMessageItem`, `AssistantMessageItem`, `ClientToolCallItem`, `WidgetItem`, `TaskItem`, `WorkflowItem`, `EndOfTurnItem`, `HiddenContextItem`
* `AssistantMessageItem.parts`: include **text deltas** (streaming) and other content parts (images, references).
* `WidgetItem.root`: root JSON node for the widgets DSL.

This follows the Python SDK’s event & item unions used by the server. ([OpenAI GitHub Pages][3])

**Definition of Done:** Round‑trip test fixtures from the Python docs examples decode into Dart classes without loss; unknown fields preserved for forward compatibility.

---

## 6) Attachments (client)

Implement all three strategies supported in JS options:

* **Direct upload**: POST `multipart/form-data` with field `file` to `uploadUrl` supplied in options; server returns `FileAttachment | ImageAttachment` JSON to include in `sendUserMessage`. ([OpenAI GitHub Pages][5])
* **Two‑phase**: call `attachments.create` (your backend persists metadata + returns `upload_url`), then upload bytes, then send the message referencing the created attachment. ([OpenAI GitHub Pages][3])
* **Hosted** (optional for future): use token flow (`getClientSecret`) if you adopt hosted mode later. ([OpenAI GitHub Pages][9])

Composer config should enforce `maxCount`, `maxSize`, and mime **accept** lists; errors surface via `chatkit.error`. ([OpenAI GitHub Pages][2])

---

## 7) Client Tools (browser/device callbacks)

Expose `onClientTool: Future<Map<String, dynamic>> Function({name, params})` in options. When a **client tool call** arrives from the server (Agents SDK sets it; ChatKit pauses streaming), invoke the callback; forward returned JSON back to the server; resume. Semantics mirror JS **Client tools**. ([OpenAI GitHub Pages][6])

**Definition of Done:** If callback throws, emit `chatkit.error` and send error back to server; ensure only one tool call is processed at a time as per server notes. ([OpenAI GitHub Pages][3])

---

## 8) Widgets DSL → Flutter widgets

Implement a **renderer** that converts widget JSON into native Flutter. Use the Python **Widgets** reference to ensure prop names and behaviors match (Badge, Box/Row/Col, Card, Text, Title, Markdown, Button, Checkbox, RadioGroup, Select, Input, Textarea, DatePicker, Divider, Spacer, Icon, Image, ListView/ListViewItem, Form, Chart, Transition, Caption, Label). ([OpenAI GitHub Pages][4])

**Actions:** Bind `ActionConfig` props (`onClickAction`, `onChangeAction`, `onSubmitAction`) to call `sendCustomAction`. Also allow **client‑side action handlers** when `handler="client"` is present (forward to a widgets onAction hook), following Python “Actions” guide. ([OpenAI GitHub Pages][10])

**Definition of Done**

* Every listed widget renders with documented props.
* Forms collect named inputs into action payloads (including `Card(asForm=True)` behavior). ([OpenAI GitHub Pages][10])
* Charts render basic bar/line/area (pick a simple pure‑Flutter chart or custom painter).
* Markdown uses `flutter_markdown`.

---

## 9) Theming, Localization, Entities

* **Theming**: Provide `ThemeOptions` akin to JS (`colorScheme`, accent, surface colors); map to `ThemeData`. ([OpenAI GitHub Pages][11])
* **Localization**: Support the `localization` hooks similar to JS, wiring through to `MaterialApp` locale; expose strings for all system UI messages. ([OpenAI GitHub Pages][12])
* **Entities**: Expose `entities.onTagSearch`, `onClick`, `onRequestPreview` with widget preview payloads for @‑mentions and source citations. ([OpenAI GitHub Pages][7])

---

## 10) Error handling & logs

Emit structured events:

* `chatkit.error` with rich error object (network, decode, SSE) and context (request id, thread id).
* `chatkit.log` for verbose diagnostics (SSE lifecycle, widget apply, action routing).
  Mirror the **Events** guide semantics. ([OpenAI GitHub Pages][2])

---

## 11) Testing strategy

**Unit (core)**

* SSE parser: fragmented frames, multiple `data:` lines per event, unicode.
* JSON decoding: all `ThreadStreamEvent` and `ThreadItem` unions (golden fixtures).
* Attachment strategies: happy / error paths.

**Widget tests (flutter)**

* Golden tests for each widget type using sample JSON from docs (Card, Form, Select, DatePicker, Chart, Transition). ([OpenAI GitHub Pages][4])
* Action dispatch: clicking Button triggers `sendCustomAction` with correct payload; `Form` aggregates named fields. ([OpenAI GitHub Pages][10])

**Integration**

* Connect to a local FastAPI stub that returns scripted SSE streams (recordings from your staging) as per **Server Integration** page. Validate events → rendered UI. ([OpenAI GitHub Pages][3])

---

## 12) CI/CD

* GitHub Actions: matrix for Dart/Flutter versions; run `flutter test` and `dart test`.
* Lints: `pedantic`/`flutter_lints`.
* Publish workflow (manual) to `pub.dev` for both packages; semantic versioning.

---

## 13) Security & performance

* **Security**: never persist secrets client‑side; only inject headers via `api.fetch` callback; if you use hosted mode later, implement short‑lived token refresh (`getClientSecret`). ([OpenAI GitHub Pages][9])
* **Attachments**: enforce accept lists & size; never expose raw signed URLs beyond immediate use; follow AttachmentStore guidance for access control. ([OpenAI GitHub Pages][3])
* **Perf**: incremental list rendering (message virtualization), image caching, coalesce text deltas, debounce widget updates.

---

## 14) Example app (`examples/coach_demo`)

* Minimal Flutter app with one page hosting `<ChatKitView>`.
* Config points to your `/chatkit` FastAPI endpoint (custom backend mode with `api.url` + `fetch` adding JWT). ([OpenAI GitHub Pages][5])
* Buttons to switch `threadId`, attach files, and trigger a demo widget action.

---

## 15) Work breakdown structure (WBS)

> Create issues/milestones in the repo with these acceptance tests. Codex can implement in order.

### M1 — Scaffolding

* [ ] Create monorepo structure, CI, lints, license (Apache‑2.0). ([GitHub][8])

### M2 — Transport & controller (core)

* [ ] Implement `ChatKitOptions` with `ApiOptions { url | fetch | getClientSecret | uploadStrategy | domainKey }`. ([OpenAI GitHub Pages][5])
* [ ] SSE client (`text/event-stream`) + JSON POST.
* [ ] `ChatKitController` with **all methods** and state guards (reject during response, as per Events guide). ([OpenAI GitHub Pages][2])
* [ ] Event stream types (`ChatKitEvent`): thread.change, response.start/end, error, log. ([OpenAI GitHub Pages][2])
* **Acceptance:** Demo prints deltas to console from a mocked SSE stream.

### M3 — Models (core)

* [ ] Implement `ThreadStreamEvent` union + `ThreadItem` union and deltas.
* [ ] JSON decoding with discriminator `type`.
* **Acceptance:** Golden fixtures decode/encode round‑trip.

### M4 — Attachments (core)

* [ ] Direct upload helper with `multipart/form-data` to `uploadUrl`.
* [ ] Two‑phase helper: `attachments.create` → upload → reference.
* **Acceptance:** Local test server echoes attachment JSON; errors raise `chatkit.error`. ([OpenAI GitHub Pages][3])

### M5 — Client tools (core)

* [ ] `onClientTool` hook; serialize return value to server; single‑call concurrency.
* **Acceptance:** Simulated tool call pauses stream; resumes on client return. ([OpenAI GitHub Pages][6])

### M6 — Flutter UI shell

* [ ] `ChatKitView(controller)` with header, message list, composer.
* [ ] Bind `focusComposer` via `FocusNode`.
* **Acceptance:** Sends messages; shows streaming text.

### M7 — Widgets renderer (phase 1)

* [ ] Implement primitives: **Text, Title, Markdown, Button, Divider, Spacer, Icon, Image, Row/Col/Box, Card, ListView/ListViewItem**. ([OpenAI GitHub Pages][4])
* [ ] Wire actions to `sendCustomAction`.
* **Acceptance:** Render sample widget trees from docs.

### M8 — Widgets renderer (phase 2)

* [ ] Inputs: **Input, Textarea, Checkbox, RadioGroup, Select, DatePicker, Form**. ([OpenAI GitHub Pages][4])
* [ ] Form value collection & validation semantics; `Card(asForm=True)` confirm/cancel behavior. ([OpenAI GitHub Pages][10])
* **Acceptance:** Form submit builds payload per docs (namespaced keys).

### M9 — Widgets renderer (phase 3)

* [ ] **Chart** + **Transition** + **Caption/Label/Badge**. ([OpenAI GitHub Pages][4])
* **Acceptance:** Chart renders provided series; Transition shows loading/placeholder states.

### M10 — Theming, Localization, Entities

* [ ] Theming options mapping (light/dark, accent). ([OpenAI GitHub Pages][11])
* [ ] Localization hooks & string tables. ([OpenAI GitHub Pages][12])
* [ ] Entities: `onTagSearch`, `onClick`, `onRequestPreview` (preview uses widgets). ([OpenAI GitHub Pages][7])
* **Acceptance:** @‑mentions show suggestions; hover/tap preview renders a Card.

### M11 — Integration demo & docs

* [ ] Example app wired to `/chatkit` FastAPI server (custom backend). ([OpenAI GitHub Pages][3])
* [ ] README with setup, code samples, and migration notes (JS → Dart map).

---

## 16) File‑level skeleton (key files Codex should create)

**`packages/chatkit_core/lib/chatkit_core.dart`**

```dart
library chatkit_core;
export 'src/options.dart';
export 'src/controller.dart';
export 'src/events.dart';
export 'src/models/models.dart';
export 'src/net/sse_client.dart';
export 'src/net/api_client.dart';
```

**`src/options.dart`**

* `ApiOptions` with `url`, `fetch(url, method, headers, body)`, `getClientSecret(existing)`, `uploadStrategy`, `domainKey`. (Parity with JS Custom Backends + Authentication.) ([OpenAI GitHub Pages][5])

**`src/events.dart`**

* `ChatKitEvent` base + `ThreadChangeEvent`, `ResponseStartEvent`, `ResponseEndEvent`, `ErrorEvent`, `LogEvent`. (Parity with JS Events.) ([OpenAI GitHub Pages][2])

**`src/models/models.dart`**

* All `ThreadStreamEvent` and `ThreadItem` unions per Python SDK usage. ([OpenAI GitHub Pages][3])

**`src/net/sse_client.dart`**

* Streaming POST with SSE parsing.

**`src/net/api_client.dart`**

* `sendStreaming(payload)` and `sendJson(payload)`; uses `ApiOptions.fetch` when provided; injects `domainKey`.

**`src/controller.dart`**

* Implement all methods (with guards during response / thread load as in Events guide). ([OpenAI GitHub Pages][2])

**`packages/chatkit_flutter/lib/chatkit_view.dart`**

* Shell: header, message list, composer; focus wiring.

**`packages/chatkit_flutter/lib/widgets/renderer.dart`**

* `Widget render(Map<String, dynamic> node)` switch for all components listed in widgets reference. ([OpenAI GitHub Pages][4])

**`packages/chatkit_flutter/lib/widgets/composer.dart`**

* Text field, attachments, pinned tools; honors `placeholder`, `accept`, `maxSize`, `maxCount`.

**`examples/coach_demo/lib/main.dart`**

* Shows `ChatKitView` with options pointing to your FastAPI endpoint.

---

## 17) Compatibility & migration table (JS → Dart)

| JS                                                                                                                 | Dart/Flutter                                                                           |
| ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| `useChatKit({...})`                                                                                                | `ChatKitController(ChatKitOptions(...))`                                               |
| `api: { url, fetch, uploadStrategy, domainKey }`                                                                   | `ApiOptions(url, fetch, uploadStrategy, domainKey)`                                    |
| `api: { getClientSecret(existing) }`                                                                               | `ApiOptions.getClientSecret(existing)`                                                 |
| Methods: `focusComposer`, `setThreadId`, `sendUserMessage`, `setComposerValue`, `fetchUpdates`, `sendCustomAction` | Identical methods on controller. ([OpenAI GitHub Pages][1])                            |
| Events: `chatkit.thread.change`, `chatkit.response.*`, `chatkit.error`, `chatkit.log`                              | `ChatKitEvent` stream emits equivalent types. ([OpenAI GitHub Pages][2])               |
| Widgets JSON                                                                                                       | `WidgetsRenderer.render(node)` produces Flutter UI. ([OpenAI GitHub Pages][4])         |
| Client tools (`onClientTool`)                                                                                      | `onClientTool` option invoked; results forwarded to server. ([OpenAI GitHub Pages][6]) |
| Entity tagging (`onTagSearch`, `onRequestPreview`, `onClick`)                                                      | Same‑named options in Dart; previews rendered via widgets. ([OpenAI GitHub Pages][7])  |

---

## 18) Example configuration in your app (Coach tab)

```dart
final controller = ChatKitController(
  ChatKitOptions(
    api: ApiOptions(
      url: Uri.parse('https://api.26weeks.ai/chatkit'),
      fetch: (url, method, headers, body) async {
        // inject session JWT; return a small adapter result
        // (Codex: implement an adapter class to normalize to http.Response)
        throw UnimplementedError();
      },
      uploadStrategy: const TwoPhaseUploadStrategy(),
      domainKey: 'your-domain-key', // if you use allow-list
    ),
    composer: ComposerOptions(
      placeholder: "Ask your coach anything…",
      attachments: ComposerAttachments(
        uploadStrategy: const TwoPhaseUploadStrategy(),
        maxCount: 3,
        maxSize: 20 * 1024 * 1024,
        accept: ComposerAttachmentAccept({
          'image/*': ['.png', '.jpg', '.jpeg'], 'application/pdf': ['.pdf']
        }),
      ),
    ),
    entities: EntitiesOptions(
      onTagSearch: (q) async => [],
      onRequestPreview: (e) async => {/* widget JSON */},
    ),
  ),
);
return ChatKitView(controller: controller);
```

**Why this shape:** Mirrors the **Custom Backends** guide so the client injects auth and upload strategy without exposing secrets. ([OpenAI GitHub Pages][5])

---

## 19) Sample fixtures for tests

* **SSE stream** with interleaved text deltas and a widget add/update; ensure `ResponseStart/End` emitted at correct times. (Model after the Python server streaming contract.) ([OpenAI GitHub Pages][3])
* **Widget JSON** for each component in the widgets list (Card with Form & Button; Select with `onChangeAction`; DatePicker; Chart). ([OpenAI GitHub Pages][4])
* **Action routing**: `handler="client"` vs server‑handled action as documented. ([OpenAI GitHub Pages][10])

---

## 20) Documentation deliverables

* **README.md** for each package with:

  * Quickstart (custom backend mode) with code snippets (based on **Custom Backends**/**Methods** docs). ([OpenAI GitHub Pages][5])
  * Widgets usage & supported props (link to Python Widgets ref). ([OpenAI GitHub Pages][4])
  * Client Tools & Entities sections. ([OpenAI GitHub Pages][6])
* **MIGRATION.md**: JS → Dart mapping table (above).
* **SECURITY.md**: token refresh (hosted), domain allow‑listing, attachment access control. ([OpenAI GitHub Pages][9])

---

## 21) Risks & mitigations

* **Spec drift** (JS evolves): keep models tolerant to unknown fields; log but ignore unknown widget types.
* **SSE edge cases**: build robust line parser; backoff/retry on transient network errors.
* **Access control on attachments**: follow AttachmentStore guidance (verify requester owns the resource). ([OpenAI GitHub Pages][3])

---

## 22) “Definition of Done” (project)

* `chatkit_core` and `chatkit_flutter` published to `pub.dev`.
* Parity with JS **methods**, **events**, **custom backend options**, **client tools**, **entities**. ([OpenAI GitHub Pages][1])
* Widgets renderer supports all components listed in Python **Widgets** reference. ([OpenAI GitHub Pages][4])
* Example app compiles and streams from your FastAPI `/chatkit`. ([OpenAI GitHub Pages][3])
* Test coverage on SSE, models, renderer, actions, attachments.

---

## 23) Issue templates for Codex

1. **Core transport**
   *Implement SSE POST client and `ApiClient` with `fetch` override.*
   **Refs:** Server Integration (single POST, JSON/SSE). ([OpenAI GitHub Pages][3])

2. **Controller methods & events**
   *Implement all methods and event emission rules.*
   **Refs:** Methods; Events. ([OpenAI GitHub Pages][1])

3. **Models & decoding**
   *Define `ThreadStreamEvent` / `ThreadItem` unions; robust JSON decode.*
   **Refs:** Python server guide & type modules. ([OpenAI GitHub Pages][3])

4. **Attachments strategies**
   *Direct & two‑phase flows; composer limits & accept; error propagation.*
   **Refs:** Custom Backends; Attachment store. ([OpenAI GitHub Pages][5])

5. **Client tools**
   *Add `onClientTool` option; pause/resume stream; error semantics.*
   **Refs:** Client tools. ([OpenAI GitHub Pages][6])

6. **Widgets renderer P1/P2/P3**
   *Render all components; wire actions; form semantics; charts.*
   **Refs:** Widgets; Actions (forms & loading behavior). ([OpenAI GitHub Pages][4])

7. **Theming & localization & entities**
   *Theme options; i18n plumbing; entity hooks & previews.*
   **Refs:** Theming; Localization; Entities. ([OpenAI GitHub Pages][11])

8. **Example app & docs**
   *End‑to‑end demo; README; migration guide.*

---

### Quick links used in this plan

* **ChatKit JS: Methods / Events / Client Tools / Custom Backends / Authentication / Theming / Entities / Localization**: ([OpenAI GitHub Pages][1])
* **ChatKit Python: Server Integration / Actions / Widgets reference**: ([OpenAI GitHub Pages][3])
* **License (Apache‑2.0) for JS repo**: ([GitHub][8])

---

## Coach note (optional)

This gives you a clean sprint path. If energy dips, ship M2–M7 first (streaming + core widgets + actions). That already unlocks a killer **Coach** experience. Then layer in P2/P3 widgets, theming, entities. Momentum > perfection.

[1]: https://openai.github.io/chatkit-js/guides/methods "Methods | OpenAI Agent Embeds"
[2]: https://openai.github.io/chatkit-js/guides/events "Events | OpenAI Agent Embeds"
[3]: https://openai.github.io/chatkit-python/server/ "Server Integration - Chatkit Python SDK"
[4]: https://openai.github.io/chatkit-python/widgets/ "Widgets - Chatkit Python SDK"
[5]: https://openai.github.io/chatkit-js/guides/custom-backends "Custom backends | OpenAI Agent Embeds"
[6]: https://openai.github.io/chatkit-js/guides/client-tools "Client tools | OpenAI Agent Embeds"
[7]: https://openai.github.io/chatkit-js/guides/entities "Entity tagging | OpenAI Agent Embeds"
[8]: https://github.com/openai/chatkit-js "GitHub - openai/chatkit-js"
[9]: https://openai.github.io/chatkit-js/guides/authentication "Authentication | OpenAI Agent Embeds"
[10]: https://openai.github.io/chatkit-python/actions/ "Actions - Chatkit Python SDK"
[11]: https://openai.github.io/chatkit-js/guides/theming-customization "Theming and customization | OpenAI Agent Embeds"
[12]: https://openai.github.io/chatkit-js/guides/localization "Localization | OpenAI Agent Embeds"
