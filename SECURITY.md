# Security Guidelines

Follow these recommendations when deploying ChatKit with the Dart/Flutter client:

## Authentication & tokens

- **Hosted mode:** Supply a short-lived `clientToken` and (optionally) a `getClientSecret` refresh hook via `HostedApiConfig` to fetch replacement tokens from your backend. Never embed static API keys in the app.
- **Custom backend:** Use `CustomApiConfig(headersBuilder: ...)` to inject per-request auth headers (session JWT, etc.) retrieved from secure storage.
- Rotate credentials frequently and prefer HTTPS for all endpoints.

## Domain allow-list

- When using hosted ChatKit, configure `domainKey` in the dashboard and set the same key via `CustomApiConfig(domainKey: ...)`. This allows the backend to verify the origin of requests.

## Attachments

- Validate file type/size server-side even if the client enforces limits (`ComposerAttachmentOption.maxSize`, `accept`).
- For two-phase uploads, ensure pre-signed URLs are scoped to a single attachment and expire quickly.
- Use authenticated URLs when rendering attachments or widget assets in the UI.

## Client tools & widget actions

- Treat tool invocations (`onClientTool`) as untrusted input; validate parameters before making network calls or writing to storage.
- Widget actions bubble back to your server (`sendCustomAction`). Sanitize payloads and enforce authorization per user/thread.

## Entities & previews

- Autocomplete responses (`entity.onTagSearch`) should be filtered to the requesting user. Avoid returning confidential data they shouldn't see.
- Widget previews returned by `onRequestPreview` are executed client-side; ensure they do not leak secrets and only include whitelisted actions.

## Error handling

- Listen to `chatkit.error` events emitted by the controller and provide user-friendly messaging without exposing stack traces.
- Log detailed error information on the backend where secure.

## Transport

- The controller automatically reconnects on transient SSE failures. Still, deploy behind HTTPS and handle 401/403 to force re-authentication.
- Set appropriate CORS rules on the backend for your Flutter web targets.

## Reporting vulnerabilities

If you discover a vulnerability in this port, please open an issue or reach out to the repository maintainer with a detailed report so it can be addressed promptly.
