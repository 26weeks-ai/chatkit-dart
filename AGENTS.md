# Repository Guidelines

## Project Structure & Module Organization
- `packages/chatkit_core`: Pure Dart client, protocol models, transport, and helpers. Unit tests live under `packages/chatkit_core/test`.
- `packages/chatkit_flutter`: Flutter widgets, theming, and golden baselines in `packages/chatkit_flutter/test/golden`. Update goldens only when the rendered output is intentionally changed.
- `packages/examples/coach_demo`: End-to-end sample app for manual QA against a ChatKit-compatible backend.
- `docs/`: Parity matrix, usage guides, and widget coverage that must be refreshed when surface areas change.
- `analysis_options.yaml`: Shared analyzer and lint configuration; keep package-level overrides in sync with it.

## Build, Test, and Development Commands
- Install dependencies: `dart pub get packages/chatkit_core` and `flutter pub get packages/chatkit_flutter packages/examples/coach_demo`.
- Static analysis: `dart analyze` (run from the repo root to cover all packages).
- Unit tests: `dart test packages/chatkit_core` and `flutter test packages/chatkit_flutter`.
- Golden updates: `flutter test packages/chatkit_flutter/test/golden/widget_dsl_golden_test.dart --update-goldens` after reviewing visual diffs.

## Coding Style & Naming Conventions
- Use `dart format .` before committing; 2-space indentation and trailing commas keep diffs tidy.
- Follow the shared lints (`prefer_const_constructors`, `prefer_final_locals`, `avoid_escaping_inner_quotes`, `avoid_unused_constructor_parameters`); resolve analyzer warnings instead of suppressing them.
- Classes and enums use PascalCase; methods, fields, and variables use lowerCamelCase. File names stay in snake_case (`chatkit_controller.dart`).
- Keep widget build methods small; extract private helpers for complex layouts or side effects.

## Testing Guidelines
- Name test files `*_test.dart` and group cases with `group` blocks mirroring the API surface (`ChatKitController`, `MessageComposer`).
- Aim for parity with JS coverage; add new unit or widget tests whenever behavior or contracts change.
- For UI changes, update the relevant golden and include regenerated artifacts with rationale in the PR description.
- Use the coach demo for exploratory testing; document manual steps when verifying regressions.

## Commit & Pull Request Guidelines
- Write imperative, sentence-case commit subjects (~60 chars) similar to `Refactor scrolling behavior: Optimize scroll-to-bottom logic`.
- Squash noisy fixups locally; every commit should pass `dart analyze` plus the relevant test suites.
- PRs need a concise summary, linked issues (if any), screenshots for UI shifts, and explicit callouts for golden updates or new configuration requirements.
- Include reproduction steps for bug fixes and mention any follow-up work in `plan.md` when applicable.

## Security & Configuration Tips
- Report vulnerabilities via the process in `SECURITY.md`; never publish backend credentials in code or docs.
- Keep example configs generic—use environment variables or placeholders in sample code within `packages/examples/coach_demo`.
