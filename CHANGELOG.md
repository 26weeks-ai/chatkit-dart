# Changelog

## 0.1.0 – Phase 7 (Testing & Documentation)

- Added streaming fixtures in `packages/chatkit_core/test/fixtures` and new test
  coverage for SSE permutations, transport retry, and hosted-mode hooks.
- Expanded coverage for client tool invocations and workflow task updates with
  dedicated fixtures/tests.
- Introduced widget/golden regression suites for the DSL renderer and updated
  `chatkit_view_test.dart` to cover default share workflows.
- Added additional goldens (insights/workflow) and carousel keyboard navigation
  assertions.
- Documented parity status and advanced usage via
  [`docs/parity_matrix.md`](docs/parity_matrix.md) and
  [`docs/usage_guides.md`](docs/usage_guides.md).
- Published [`docs/widget_property_coverage.md`](docs/widget_property_coverage.md)
  and updated package docs with testing guidance plus golden regeneration notes.
