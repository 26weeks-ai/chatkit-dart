# Widget Property Coverage

This table tracks how the Dart/Flutter renderer applies common widget DSL
properties. It is intended as a quick parity reference for feature validation
and documentation updates.

| Widget | JS Properties | Dart Coverage | Notes |
| --- | --- | --- | --- |
| `box`, `row`, `col`, `stack`, `section` | `align`, `justify`, `wrap`, `gap`, `flex`, `padding`, `margin`, `border`, `radius`, `background`, `aspectRatio`, `minWidth/Height`, `maxWidth/Height` | ✅ Implemented (`widget_renderer.dart:266-420`, `5265-5385`) | Flex and wrap semantics mirror JS; `aspectRatio` maps to `AspectRatio`, borders support axis-specific overrides. |
| `list`, `list.item` | `gap`, `limit`, `status`, `align`, `onClickAction`, `icon`, `badge`, nested children | ✅ Implemented (`widget_renderer.dart:248-312`, `666-740`) | Click actions honour `loadingBehavior`; nested children rendered with `Wrap`. |
| `timeline`, `timeline.item` | `items`, `alignment`, `variant`, `lineStyle`, `density`, `dividers`, `status`, `timestamp`, `tags` | ✅ Implemented (`widget_renderer.dart:751-882`) | Timestamps parsed using `intl`; dashed vs solid line styles respected. |
| `carousel` | `id`, `items`, `children`, `height`, `loop`, `autoPlay`, `autoPlayInterval`, `showIndicators`, `showControls`, `label` | ✅ Implemented (`widget_renderer.dart:1027-1175`) | Keyboard focus handled via `Focus` + `_handleCarouselKey`; slides accept metadata (title/subtitle/badge/tags). |
| `table` | `columns`, `rows`, `striped`, `density`, `columnSpacing`, `horizontalMargin`, `caption`, `emptyText`, column `sortable`, `tooltip`, `alignment`, `format` | ✅ Implemented (`widget_renderer.dart:3732-3880`) | Sorting state cached per table id; cells support nested widgets via `_buildTableCellWidget`. |
| `tabs` | `tabs[*].label`, `tabs[*].children` | ✅ Implemented (`widget_renderer.dart:3875-3907`) | Backed by `DefaultTabController`; each tab wraps children in scroll view. |
| `accordion`, `accordion.item` | `items`, `allowMultiple`, `title`, `subtitle`, `expanded` | ✅ Implemented (`widget_renderer.dart:3212-3285`) | Expansion state cached per accordion id; nested children re-render on toggle. |
| `wizard`, `wizard.step` | `steps`, `title`, `subtitle`, `onStepChangeAction`, `onFinishAction`, `nextLabel`, `previousLabel`, `finishLabel` | ✅ Implemented (`widget_renderer.dart:3320-3399`) | Uses `Stepper`; action callbacks dispatch with `loadingBehavior: container` for parity. |
| `modal`, `overlay` | `placement`, `title`, `trigger`, `actions`, `children` | ✅ Implemented (`widget_renderer.dart:3288-3365`) | Supports dialog and bottom-sheet placements; actions dispatch via `_dispatchAction`. |
| `status` | `level`, `message`, `text` | ✅ Implemented (`widget_renderer.dart:3640-3673`) | Levels map to Material colour palette; layout mirrors JS badges. |
| `progress` | `value`, `label` | ✅ Implemented (`widget_renderer.dart:2992-3012`) | Auto renders indeterminate when value is `0`/null. |
| `badge`, `pill`, `icon`, `spacer` | Style props (`variant`, `size`, `margin`, `padding`, `tooltip`) | ✅ Implemented (`widget_renderer.dart:2922-3038`, `3090-3152`) | Colour tokens map through `_colorFromToken`. |
| `form` | `children`, `onSubmitAction`, `asForm`, `collapsed`, `confirm`, `cancel` | ✅ Implemented (`widget_renderer.dart:1339-1412`, `266-324`) | Per-form validation state; confirm/cancel buttons support action metadata. |
| Inputs (`input`, `textarea`, `select`, `select.multi`, `checkbox`, `radio`, `chips`, `toggle`, `date.picker`, `slider`, `stepper`, `signature`, `otp`) | `name`, `label`, `helperText`, `errorText`, `placeholder`, `required`, `disabled`, `defaultValue`, `options`, `search`, `async onSearchAction`, `min`, `max`, `pattern`, `iconStart`, `iconEnd`, `mask`, `inline` | ✅ Implemented (`widget_renderer.dart:1374-2089`, `5505-5695`) | Async select search debounced; validation runs per-field with min/max + pattern checks; date/time pickers enforce bounds. |
| `chart` | `series`/`datasets`, `xAxis`, `showLegend`, `showTooltip`, `showYAxis`, `height`, colours | ✅ Implemented (`widget_renderer.dart:3911-4068`) | Supports mixed line/bar charts; dataset scaffolding converts dataset arrays to `series`. |
| `metadata`, `definition.list` | `entries`, `label`, `value` | ✅ Implemented (`widget_renderer.dart:2968-3010`, `3038-3089`) | Renders key/value pairs with bold label styling. |
| `hero` | `image`, `background`, `title`, `subtitle`, `children`, `padding`, `margin` | ✅ Implemented (`widget_renderer.dart:356-406`) | Fallback styling when image absent; uses `CachedNetworkImage` for remote assets. |
| `code`, `blockquote`, `markdown`, `text` | `value`, `size`, `weight`, `margin` | ✅ Implemented (`widget_renderer.dart:520-604`, `573-606`, `607-623`) | Typography tokens mapped to Material text styles. |

Legend: ✅ fully implemented · ⚠️ partial / limited support · ⏳ planned.
