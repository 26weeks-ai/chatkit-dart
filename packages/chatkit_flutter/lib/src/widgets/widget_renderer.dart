import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatkit_core/chatkit_core.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:signature/signature.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'media_player.dart';

class ChatKitWidgetRenderer extends StatefulWidget {
  const ChatKitWidgetRenderer({
    super.key,
    required this.widgetJson,
    required this.controller,
    required this.item,
  });

  final Map<String, Object?> widgetJson;
  final ChatKitController controller;
  final ThreadItem item;

  @override
  State<ChatKitWidgetRenderer> createState() => _ChatKitWidgetRendererState();
}

class _ChatKitWidgetRendererState extends State<ChatKitWidgetRenderer> {
  static const Widget _emptyTransitionChild =
      SizedBox.shrink(key: ValueKey('__transition.empty__'));
  static const Map<String, double> _spacingScale = {
    'none': 0,
    '0': 0,
    '2xs': 4,
    'xs': 8,
    'sm': 12,
    'md': 16,
    'lg': 24,
    'xl': 32,
    '2xl': 40,
    '3xl': 48,
    '4xl': 56,
  };

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, Set<Object?>> _multiSelectValues = {};
  final Map<String, Object?> _formState = {};
  final Map<String, double> _sliderValues = {};
  final Map<String, int> _stepperValues = {};
  final Map<String, SignatureController> _signatureControllers = {};
  final Map<String, List<TextEditingController>> _otpControllers = {};
  final Map<String, PageController> _pageControllers = {};
  final Map<String, bool> _accordionExpanded = {};
  final Map<String, int> _wizardStepIndex = {};
  final Map<String, Timer> _carouselTimers = {};
  final Map<String, FocusNode> _carouselFocusNodes = {};
  final Map<String, _TableSortState> _tableSortStates = {};
  final Map<String, FocusNode> _selectFocusNodes = {};
  final Map<String, Timer> _selectSearchDebounce = {};
  final Map<String, String> _selectSearchQuery = {};
  final Map<String, Map<String, Object?>> _formComponents = {};
  final Map<String, String> _fieldErrors = {};
  final Set<String> _touchedFields = {};
  final Set<Map<String, Object?>> _pendingSelfActions = {};
  int _containerLoadingDepth = 0;
  String? _cardActionPendingKey;

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final controllers in _otpControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    for (final controller in _signatureControllers.values) {
      controller.dispose();
    }
    for (final controller in _pageControllers.values) {
      controller.dispose();
    }
    for (final timer in _carouselTimers.values) {
      timer.cancel();
    }
    for (final node in _carouselFocusNodes.values) {
      node.dispose();
    }
    for (final node in _selectFocusNodes.values) {
      node.dispose();
    }
    for (final timer in _selectSearchDebounce.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildComponent(widget.widgetJson, context);
    if (_containerLoadingDepth > 0) {
      return Stack(
        children: [
          AnimatedOpacity(
            opacity: 0.5,
            duration: const Duration(milliseconds: 150),
            child: AbsorbPointer(
              absorbing: true,
              child: content,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x0F000000)),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return content;
  }

  Widget _buildComponent(Map<String, Object?> component, BuildContext context) {
    final type = (component['type'] as String? ?? '').toLowerCase();
    switch (type) {
      case 'card':
        return _buildCard(component, context);
      case 'hero':
        return _buildHero(component, context);
      case 'section':
      case 'stack':
      case 'box':
      case 'column':
      case 'col':
      case 'row':
        return _buildFlexContainer(component, context);
      case 'transition':
        return _buildTransition(component, context);
      case 'text':
        return _buildText(component, context);
      case 'markdown':
        return _buildMarkdown(component, context);
      case 'image':
        return _buildImage(component, context);
      case 'button':
        return _buildButton(component, context);
      case 'button.group':
      case 'buttongroup':
        return _buildButtonGroup(component, context);
      case 'list':
      case 'listview':
        return _buildList(component, context);
      case 'list.item':
        return _buildListItem(component, context);
      case 'form':
        return _buildForm(component, context);
      case 'input':
      case 'textarea':
      case 'select':
      case 'select.single':
      case 'select.multi':
      case 'select.native':
      case 'checkbox':
      case 'checkbox.group':
      case 'toggle':
      case 'radio.group':
      case 'date.picker':
      case 'chips':
        return _buildFormControl(component, context);
      case 'timeline':
        return _buildTimeline(component, context);
      case 'timeline.item':
        return _buildTimelineItem(component, context);
      case 'rating':
        return _buildRating(component, context);
      case 'carousel':
        return _buildCarousel(component, context);
      case 'metadata':
        return _buildMetadata(component, context);
      case 'progress':
        return _buildProgress(component, context);
      case 'icon':
        return _buildIcon(component, context);
      case 'icon.only':
        return _buildIcon(component, context, iconOnly: true);
      case 'badge':
        return _buildBadge(component, context);
      case 'spacer':
        return _buildSpacer(component);
      case 'definition.list':
      case 'definitionlist':
      case 'list.definition':
        return _buildDefinitionList(component, context);
      case 'paginator':
      case 'pagination':
        return _buildPagination(component, context);
      case 'accordion':
        return _buildAccordion(component, context);
      case 'accordion.item':
        return _buildAccordionItem(component, context);
      case 'modal':
      case 'overlay':
        return _buildModal(component, context);
      case 'wizard':
      case 'stepper':
        return _buildWizard(component, context);
      case 'wizard.step':
      case 'step':
        return _buildWizardStep(component, context);
      case 'segmented':
      case 'segmented.control':
        return _buildSegmentedControl(component, context);
      case 'file.viewer':
      case 'fileviewer':
        return _buildFileViewer(component, context);
      case 'divider':
        return const Divider();
      case 'code':
        return _buildCode(component, context);
      case 'blockquote':
        return _buildBlockquote(component, context);
      case 'pill':
        return _buildPill(component, context);
      case 'table':
        return _buildTable(component, context);
      case 'tabs':
        return _buildTabs(component, context);
      case 'chart':
        return _buildChart(component, context);
      case 'video':
        return _buildVideo(component, context);
      case 'audio':
        return _buildAudio(component, context);
      case 'map':
        return _buildMap(component, context);
      case 'status':
        return _buildStatus(component, context);
      default:
        return Text('Unsupported widget type ${component['type']}');
    }
  }

  Widget _buildCard(Map<String, Object?> component, BuildContext context) {
    final children = _buildChildren(component['children'], context);
    final sizeToken = (component['size'] as String? ?? 'md').toLowerCase();
    final padding =
        _edgeInsets(component['padding']) ?? _cardPaddingForSize(sizeToken);
    final margin = _edgeInsets(component['margin']) ??
        const EdgeInsets.symmetric(vertical: 6);
    final background = _colorFromToken(context, component['background']);
    final status = _buildWidgetStatus(component['status'], context);
    final asForm = component['asForm'] as bool? ?? false;
    final collapsed = component['collapsed'] as bool? ?? false;
    final confirmConfig = castMap(component['confirm']);
    final cancelConfig = castMap(component['cancel']);
    final themeOverride = (component['theme'] as String?)?.toLowerCase().trim();
    final cardIdentifier =
        component['id'] as String? ?? component['key'] as String? ?? 'card';

    final footerButtons = <Widget>[];
    if (cancelConfig.isNotEmpty) {
      footerButtons.add(
        _buildCardActionButton(
          context: context,
          label: cancelConfig['label'] as String? ?? 'Cancel',
          action: castMap(cancelConfig['action']),
          includeForm: asForm,
          isPrimary: false,
          actionKey: '$cardIdentifier:cancel',
        ),
      );
    }
    if (confirmConfig.isNotEmpty) {
      footerButtons.add(
        _buildCardActionButton(
          context: context,
          label: confirmConfig['label'] as String? ?? 'Confirm',
          action: castMap(confirmConfig['action']),
          includeForm: asForm,
          isPrimary: true,
          actionKey: '$cardIdentifier:confirm',
        ),
      );
    }

    final bodyChildren = <Widget>[
      if (status != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: status,
        ),
      if (!collapsed) ...children,
      if (footerButtons.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: footerButtons,
          ),
        ),
    ];

    Widget card = Card(
      margin: margin,
      color: background,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: bodyChildren,
        ),
      ),
    );

    if (themeOverride == 'light' || themeOverride == 'dark') {
      final brightness =
          themeOverride == 'dark' ? Brightness.dark : Brightness.light;
      final theme = Theme.of(context);
      card = Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(brightness: brightness),
          brightness: brightness,
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildHero(Map<String, Object?> component, BuildContext context) {
    final children = _buildChildren(component['children'], context);
    final imageUrl =
        component['image'] as String? ?? component['background'] as String?;
    final title = component['title'] as String?;
    final subtitle = component['subtitle'] as String?;
    return Container(
      margin: _edgeInsets(component['margin']) ??
          const EdgeInsets.symmetric(vertical: 8),
      padding: _edgeInsets(component['padding']) ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: imageUrl == null
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        image: imageUrl != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.45),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white70),
              ),
            ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFlexContainer(
      Map<String, Object?> component, BuildContext context) {
    final axis = _resolveAxis(component);
    final wrapMode = (component['wrap'] as String?)
        ?.toLowerCase()
        .trim()
        .replaceAll('_', '-');
    final gap = _spacingToDouble(component['gap']);
    final alignToken = (component['align'] as String?)?.toLowerCase().trim();
    final justifyToken =
        (component['justify'] as String?)?.toLowerCase().trim();
    final children = _buildChildren(component['children'], context);

    Widget content;
    if (wrapMode != null && wrapMode != 'nowrap') {
      final spacing = gap ?? 0;
      content = Wrap(
        direction: axis,
        spacing: spacing,
        runSpacing: spacing,
        alignment: _mapWrapAlignment(justifyToken),
        runAlignment: _mapWrapAlignment(alignToken),
        crossAxisAlignment: _mapWrapCrossAlignment(alignToken),
        verticalDirection: axis == Axis.horizontal && wrapMode == 'wrap-reverse'
            ? VerticalDirection.up
            : VerticalDirection.down,
        children: children,
      );
    } else {
      final spacedChildren = (gap != null && gap > 0)
          ? _withGapBetween(children, gap, axis)
          : children;
      if (axis == Axis.horizontal) {
        final crossAxis = _mapCrossAxisAlignment(alignToken, axis);
        content = Row(
          mainAxisAlignment: _mapMainAxisAlignment(justifyToken),
          crossAxisAlignment: crossAxis,
          mainAxisSize: MainAxisSize.max,
          textBaseline: crossAxis == CrossAxisAlignment.baseline
              ? TextBaseline.alphabetic
              : null,
          children: spacedChildren,
        );
      } else {
        content = Column(
          mainAxisAlignment: _mapMainAxisAlignment(justifyToken),
          crossAxisAlignment: _mapCrossAxisAlignment(alignToken, axis),
          mainAxisSize: MainAxisSize.max,
          children: spacedChildren,
        );
      }
    }

    final decorated = _decorateBox(
      context: context,
      component: component,
      child: content,
    );

    Widget result = decorated.child;
    if (decorated.flex != null) {
      result = _FlexMaybe(flex: decorated.flex!, child: result);
    }
    return result;
  }

  Widget _buildTransition(
      Map<String, Object?> component, BuildContext context) {
    final rawChild = component['children'];
    Map<String, Object?>? childConfig;
    if (rawChild is Map<String, Object?>) {
      childConfig = rawChild;
    } else if (rawChild is List) {
      for (final entry in rawChild) {
        if (entry is Map<String, Object?>) {
          childConfig = entry;
          break;
        }
      }
    }

    Widget child;
    if (childConfig != null) {
      final builtChild = _buildComponent(childConfig, context);
      child = KeyedSubtree(
        key: _resolveComponentKey(childConfig),
        child: builtChild,
      );
    } else {
      child = _emptyTransitionChild;
    }

    final durationMs = (component['duration'] as num?)?.toInt();
    final duration = durationMs != null && durationMs >= 0
        ? Duration(milliseconds: durationMs)
        : const Duration(milliseconds: 250);

    final padding = _edgeInsets(component['padding']);

    Widget animated = AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (current, animation) {
        final fade = FadeTransition(opacity: animation, child: current);
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: fade,
        );
      },
      child: child,
    );

    animated = ClipRect(child: animated);

    if (padding != null) {
      animated = Padding(padding: padding, child: animated);
    }

    return animated;
  }

  Widget _buildText(Map<String, Object?> component, BuildContext context) {
    final value = component['value'] as String? ?? '';
    final size = (component['size'] as String? ?? '').toLowerCase();
    final weight = (component['weight'] as String? ?? '').toLowerCase();
    final theme = Theme.of(context);
    TextStyle style = theme.textTheme.bodyMedium ?? const TextStyle();
    switch (size) {
      case 'xs':
        style = theme.textTheme.bodySmall ?? style;
      case 'sm':
        style = theme.textTheme.bodySmall ?? style;
      case 'lg':
        style = theme.textTheme.titleMedium ?? style;
      case 'xl':
        style = theme.textTheme.headlineSmall ?? style;
      case '2xl':
      case '3xl':
      case '4xl':
        style = theme.textTheme.headlineMedium ?? style;
    }
    switch (weight) {
      case 'medium':
        style = style.copyWith(fontWeight: FontWeight.w500);
      case 'semibold':
        style = style.copyWith(fontWeight: FontWeight.w600);
      case 'bold':
        style = style.copyWith(fontWeight: FontWeight.bold);
    }
    return Padding(
      padding: _edgeInsets(component['margin']) ??
          const EdgeInsets.symmetric(vertical: 4),
      child: Text(value, style: style),
    );
  }

  Widget _buildMarkdown(Map<String, Object?> component, BuildContext context) {
    final value = component['value'] as String? ?? '';
    return Padding(
      padding: _edgeInsets(component['margin']) ??
          const EdgeInsets.symmetric(vertical: 4),
      child: MarkdownBody(data: value),
    );
  }

  Widget _buildImage(Map<String, Object?> component, BuildContext context) {
    final src = component['src'] as String?;
    if (src == null) {
      return const SizedBox.shrink();
    }
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: _edgeInsets(component['margin']) ??
          const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: src,
          fit: BoxFit.cover,
          height: (component['height'] as num?)?.toDouble(),
          width: (component['width'] as num?)?.toDouble(),
        ),
      ),
    );
  }

  Widget _buildButton(Map<String, Object?> component, BuildContext context) {
    final label = component['label'] as String? ?? 'Action';
    final variant = (component['variant'] as String? ?? 'solid').toLowerCase();
    final action = component['action'] as Map<String, Object?>?;
    final disabled = component['disabled'] as bool? ?? false;
    final isLoading = action != null && _pendingSelfActions.contains(action);
    final effectiveDisabled = disabled || isLoading;
    void Function()? onPressed;
    if (action != null && !effectiveDisabled) {
      onPressed = () => _dispatchAction(
            action,
            context,
            preference: _ActionLoadingPreference.self,
            actionSource: action,
          );
    }

    final Widget child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    switch (variant) {
      case 'ghost':
      case 'outline':
        return OutlinedButton(onPressed: onPressed, child: child);
      case 'soft':
        return FilledButton.tonal(onPressed: onPressed, child: child);
      default:
        return FilledButton(onPressed: onPressed, child: child);
    }
  }

  Widget _buildButtonGroup(
      Map<String, Object?> component, BuildContext context) {
    final children = _buildChildren(component['children'], context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }

  Widget _buildList(Map<String, Object?> component, BuildContext context) {
    final limitRaw = component['limit'];
    final int? limit = switch (limitRaw) {
      final num value when value >= 0 => value.toInt(),
      final String value when value.toLowerCase().trim() == 'auto' => null,
      _ => null,
    };

    final rawChildren = component['children'];
    final items = <Widget>[];
    if (rawChildren is List) {
      for (final child in rawChildren) {
        if (child is Map<String, Object?>) {
          if (limit != null && items.length >= limit) break;
          items.add(_buildComponent(child, context));
        }
      }
    }

    final gap = _spacingToDouble(component['gap']);
    final spacedItems = (gap != null && gap > 0)
        ? _withGapBetween(items, gap, Axis.vertical)
        : items;

    final statusWidget = _buildListStatus(component['status'], context);
    final children = [
      if (statusWidget != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: statusWidget,
        ),
      ...spacedItems,
    ];

    final decorated = _decorateBox(
      context: context,
      component: component,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    Widget result = decorated.child;
    if (decorated.flex != null) {
      result = _FlexMaybe(flex: decorated.flex!, child: result);
    }
    return result;
  }

  Widget _buildListItem(Map<String, Object?> component, BuildContext context) {
    final alignToken = (component['align'] as String?)?.toLowerCase().trim();
    final gap = _spacingToDouble(component['gap']);
    final children = _buildChildren(component['children'], context);
    final spacedChildren = (gap != null && gap > 0)
        ? _withGapBetween(children, gap, Axis.horizontal)
        : children;

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: _mapCrossAxisAlignment(alignToken, Axis.horizontal),
      mainAxisSize: MainAxisSize.max,
      children: spacedChildren,
    );

    final decorated = _decorateBox(
      context: context,
      component: component,
      child: content,
      applyMargin: false,
    );

    Widget result = decorated.child;
    final action = component['onClickAction'] as Map<String, Object?>?;
    if (action != null) {
      result = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: decorated.borderRadius,
          onTap: () => _dispatchAction(
            action,
            context,
            preference: _ActionLoadingPreference.self,
            actionSource: action,
          ),
          child: result,
        ),
      );
    }

    if (decorated.margin != null) {
      result = Padding(padding: decorated.margin!, child: result);
    }
    if (decorated.flex != null) {
      result = _FlexMaybe(flex: decorated.flex!, child: result);
    }
    return result;
  }

  Widget _buildTimeline(Map<String, Object?> component, BuildContext context) {
    final items = (component['items'] as List?)
            ?.map((item) => castMap(item))
            .toList(growable: false) ??
        const [];
    if (items.isEmpty) {
      final children = _buildChildren(component['children'], context);
      return Column(children: children);
    }

    final alignmentToken =
        (component['alignment'] as String? ?? component['align'] as String?)
            ?.toString()
            .toLowerCase()
            .trim();
    final variantToken =
        (component['variant'] as String?)?.toLowerCase().trim();
    final lineStyleToken =
        (component['lineStyle'] as String? ?? variantToken)?.toString();

    final alignment =
        _resolveTimelineAlignment(alignmentToken, _TimelineAlignment.end);
    final lineStyle =
        _resolveTimelineLineStyle(lineStyleToken, _TimelineLineStyle.solid);
    final dense = ((component['density'] as String?)?.toLowerCase().trim() ==
            'compact') ||
        (variantToken != null && variantToken.contains('compact'));
    final showDividers = component['dividers'] as bool? ?? false;

    final children = <Widget>[];
    for (final entry in items.indexed) {
      children.add(
        _buildTimelineEntry(
          entry.$2,
          context,
          index: entry.$1,
          total: items.length,
          alignment: alignment,
          lineStyle: lineStyle,
          dense: dense,
        ),
      );
      if (showDividers && entry.$1 != items.length - 1) {
        children.add(const Divider(height: 32));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildTimelineItem(
      Map<String, Object?> component, BuildContext context) {
    return _buildTimelineEntry(
      component,
      context,
      index: 0,
      total: 1,
      alignment: _TimelineAlignment.end,
      lineStyle: _TimelineLineStyle.solid,
      dense: false,
    );
  }

  Widget _buildTimelineEntry(
    Map<String, Object?> component,
    BuildContext context, {
    required int index,
    required int total,
    required _TimelineAlignment alignment,
    required _TimelineLineStyle lineStyle,
    required bool dense,
  }) {
    final theme = Theme.of(context);
    final title = component['title'] as String? ?? '';
    final subtitle = component['subtitle'] as String?;
    final timestamp = component['timestamp'] as String?;
    String? formattedTimestamp;
    if (timestamp != null) {
      final parsed = DateTime.tryParse(timestamp);
      formattedTimestamp = parsed != null
          ? DateFormat.yMMMd().add_jm().format(parsed.toLocal())
          : timestamp;
    }
    final statusWidget = _buildWidgetStatus(component['status'], context);
    final color = _colorFromToken(context, component['color']) ??
        theme.colorScheme.primary;
    final lineColor = _colorFromToken(context, component['lineColor']) ??
        color.withValues(alpha: 0.5);
    final iconName = component['icon'] as String?;
    final icon = _iconFromName(iconName);
    final itemAlignmentToken =
        (component['alignment'] as String? ?? component['align'] as String?)
            ?.toString()
            .toLowerCase()
            .trim();
    final itemAlignment =
        _resolveTimelineAlignment(itemAlignmentToken, alignment);
    final alignLeft = switch (itemAlignment) {
      _TimelineAlignment.start => true,
      _TimelineAlignment.end => false,
      _TimelineAlignment.alternate => index.isEven,
    };

    final badge = component['badge'] as String?;
    final tags = (component['tags'] as List?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const [];
    final children = _buildChildren(component['children'], context);

    final contentChildren = <Widget>[
      if (badge != null && badge.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badge,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      if (title.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: badge != null ? 8 : 0),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      if (subtitle != null && subtitle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      if (formattedTimestamp != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            formattedTimestamp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
        ),
      if (statusWidget != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: statusWidget,
        ),
      if (tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (children.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentChildren,
    );

    final verticalPadding = dense
        ? const EdgeInsets.symmetric(vertical: 8)
        : const EdgeInsets.symmetric(vertical: 16);

    final markerVariant =
        (component['variant'] as String?)?.toLowerCase().trim() ?? '';
    final hollow =
        markerVariant.contains('outline') || markerVariant.contains('hollow');

    final axis = SizedBox(
      width: 40,
      child: Column(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: hollow ? Colors.transparent : color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 12, color: hollow ? color : Colors.white)
                : null,
          ),
          if (index != total - 1)
            Expanded(
              child: CustomPaint(
                painter: _TimelineConnectorPainter(
                  color: lineColor,
                  style: lineStyle,
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: verticalPadding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: alignLeft ? content : const SizedBox()),
            axis,
            Expanded(child: alignLeft ? const SizedBox() : content),
          ],
        ),
      ),
    );
  }

  Widget _buildRating(Map<String, Object?> component, BuildContext context) {
    final value = (component['value'] as num?)?.toDouble() ?? 0;
    final max = (component['max'] as num?)?.toDouble() ?? 5;
    final count = math.max(1, max.round());
    final stars = <Widget>[];
    for (var i = 0; i < count; i++) {
      final fill = value - i;
      IconData icon;
      if (fill >= 1) {
        icon = Icons.star;
      } else if (fill > 0) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      stars.add(Icon(icon, color: Colors.amber));
    }
    return Row(children: stars);
  }

  Widget _buildCarousel(Map<String, Object?> component, BuildContext context) {
    final slides = _resolveCarouselSlides(component, context);
    if (slides.isEmpty) {
      return const SizedBox.shrink();
    }

    final id = component['id'] as String? ?? widget.item.id;
    final controllerKey = 'carousel::$id';
    final viewportFraction =
        (component['viewportFraction'] as num?)?.toDouble() ?? 1.0;
    final controller =
        _pageControllerFor(controllerKey, viewportFraction: viewportFraction);
    final focusNode = _carouselFocusNodeFor(controllerKey);

    final height = (component['height'] as num?)?.toDouble() ?? 220;
    final showIndicators = component['showIndicators'] as bool? ?? true;
    final showControls = component['showControls'] as bool? ?? false;
    final semanticsLabel = component['label'] as String?;
    final loop = component['loop'] as bool? ?? true;
    final autoPlay = component['autoPlay'] as bool? ?? false;
    final autoPlayInterval = Duration(
      milliseconds: (component['autoPlayInterval'] as num?)?.toInt() ?? 5000,
    );

    if ((!autoPlay || slides.length <= 1) &&
        _carouselTimers.containsKey(controllerKey)) {
      _carouselTimers.remove(controllerKey)?.cancel();
    } else if (autoPlay && slides.length > 1) {
      _carouselTimers[controllerKey]?.cancel();
      _carouselTimers[controllerKey] = Timer.periodic(autoPlayInterval, (_) {
        if (!mounted || !controller.hasClients || slides.isEmpty) return;
        final current = controller.page?.round() ?? controller.initialPage;
        final next = loop
            ? (current + 1) % slides.length
            : math.min(current + 1, slides.length - 1);
        if (!loop && next == current) return;
        _animateCarousel(controller, next);
      });
    }

    final pageView = PageView.builder(
      controller: controller,
      itemCount: slides.length,
      itemBuilder: (context, index) {
        final slide = slides[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildCarouselSlide(
            context: context,
            slide: slide,
            index: index,
            count: slides.length,
          ),
        );
      },
    );

    final indicator = showIndicators && slides.length > 1
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SmoothPageIndicator(
              controller: controller,
              count: slides.length,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                dotColor: Theme.of(context).colorScheme.outlineVariant,
                activeDotColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : const SizedBox.shrink();

    final controls = showControls && slides.length > 1
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous slide',
                  onPressed: () {
                    if (!controller.hasClients) return;
                    final current = controller.page?.round() ?? 0;
                    final previous = loop
                        ? (current - 1 + slides.length) % slides.length
                        : math.max(current - 1, 0);
                    if (!loop && previous == current) return;
                    _animateCarousel(controller, previous);
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next slide',
                  onPressed: () {
                    if (!controller.hasClients) return;
                    final current = controller.page?.round() ?? 0;
                    final next = loop
                        ? (current + 1) % slides.length
                        : math.min(current + 1, slides.length - 1);
                    if (!loop && next == current) return;
                    _animateCarousel(controller, next);
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: height, child: pageView),
        indicator,
        controls,
      ],
    );

    final focus = Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) =>
          _handleCarouselKey(event, controller, slides.length, loop),
      child: column,
    );

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: focus,
    );
  }

  Widget _buildVideo(Map<String, Object?> component, BuildContext context) {
    final url = component['src'] as String? ?? component['url'] as String?;
    if (url == null) {
      return const SizedBox.shrink();
    }
    final aspect = (component['aspectRatio'] as num?)?.toDouble();
    final autoplay = component['autoplay'] as bool? ?? false;
    return ChatKitVideoPlayer(
      url: url,
      aspectRatio: aspect,
      autoplay: autoplay,
    );
  }

  Widget _buildAudio(Map<String, Object?> component, BuildContext context) {
    final url = component['src'] as String? ?? component['url'] as String?;
    if (url == null) {
      return const SizedBox.shrink();
    }
    return ChatKitAudioPlayer(url: url);
  }

  Widget _buildMap(Map<String, Object?> component, BuildContext context) {
    final centerData = castMap(component['center']);
    final lat = (centerData['lat'] as num?)?.toDouble();
    final lng = (centerData['lng'] as num?)?.toDouble() ??
        (centerData['lon'] as num?)?.toDouble();
    final markersJson =
        (component['markers'] as List?)?.cast<Map<String, Object?>>() ??
            const [];
    LatLng? center = lat != null && lng != null ? LatLng(lat, lng) : null;
    if (center == null && markersJson.isNotEmpty) {
      final first = markersJson.first;
      final markerLat = (first['lat'] as num?)?.toDouble();
      final markerLng = (first['lng'] as num?)?.toDouble() ??
          (first['lon'] as num?)?.toDouble();
      if (markerLat != null && markerLng != null) {
        center = LatLng(markerLat, markerLng);
      }
    }
    center ??= const LatLng(37.7749, -122.4194);

    final zoom = (component['zoom'] as num?)?.toDouble() ??
        (component['initialZoom'] as num?)?.toDouble() ??
        13.0;
    final tileUrl = component['tileUrl'] as String? ??
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final showControls = component['interactive'] as bool? ?? true;
    final height = (component['height'] as num?)?.toDouble() ?? 220;

    final markers = [
      for (final marker in markersJson) _buildMarker(marker, context),
    ].whereType<Marker>().toList();

    final title = component['title'] as String?;
    final description = component['description'] as String?;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              interactionOptions: showControls
                  ? const InteractionOptions()
                  : const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'chatkit_flutter',
              ),
              if (markers.isNotEmpty)
                MarkerLayer(
                  markers: markers,
                ),
            ],
          ),
          if (title != null || description != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (description != null)
                      Text(
                        description,
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Marker? _buildMarker(
    Map<String, Object?> marker,
    BuildContext context,
  ) {
    final lat = (marker['lat'] as num?)?.toDouble();
    final lng = (marker['lng'] as num?)?.toDouble() ??
        (marker['lon'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      return null;
    }
    final label = marker['label'] as String?;
    final action = marker['onTapAction'] as Map<String, Object?>?;
    final color = _colorFromToken(context, marker['color']) ??
        Theme.of(context).colorScheme.primary;

    return Marker(
      point: LatLng(lat, lng),
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: action != null
            ? () => _dispatchAction(
                  action,
                  context,
                  payloadOverride: {
                    'marker': marker,
                  },
                  preference: _ActionLoadingPreference.none,
                )
            : null,
        child: Column(
          children: [
            const Icon(Icons.location_on, size: 28, color: Colors.black87),
            Icon(Icons.circle, size: 12, color: color),
            if (label != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(Map<String, Object?> component, BuildContext context) {
    final children = component['children'];
    final submitAction = component['onSubmitAction'] as Map<String, Object?>?;
    final fieldNames = _collectFieldNames(children);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._buildChildren(children, context),
        if (submitAction != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton(
                onPressed: _pendingSelfActions.contains(submitAction)
                    ? null
                    : () => _submitForm(
                          submitAction,
                          context,
                          fieldNames: fieldNames,
                        ),
                child: _pendingSelfActions.contains(submitAction)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(submitAction['label'] as String? ?? 'Submit'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFormControl(
      Map<String, Object?> component, BuildContext context) {
    final type = (component['type'] as String? ?? '').toLowerCase();
    final name =
        component['name'] as String? ?? component['id'] as String? ?? '';
    if (name.isNotEmpty) {
      _formComponents[name] = component;
    }
    final disabled = component['disabled'] as bool? ?? false;
    final readOnly = component['readonly'] as bool? ??
        component['readOnly'] as bool? ??
        false;
    final helperText = component['helperText'] as String?;
    final errorText = component['errorText'] as String?;
    final placeholder = component['placeholder'] as String?;
    final required = component['required'] as bool? ?? false;
    final prefixIcon = _iconFromName(component['iconStart'] as String?);
    final suffixIcon = _iconFromName(component['iconEnd'] as String?);
    final maxLength = (component['maxLength'] as num?)?.toInt();
    final fieldError = name.isNotEmpty ? _fieldErrors[name] : null;

    final decoration = InputDecoration(
      labelText: component['label'] as String?,
      hintText: placeholder,
      helperText: fieldError == null ? helperText : null,
      errorText: fieldError ?? errorText,
      counterText: maxLength != null ? '' : null,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
      floatingLabelBehavior:
          required ? FloatingLabelBehavior.always : FloatingLabelBehavior.auto,
    );

    switch (type) {
      case 'input':
      case 'text':
        final controller = _textControllers.putIfAbsent(
          name,
          () => TextEditingController(
            text: (component['defaultValue'] ?? '') as String,
          ),
        );
        final inputKind =
            (component['inputType'] as String? ?? 'text').toLowerCase();
        final obscure = inputKind == 'password';
        final keyboardType = switch (inputKind) {
          'number' || 'numeric' => TextInputType.number,
          'email' => TextInputType.emailAddress,
          'phone' => TextInputType.phone,
          'url' => TextInputType.url,
          _ => TextInputType.text,
        };
        return TextField(
          controller: controller,
          readOnly: readOnly,
          enabled: !disabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: decoration.copyWith(
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
          ),
          onChanged: (value) {
            _setFieldValue(name, value);
            _handleFieldInteraction(name, markTouched: true, validate: true);
          },
        );
      case 'textarea':
        final controller = _textControllers.putIfAbsent(
          name,
          () => TextEditingController(
            text: (component['defaultValue'] ?? '') as String,
          ),
        );
        final rows = (component['rows'] as num?)?.toInt() ?? 4;
        final autoResize = component['autoResize'] as bool? ?? false;
        return TextField(
          controller: controller,
          readOnly: readOnly,
          enabled: !disabled,
          minLines: rows,
          maxLines: autoResize ? null : rows,
          decoration: decoration,
          onChanged: (value) {
            _setFieldValue(name, value);
            _handleFieldInteraction(name, markTouched: true, validate: true);
          },
        );
      case 'select':
      case 'select.single':
      case 'select.native':
        return _buildSelectControl(
          component: component,
          context: context,
          name: name,
          decoration: decoration,
          disabled: disabled || readOnly,
          multi: false,
        );
      case 'select.multi':
        return _buildSelectControl(
          component: component,
          context: context,
          name: name,
          decoration: decoration,
          disabled: disabled || readOnly,
          multi: true,
        );
      case 'chips':
        final options =
            (component['options'] as List?)?.cast<Map<String, Object?>>() ??
                const [];
        final selected = _multiSelectValues.putIfAbsent(name, () {
          final initial = <Object?>[];
          final existing = _formState[name];
          if (existing is List) {
            initial.addAll(existing);
          }
          final defaults = component['defaultValue'];
          if (defaults is List) {
            initial.addAll(defaults);
          }
          return initial.toSet();
        });
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                avatar: option['avatar'] != null
                    ? CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          option['avatar'] as String,
                        ),
                      )
                    : null,
                label: Text(
                  option['label'] as String? ??
                      option['value']?.toString() ??
                      '',
                ),
                selected: selected.contains(option['value']),
                onSelected: disabled
                    ? null
                    : (value) {
                        final optionValue = option['value'];
                        setState(() {
                          if (value) {
                            selected.add(optionValue);
                          } else {
                            selected.remove(optionValue);
                          }
                        });
                        _setFieldValue(name, selected.toList());
                        _handleFieldInteraction(
                          name,
                          markTouched: true,
                          validate: true,
                        );
                      },
              ),
          ],
        );
      case 'radio.group':
        final options =
            (component['options'] as List?)?.cast<Map<String, Object?>>() ??
                const [];
        final defaultValue = component['defaultValue'];
        final selectedValue =
            _formState.containsKey(name) ? _formState[name] : defaultValue;
        _setFieldValue(name, selectedValue);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (component['label'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  component['label'] as String,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            for (final option in options)
              RadioListTile<Object?>(
                value: option['value'],
                dense: true,
                groupValue: selectedValue,
                title: Text(option['label'] as String? ??
                    option['value']?.toString() ??
                    ''),
                onChanged: disabled
                    ? null
                    : (value) {
                        setState(() => _setFieldValue(name, value));
                        _handleFieldInteraction(
                          name,
                          markTouched: true,
                          validate: true,
                        );
                        final action = component['onChangeAction']
                            as Map<String, Object?>?;
                        if (action != null) {
                          _dispatchAction(
                            action,
                            context,
                            payloadOverride: {'value': value},
                            preference: _ActionLoadingPreference.none,
                          );
                        }
                      },
              ),
            if (fieldError != null || helperText != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              ),
          ],
        );
      case 'checkbox':
        final checked = component['defaultValue'] as bool? ?? false;
        _boolValues.putIfAbsent(name, () => checked);
        return CheckboxListTile(
          value: _boolValues[name] ?? checked,
          title: Text(component['label'] as String? ?? name),
          subtitle: fieldError != null || helperText != null
              ? Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                )
              : null,
          onChanged: disabled
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _boolValues[name] = value;
                  });
                  _setFieldValue(name, value);
                  _handleFieldInteraction(
                    name,
                    markTouched: true,
                    validate: true,
                  );
                },
        );
      case 'checkbox.group':
        final options =
            (component['options'] as List?)?.cast<Map<String, Object?>>() ??
                const [];
        final selected = _multiSelectValues.putIfAbsent(name, () {
          final initial = <Object?>[];
          final existing = _formState[name];
          if (existing is List) {
            initial.addAll(existing);
          }
          final defaults = component['defaultValue'];
          if (defaults is List) {
            initial.addAll(defaults);
          }
          return initial.toSet();
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final option in options)
              CheckboxListTile(
                value: selected.contains(option['value']),
                title: Text(option['label'] as String? ??
                    option['value']?.toString() ??
                    ''),
                subtitle: option['description'] != null
                    ? Text(option['description'] as String)
                    : null,
                onChanged: disabled
                    ? null
                    : (value) {
                        final checked = value ?? false;
                        setState(() {
                          if (checked) {
                            selected.add(option['value']);
                          } else {
                            selected.remove(option['value']);
                          }
                        });
                        _setFieldValue(name, selected.toList());
                        _handleFieldInteraction(
                          name,
                          markTouched: true,
                          validate: true,
                        );
                      },
              ),
            if (fieldError != null || helperText != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              ),
          ],
        );
      case 'toggle':
        final checked = component['defaultValue'] as bool? ?? false;
        _boolValues.putIfAbsent(name, () => checked);
        return SwitchListTile(
          value: _boolValues[name] ?? checked,
          title: Text(component['label'] as String? ?? name),
          subtitle: fieldError != null || helperText != null
              ? Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                )
              : null,
          onChanged: disabled
              ? null
              : (value) {
                  setState(() => _boolValues[name] = value);
                  _setFieldValue(name, value);
                  _handleFieldInteraction(
                    name,
                    markTouched: true,
                    validate: true,
                  );
                },
        );
      case 'date.picker':
        final defaultValue = component['defaultValue'] as String?;
        final mode = (component['mode'] as String? ?? 'date').toLowerCase();
        final minDate = DateTime.tryParse(component['min'] as String? ?? '');
        final maxDate = DateTime.tryParse(component['max'] as String? ?? '');
        if (!_formState.containsKey(name) && defaultValue != null) {
          _setFieldValue(name, defaultValue);
        }
        final currentValue = (_formState.containsKey(name)
            ? _formState[name]
            : defaultValue) as String?;
        final displayValue = _formatDateDisplay(currentValue, mode);
        final timeMin = _tryParseTimeOfDay(component['min'] as String?);
        final timeMax = _tryParseTimeOfDay(component['max'] as String?);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(component['label'] as String? ?? 'Select date'),
              subtitle: displayValue != null ? Text(displayValue) : null,
              trailing: Icon(
                mode == 'time' ? Icons.schedule : Icons.calendar_today,
              ),
              onTap: disabled
                  ? null
                  : () async {
                      final now = DateTime.now();
                      if (mode == 'time') {
                        final initialTime = currentValue != null
                            ? _tryParseTimeOfDay(currentValue) ??
                                TimeOfDay.fromDateTime(now)
                            : TimeOfDay.fromDateTime(now);
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initialTime,
                        );
                        if (picked == null) return;
                        if (timeMin != null &&
                            _compareTimeOfDay(picked, timeMin) < 0) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Time must be after '
                                  '${_formatTimeOfDay(timeMin)}.',
                                ),
                              ),
                            );
                          }
                          _handleFieldInteraction(
                            name,
                            markTouched: true,
                            validate: true,
                          );
                          return;
                        }
                        if (timeMax != null &&
                            _compareTimeOfDay(picked, timeMax) > 0) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Time must be before '
                                  '${_formatTimeOfDay(timeMax)}.',
                                ),
                              ),
                            );
                          }
                          _handleFieldInteraction(
                            name,
                            markTouched: true,
                            validate: true,
                          );
                          return;
                        }
                        final value =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        setState(() {
                          _setFieldValue(name, value);
                        });
                        _handleFieldInteraction(
                          name,
                          markTouched: true,
                          validate: true,
                        );
                        return;
                      }
                      final initialDate = currentValue != null
                          ? DateTime.tryParse(currentValue) ?? now
                          : now;
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: minDate ?? DateTime(2000),
                        lastDate: maxDate ?? DateTime(2100),
                      );
                      if (selectedDate == null) {
                        return;
                      }
                      DateTime result = selectedDate;
                      if (mode == 'datetime') {
                        final initialTime = currentValue != null
                            ? _tryParseTimeOfDay(currentValue) ??
                                TimeOfDay.fromDateTime(now)
                            : TimeOfDay.fromDateTime(now);
                        final time = await showTimePicker(
                          context: context,
                          initialTime: initialTime,
                        );
                        if (time != null) {
                          result = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            time.hour,
                            time.minute,
                          );
                        }
                      }
                      final iso = result.toIso8601String();
                      setState(() {
                        _setFieldValue(name, iso);
                      });
                      _handleFieldInteraction(
                        name,
                        markTouched: true,
                        validate: true,
                      );
                    },
            ),
            if (fieldError != null || helperText != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              ),
          ],
        );
      case 'slider':
        final min = (component['min'] as num?)?.toDouble() ?? 0;
        final max = (component['max'] as num?)?.toDouble() ?? 100;
        final step = (component['step'] as num?)?.toDouble() ?? 1;
        final defaultValue =
            (component['defaultValue'] as num?)?.toDouble() ?? min;
        final value = _sliderValues.putIfAbsent(name, () => defaultValue);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (component['label'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(component['label'] as String),
              ),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / step).round().clamp(1, 1000),
              label: value.toStringAsFixed(0),
              onChanged: disabled
                  ? null
                  : (newValue) {
                      setState(() {
                        _sliderValues[name] = newValue;
                      });
                      _setFieldValue(name, newValue);
                      _handleFieldInteraction(
                        name,
                        markTouched: true,
                        validate: true,
                      );
                    },
            ),
            if (fieldError != null || helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              ),
          ],
        );
      case 'stepper':
      case 'number.stepper':
        final min = (component['min'] as num?)?.toInt() ?? 0;
        final max = (component['max'] as num?)?.toInt() ?? 100;
        final step = (component['step'] as num?)?.toInt() ?? 1;
        final defaultValue =
            (component['defaultValue'] as num?)?.toInt() ?? min;
        final value = _stepperValues.putIfAbsent(name, () => defaultValue);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: disabled || value <= min
                      ? null
                      : () {
                          setState(() {
                            final next = (value - step).clamp(min, max);
                            _stepperValues[name] = next;
                            _setFieldValue(name, next);
                          });
                          _handleFieldInteraction(
                            name,
                            markTouched: true,
                            validate: true,
                          );
                        },
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${_stepperValues[name]}',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: disabled || value >= max
                      ? null
                      : () {
                          setState(() {
                            final next = (value + step).clamp(min, max);
                            _stepperValues[name] = next;
                            _setFieldValue(name, next);
                          });
                          _handleFieldInteraction(
                            name,
                            markTouched: true,
                            validate: true,
                          );
                        },
                ),
              ],
            ),
            if (fieldError != null || helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              ),
          ],
        );
      case 'otp':
        final length = (component['length'] as num?)?.toInt() ?? 6;
        final controllers = _otpControllers.putIfAbsent(
          name,
          () => List.generate(
            length,
            (_) => TextEditingController(),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < controllers.length; i++)
                  SizedBox(
                    width: 40,
                    child: TextField(
                      controller: controllers[i],
                      readOnly: readOnly,
                      enabled: !disabled,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(counterText: ''),
                      onChanged: (value) {
                        final code = controllers.map((c) => c.text).join();
                        _setFieldValue(name, code);
                        if (value.isNotEmpty && i < controllers.length - 1) {
                          FocusScope.of(context).nextFocus();
                        }
                        _handleFieldInteraction(
                          name,
                          markTouched: true,
                          validate: true,
                        );
                      },
                    ),
                  ),
              ],
            ),
            if (fieldError != null || helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              ),
          ],
        );
      case 'signature':
        final controller = _signatureControllerFor(name);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Signature(
                  controller: controller,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: controller.isEmpty
                      ? null
                      : () {
                          controller.clear();
                          _setFieldValue(name, null);
                          _handleFieldInteraction(
                            name,
                            markTouched: true,
                            validate: true,
                          );
                        },
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final bytes = await controller.toPngBytes();
                    _setFieldValue(name, bytes);
                    _handleFieldInteraction(
                      name,
                      markTouched: true,
                      validate: true,
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
            if (fieldError != null || helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  fieldError ?? helperText ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fieldError != null
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                ),
              ),
          ],
        );
      case 'file.upload':
        final action = component['onUploadAction'] as Map<String, Object?>?;
        return FilledButton.icon(
          onPressed: disabled
              ? null
              : () {
                  if (action != null) {
                    _dispatchAction(
                      action,
                      context,
                      preference: _ActionLoadingPreference.none,
                    );
                  }
                },
          icon: const Icon(Icons.upload_file),
          label: Text(component['label'] as String? ?? 'Upload'),
        );
      case 'captcha':
        final description =
            component['description'] as String? ?? 'Complete verification';
        final action = component['onVerifyAction'] as Map<String, Object?>?;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: action == null
                      ? null
                      : () => _dispatchAction(
                            action,
                            context,
                            preference: _ActionLoadingPreference.none,
                          ),
                  child: Text(component['buttonLabel'] as String? ?? 'Verify'),
                ),
              ],
            ),
          ),
        );
      default:
        return Text('Unsupported form control ${component['type']}');
    }
  }

  Widget _buildSelectControl({
    required Map<String, Object?> component,
    required BuildContext context,
    required String name,
    required InputDecoration decoration,
    required bool disabled,
    required bool multi,
  }) {
    final focusNode = _selectFocusNodes.putIfAbsent(name, () => FocusNode());
    final options = _normalizeSelectOptions(component);
    final totalOptions =
        options.fold<int>(0, (count, group) => count + group.options.length);
    final placeholder = component['placeholder'] as String?;
    final clearable = component['clearable'] as bool? ?? false;
    final loading = component['loading'] as bool? ?? false;
    final searchableOverride =
        component['searchable'] as bool? ?? component['enableSearch'] as bool?;
    final searchPlaceholder =
        component['searchPlaceholder'] as String? ?? 'Search';
    final emptyText = component['emptyText'] as String? ??
        component['emptyState'] as String? ??
        'No options available';
    final onSearchAction = component['onSearchAction'] as Map<String, Object?>?;
    final onChangeAction = component['onChangeAction'] as Map<String, Object?>?;

    Object? currentValue;
    _SelectOption? currentOption;
    if (!multi) {
      currentValue = _formState.containsKey(name)
          ? _formState[name]
          : component['defaultValue'];
      currentOption = _findSelectOption(options, currentValue);
      if (currentOption == null) {
        currentValue = null;
      } else {
        currentValue = currentOption.value;
      }
      if (!_formState.containsKey(name) || _formState[name] != currentValue) {
        _setFieldValue(name, currentValue);
      }
    }

    final selectedSet = multi
        ? _multiSelectValues.putIfAbsent(name, () {
            final initial = <Object?>[];
            final existing = _formState[name];
            if (existing is List) {
              initial.addAll(existing);
            }
            final defaults = component['defaultValue'];
            if (defaults is List) {
              initial.addAll(defaults);
            }
            return initial.toSet();
          })
        : null;
    if (multi && selectedSet != null) {
      _setFieldValue(name, selectedSet.toList());
    }

    final bool isEmpty =
        multi ? (selectedSet?.isEmpty ?? true) : currentValue == null;

    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.hintColor,
    );

    Widget valueWidget;
    if (multi) {
      final chips = <Widget>[];
      if (selectedSet != null) {
        for (final value in selectedSet) {
          final option = _findSelectOption(options, value);
          final label = option?.label ?? value?.toString() ?? '';
          chips.add(
            InputChip(
              label: Text(label),
              onDeleted: disabled
                  ? null
                  : () {
                      setState(() {
                        selectedSet.remove(value);
                        _setFieldValue(name, selectedSet.toList());
                      });
                      _handleFieldInteraction(
                        name,
                        markTouched: true,
                        validate: true,
                      );
                      if (onChangeAction != null) {
                        _dispatchAction(
                          onChangeAction,
                          context,
                          payloadOverride: {
                            'name': name,
                            'values': selectedSet.toList(),
                          },
                          preference: _ActionLoadingPreference.none,
                        );
                      }
                    },
            ),
          );
        }
      }
      valueWidget = chips.isEmpty
          ? Text(placeholder ?? 'Select options', style: hintStyle)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            );
    } else {
      if (currentOption != null) {
        valueWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentOption.label),
            if (currentOption.description != null &&
                currentOption.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  currentOption.description!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        );
      } else {
        valueWidget = Text(
          placeholder ?? 'Select an option',
          style: hintStyle,
        );
      }
    }

    final suffixChildren = <Widget>[];
    if (!disabled && clearable && !isEmpty) {
      suffixChildren.add(
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear selection',
          onPressed: () {
            if (multi) {
              final target = selectedSet ?? <Object?>{};
              if (target.isEmpty) return;
              setState(() {
                target.clear();
                _setFieldValue(name, const <Object?>[]);
              });
              _handleFieldInteraction(
                name,
                markTouched: true,
                validate: true,
              );
              if (onChangeAction != null) {
                _dispatchAction(
                  onChangeAction,
                  context,
                  payloadOverride: {
                    'name': name,
                    'values': const <Object?>[],
                  },
                  preference: _ActionLoadingPreference.none,
                );
              }
            } else {
              if (_formState[name] == null) return;
              setState(() {
                _setFieldValue(name, null);
              });
              _handleFieldInteraction(
                name,
                markTouched: true,
                validate: true,
              );
              if (onChangeAction != null) {
                _dispatchAction(
                  onChangeAction,
                  context,
                  payloadOverride: {'name': name, 'value': null},
                  preference: _ActionLoadingPreference.none,
                );
              }
            }
          },
        ),
      );
    }
    suffixChildren.add(const Icon(Icons.arrow_drop_down));

    final effectiveDecoration = decoration.copyWith(
      enabled: !disabled,
      suffixIcon: SizedBox(
        width: suffixChildren.length * 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: suffixChildren,
        ),
      ),
      suffixIconConstraints: BoxConstraints(
        minHeight: 40,
        minWidth: suffixChildren.length * 32.0,
      ),
    );

    final bool searchable = searchableOverride ?? totalOptions > 8;

    Future<void> handleTap() async {
      if (disabled) return;
      focusNode.requestFocus();
      if (multi) {
        final result = await _showMultiSelectSheet(
          context: context,
          name: name,
          groups: options,
          selectedValues: selectedSet ?? <Object?>{},
          searchable: searchable,
          loading: loading,
          clearable: clearable,
          searchPlaceholder: searchPlaceholder,
          emptyText: emptyText,
          onSearchAction: onSearchAction,
        );
        focusNode.unfocus();
        if (result == null) return;
        setState(() {
          final target = selectedSet ?? <Object?>{};
          target
            ..clear()
            ..addAll(result.values);
          _multiSelectValues[name] = target;
          _setFieldValue(name, target.toList());
        });
        _handleFieldInteraction(
          name,
          markTouched: true,
          validate: true,
        );
        if (onChangeAction != null) {
          _dispatchAction(
            onChangeAction,
            context,
            payloadOverride: {
              'name': name,
              'values': result.values.toList(),
            },
            preference: _ActionLoadingPreference.none,
          );
        }
      } else {
        final result = await _showSingleSelectSheet(
          context: context,
          name: name,
          groups: options,
          selectedValue: currentValue,
          searchable: searchable,
          loading: loading,
          clearable: clearable,
          searchPlaceholder: searchPlaceholder,
          emptyText: emptyText,
          onSearchAction: onSearchAction,
        );
        focusNode.unfocus();
        if (result == null) return;
        if (result.cleared) {
          if (_formState[name] != null) {
            setState(() {
              _setFieldValue(name, null);
            });
            _handleFieldInteraction(
              name,
              markTouched: true,
              validate: true,
            );
            if (onChangeAction != null) {
              _dispatchAction(
                onChangeAction,
                context,
                payloadOverride: {'name': name, 'value': null},
                preference: _ActionLoadingPreference.none,
              );
            }
          }
        } else {
          final newValue = result.value;
          if (_formState[name] != newValue) {
            setState(() {
              _setFieldValue(name, newValue);
            });
            _handleFieldInteraction(
              name,
              markTouched: true,
              validate: true,
            );
            if (onChangeAction != null) {
              _dispatchAction(
                onChangeAction,
                context,
                payloadOverride: {'name': name, 'value': newValue},
                preference: _ActionLoadingPreference.none,
              );
            }
          }
        }
      }
    }

    return Focus(
      focusNode: focusNode,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : handleTap,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: InputDecorator(
            decoration: effectiveDecoration,
            isFocused: focusNode.hasFocus,
            isEmpty: isEmpty,
            child: valueWidget,
          ),
        ),
      ),
    );
  }

  Future<_SingleSelectResult?> _showSingleSelectSheet({
    required BuildContext context,
    required String name,
    required List<_SelectOptionGroup> groups,
    required Object? selectedValue,
    required bool searchable,
    required bool loading,
    required bool clearable,
    required String searchPlaceholder,
    required String emptyText,
    required Map<String, Object?>? onSearchAction,
  }) async {
    final initialQuery = _selectSearchQuery[name] ?? '';
    final searchController = TextEditingController(text: initialQuery);
    try {
      return await showModalBottomSheet<_SingleSelectResult>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          String query = initialQuery;
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    final filtered = _filterSelectOptions(groups, query);
                    return Column(
                      children: [
                        if (searchable)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: TextField(
                              controller: searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: searchPlaceholder,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setModalState(() => query = value);
                                _handleSelectSearch(
                                  name,
                                  value,
                                  onSearchAction,
                                  context,
                                );
                              },
                            ),
                          ),
                        if (loading) const LinearProgressIndicator(),
                        Expanded(
                          child: filtered.isEmpty && !loading
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      emptyText,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : ListView(
                                  controller: scrollController,
                                  children: [
                                    if (clearable && selectedValue != null)
                                      ListTile(
                                        leading: const Icon(Icons.clear),
                                        title: const Text('Clear selection'),
                                        onTap: () => Navigator.pop(
                                          context,
                                          const _SingleSelectResult(
                                            value: null,
                                            cleared: true,
                                          ),
                                        ),
                                      ),
                                    for (final group in filtered) ...[
                                      if (group.label != null &&
                                          group.label!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            12,
                                            16,
                                            4,
                                          ),
                                          child: Text(
                                            group.label!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      for (final option in group.options)
                                        RadioListTile<Object?>(
                                          value: option.value,
                                          groupValue: selectedValue,
                                          title: Text(option.label),
                                          subtitle: option.description != null
                                              ? Text(option.description!)
                                              : null,
                                          secondary: option.icon != null
                                              ? Icon(
                                                  _iconFromName(option.icon),
                                                )
                                              : null,
                                          onChanged: option.disabled || loading
                                              ? null
                                              : (value) => Navigator.pop(
                                                    context,
                                                    _SingleSelectResult(
                                                      value: option.value,
                                                    ),
                                                  ),
                                        ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<_MultiSelectResult?> _showMultiSelectSheet({
    required BuildContext context,
    required String name,
    required List<_SelectOptionGroup> groups,
    required Set<Object?> selectedValues,
    required bool searchable,
    required bool loading,
    required bool clearable,
    required String searchPlaceholder,
    required String emptyText,
    required Map<String, Object?>? onSearchAction,
  }) async {
    final initialQuery = _selectSearchQuery[name] ?? '';
    final searchController = TextEditingController(text: initialQuery);
    try {
      return await showModalBottomSheet<_MultiSelectResult>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          String query = initialQuery;
          final localSelection = Set<Object?>.from(selectedValues);
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    final filtered = _filterSelectOptions(groups, query);
                    final listChildren = <Widget>[];
                    for (final group in filtered) {
                      if (group.label != null && group.label!.isNotEmpty) {
                        listChildren.add(
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              group.label!,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }
                      for (final option in group.options) {
                        final checked = localSelection.contains(option.value);
                        listChildren.add(
                          CheckboxListTile(
                            value: checked,
                            title: Text(option.label),
                            subtitle: option.description != null
                                ? Text(option.description!)
                                : null,
                            secondary: option.icon != null
                                ? Icon(_iconFromName(option.icon))
                                : null,
                            onChanged: option.disabled || loading
                                ? null
                                : (value) {
                                    final next = value ?? false;
                                    setModalState(() {
                                      if (next) {
                                        localSelection.add(option.value);
                                      } else {
                                        localSelection.remove(option.value);
                                      }
                                    });
                                  },
                          ),
                        );
                      }
                    }

                    return Column(
                      children: [
                        if (searchable)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: searchPlaceholder,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                setModalState(() => query = value);
                                _handleSelectSearch(
                                  name,
                                  value,
                                  onSearchAction,
                                  context,
                                );
                              },
                            ),
                          ),
                        if (loading) const LinearProgressIndicator(),
                        Expanded(
                          child: filtered.isEmpty && !loading
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      emptyText,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : ListView(
                                  controller: scrollController,
                                  children: listChildren,
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, null),
                                child: const Text('Cancel'),
                              ),
                              if (clearable)
                                TextButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    const _MultiSelectResult(
                                      values: <Object?>{},
                                      cleared: true,
                                    ),
                                  ),
                                  child: const Text('Clear'),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () => Navigator.pop(
                                  context,
                                  _MultiSelectResult(
                                    values: Set<Object?>.from(localSelection),
                                    cleared: localSelection.isEmpty,
                                  ),
                                ),
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  void _handleSelectSearch(
    String name,
    String query,
    Map<String, Object?>? action,
    BuildContext context,
  ) {
    _selectSearchQuery[name] = query;
    _selectSearchDebounce[name]?.cancel();
    if (action == null) {
      return;
    }
    _selectSearchDebounce[name] = Timer(
      const Duration(milliseconds: 300),
      () {
        _dispatchAction(
          action,
          context,
          payloadOverride: {
            'name': name,
            'query': query,
          },
          preference: _ActionLoadingPreference.none,
        );
      },
    );
  }

  _ActionLoadingPreference _resolveActionLoadingBehavior(
    Object? raw,
    _ActionLoadingPreference preference,
  ) {
    final normalized = (raw as String?)?.toLowerCase().trim();
    switch (normalized) {
      case 'none':
        return _ActionLoadingPreference.none;
      case 'self':
        return _ActionLoadingPreference.self;
      case 'container':
        return _ActionLoadingPreference.container;
      case 'auto':
      case null:
        if (preference == _ActionLoadingPreference.auto) {
          return _ActionLoadingPreference.self;
        }
        return preference;
      default:
        return preference == _ActionLoadingPreference.auto
            ? _ActionLoadingPreference.self
            : preference;
    }
  }

  List<_SelectOptionGroup> _normalizeSelectOptions(
    Map<String, Object?> component,
  ) {
    final result = <_SelectOptionGroup>[];
    final groupsData = component['groups'];
    if (groupsData is List) {
      for (final entry in groupsData) {
        final map = castMap(entry);
        final groupOptions =
            (map['options'] as List?)?.map(castMap).toList() ?? const [];
        if (groupOptions.isEmpty) continue;
        result.add(
          _SelectOptionGroup(
            label: map['label'] as String? ?? map['title'] as String?,
            options: [
              for (final option in groupOptions) _SelectOption.fromMap(option),
            ],
          ),
        );
      }
    }

    final optionsData = component['options'];
    if (optionsData is List) {
      bool hasNested = false;
      for (final entry in optionsData) {
        if (entry is Map<String, Object?> && entry['options'] is List) {
          hasNested = true;
          final nested = (entry['options'] as List)
              .whereType<Map<String, Object?>>()
              .toList();
          if (nested.isEmpty) continue;
          result.add(
            _SelectOptionGroup(
              label: entry['label'] as String? ??
                  entry['group'] as String? ??
                  entry['title'] as String?,
              options: [
                for (final option in nested) _SelectOption.fromMap(option),
              ],
            ),
          );
        }
      }

      if (!hasNested) {
        final grouped = <String?, List<_SelectOption>>{};
        for (final entry in optionsData) {
          if (entry is Map<String, Object?>) {
            final option = _SelectOption.fromMap(entry);
            final groupLabel =
                entry['group'] as String? ?? entry['section'] as String?;
            grouped.putIfAbsent(groupLabel, () => []).add(option);
          }
        }
        if (grouped.isEmpty) {
          result.add(
            _SelectOptionGroup(
              label: null,
              options: [
                for (final entry in optionsData)
                  if (entry is Map<String, Object?>)
                    _SelectOption.fromMap(entry),
              ],
            ),
          );
        } else {
          for (final entry in grouped.entries) {
            result.add(
              _SelectOptionGroup(
                label: entry.key,
                options: entry.value,
              ),
            );
          }
        }
      }
    }

    return result;
  }

  List<_SelectOptionGroup> _filterSelectOptions(
    List<_SelectOptionGroup> groups,
    String query,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return groups;
    }
    final lower = trimmed.toLowerCase();
    final result = <_SelectOptionGroup>[];
    for (final group in groups) {
      final matches = <_SelectOption>[];
      for (final option in group.options) {
        final label = option.label.toLowerCase();
        final description = option.description?.toLowerCase() ?? '';
        if (label.contains(lower) || description.contains(lower)) {
          matches.add(option);
        }
      }
      if (matches.isNotEmpty) {
        result.add(_SelectOptionGroup(label: group.label, options: matches));
      } else if ((group.label ?? '').toLowerCase().contains(lower)) {
        result.add(group);
      }
    }
    return result;
  }

  _SelectOption? _findSelectOption(
    List<_SelectOptionGroup> groups,
    Object? value,
  ) {
    for (final group in groups) {
      for (final option in group.options) {
        if (option.value == value) {
          return option;
        }
      }
    }
    return null;
  }

  Widget _buildMetadata(Map<String, Object?> component, BuildContext context) {
    final entries =
        (component['entries'] as List?)?.cast<Map<String, Object?>>() ??
            const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text('${entry['label']}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(entry['value'] as String? ?? '')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProgress(Map<String, Object?> component, BuildContext context) {
    final value = (component['value'] as num?)?.toDouble() ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: value == 0 ? null : value.clamp(0, 1)),
        if (component['label'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(component['label'] as String),
          ),
      ],
    );
  }

  Widget _buildIcon(
    Map<String, Object?> component,
    BuildContext context, {
    bool iconOnly = false,
  }) {
    final iconName =
        (component['name'] as String?) ?? (component['icon'] as String?);
    final iconData = _iconFromName(iconName);
    if (iconData == null) {
      return const SizedBox.shrink();
    }

    final size = (component['size'] as num?)?.toDouble();
    final color = _colorFromToken(context, component['color']) ??
        Theme.of(context).iconTheme.color;
    final padding = _edgeInsets(component['padding']);
    final margin = _edgeInsets(component['margin']);
    final tooltip = component['tooltip'] as String?;
    final label = component['label'] as String?;

    Widget result = Icon(iconData, size: size ?? 20, color: color);
    if (!iconOnly && label != null && label.isNotEmpty) {
      result = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          result,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      );
    }
    if (padding != null) {
      result = Padding(padding: padding, child: result);
    }
    if (tooltip != null && tooltip.isNotEmpty) {
      result = Tooltip(message: tooltip, child: result);
    }
    if (margin != null) {
      result = Container(margin: margin, child: result);
    }
    return result;
  }

  Widget _buildBadge(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final label = component['label'] as String? ?? '';
    final variant =
        (component['variant'] as String? ?? 'solid').toLowerCase().trim();
    final sizeToken = (component['size'] as String? ?? 'md').toLowerCase();
    final pill = component['pill'] as bool? ?? false;

    final padding = switch (sizeToken) {
      'sm' => const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      'lg' => const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      _ => const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    };

    final color = _colorFromToken(context, component['color']) ??
        Theme.of(context).colorScheme.primary;
    final Color background;
    final Color border;
    final Color foreground;
    switch (variant) {
      case 'soft':
        background = color.withValues(alpha: 0.15);
        border = color.withValues(alpha: 0.3);
        foreground = color;
        break;
      case 'outline':
        background = Colors.transparent;
        border = color.withValues(alpha: 0.6);
        foreground = color;
        break;
      default:
        background = color;
        border = Colors.transparent;
        foreground = Colors.white;
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(pill ? 999 : 8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildSpacer(Map<String, Object?> component) {
    final minSize = (component['minSize'] as num?)?.toDouble();
    final size = (component['size'] as num?)?.toDouble();
    final height = (component['height'] as num?)?.toDouble() ?? size ?? minSize;
    final width = (component['width'] as num?)?.toDouble() ?? size;
    return SizedBox(
      height: height ?? 16,
      width: width,
    );
  }

  Widget _buildDefinitionList(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final entries =
        (component['entries'] as List?)?.cast<Map<String, Object?>>() ??
            const [];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    (entry['term'] ?? entry['label'] ?? '') as String,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: entry['description'] is Map<String, Object?>
                      ? _buildComponent(
                          entry['description']! as Map<String, Object?>,
                          context,
                        )
                      : Text(
                          (entry['description'] ?? entry['value'] ?? '')
                              as String,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPagination(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final current = (component['page'] as num?)?.toInt() ??
        (component['currentPage'] as num?)?.toInt() ??
        1;
    final total = (component['totalPages'] as num?)?.toInt() ??
        (component['pages'] as num?)?.toInt() ??
        1;
    final action = component['onChangeAction'] as Map<String, Object?>?;
    final allowPrev = current > 1;
    final allowNext = current < total;

    Future<void> changePage(int newPage) async {
      if (action == null) return;
      await _dispatchAction(
        action,
        context,
        payloadOverride: {
          'page': newPage,
        },
        preference: _ActionLoadingPreference.none,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: allowPrev ? () => changePage(current - 1) : null,
        ),
        Text('$current / $total'),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: allowNext ? () => changePage(current + 1) : null,
        ),
      ],
    );
  }

  Widget _buildAccordion(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final id = component['id'] as String? ?? widget.item.id;
    final items =
        (component['items'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final allowMultiple = component['allowMultiple'] as bool? ?? true;

    return ExpansionPanelList(
      expansionCallback: (index, isExpanded) {
        setState(() {
          final key = '$id::$index';
          if (!allowMultiple) {
            for (final entry in items.indexed) {
              _accordionExpanded['$id::${entry.$1}'] =
                  entry.$1 == index ? !isExpanded : false;
            }
          } else {
            _accordionExpanded[key] = !isExpanded;
          }
        });
      },
      children: [
        for (final entry in items.indexed)
          _accordionPanel(entry.$2, context, id, entry.$1),
      ],
    );
  }

  Widget _buildAccordionItem(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    return _buildAccordion(
      {
        'id': component['id'] ?? widget.item.id,
        'items': [component],
      },
      context,
    );
  }

  ExpansionPanel _accordionPanel(
    Map<String, Object?> item,
    BuildContext context,
    String accordionId,
    int index,
  ) {
    final title = item['title'] as String? ?? '';
    final subtitle = item['subtitle'] as String?;
    final defaultExpanded = item['expanded'] as bool? ?? false;
    final key = '$accordionId::$index';
    final isExpanded =
        _accordionExpanded.putIfAbsent(key, () => defaultExpanded);

    return ExpansionPanel(
      canTapOnHeader: true,
      isExpanded: isExpanded,
      headerBuilder: (context, isOpen) {
        return ListTile(
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
        );
      },
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildChildren(item['children'], context),
        ),
      ),
    );
  }

  Widget _buildModal(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final trigger = castMap(component['trigger']);
    final title = component['title'] as String?;
    final placement =
        (component['placement'] as String? ?? 'dialog').toLowerCase();
    final actions =
        (component['actions'] as List?)?.cast<Map<String, Object?>>() ??
            const [];

    Future<void> show() async {
      if (placement == 'sheet') {
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: _buildModalContent(
                context,
                title,
                actions,
                component['children'],
              ),
            );
          },
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: title != null ? Text(title) : null,
              content: SingleChildScrollView(
                child: _buildModalBody(context, component['children']),
              ),
              actions: [
                for (final action in actions)
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _dispatchAction(
                        action,
                        context,
                        preference: _ActionLoadingPreference.none,
                      );
                    },
                    child: Text(action['label'] as String? ?? 'OK'),
                  ),
              ],
            );
          },
        );
      }
    }

    final triggerLabel =
        trigger['label'] as String? ?? component['label'] as String? ?? 'Open';
    return FilledButton(
      onPressed: show,
      child: Text(triggerLabel),
    );
  }

  Widget _buildModalContent(
    BuildContext context,
    String? title,
    List<Map<String, Object?>> actions,
    Object? children,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        _buildModalBody(context, children),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 8,
              children: actions
                  .map(
                    (action) => FilledButton.tonal(
                      onPressed: () => _dispatchAction(
                        action,
                        context,
                        preference: _ActionLoadingPreference.none,
                      ),
                      child: Text(action['label'] as String? ?? 'Action'),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildModalBody(BuildContext context, Object? children) {
    final nodes = _buildChildren(children, context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes,
    );
  }

  Widget _buildWizard(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final steps =
        (component['steps'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final id = component['id'] as String? ?? widget.item.id;
    final current =
        _wizardStepIndex.putIfAbsent(id, () => 0).clamp(0, steps.length - 1);

    Future<void> goTo(int target) async {
      setState(() {
        _wizardStepIndex[id] = target;
      });
      final onChange = component['onStepChangeAction'] as Map<String, Object?>?;
      if (onChange != null) {
        await _dispatchAction(
          onChange,
          context,
          payloadOverride: {'step': target},
          preference: _ActionLoadingPreference.container,
        );
      }
    }

    Future<void> finish() async {
      final action = component['onFinishAction'] as Map<String, Object?>?;
      if (action != null) {
        await _dispatchAction(
          action,
          context,
          preference: _ActionLoadingPreference.container,
        );
      }
    }

    return Stepper(
      currentStep: current,
      onStepTapped: (index) => goTo(index),
      controlsBuilder: (context, details) {
        final isLast = current == steps.length - 1;
        return Row(
          children: [
            FilledButton(
              onPressed: () async {
                if (isLast) {
                  await finish();
                } else {
                  await goTo(current + 1);
                }
              },
              child: Text(isLast
                  ? (component['finishLabel'] as String? ?? 'Finish')
                  : (component['nextLabel'] as String? ?? 'Next')),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: current > 0 ? () => goTo(current - 1) : null,
              child: Text(component['previousLabel'] as String? ?? 'Previous'),
            ),
          ],
        );
      },
      steps: [
        for (final entry in steps.indexed)
          Step(
            isActive: current >= entry.$1,
            title: Text(entry.$2['title'] as String? ?? 'Step ${entry.$1 + 1}'),
            subtitle: entry.$2['subtitle'] != null
                ? Text(entry.$2['subtitle'] as String)
                : null,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildChildren(entry.$2['children'], context),
            ),
          ),
      ],
    );
  }

  Widget _buildWizardStep(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    return _buildWizard(
      {
        'steps': [component],
        'id': component['id'] ?? widget.item.id,
      },
      context,
    );
  }

  Widget _buildSegmentedControl(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final name =
        component['name'] as String? ?? component['id'] as String? ?? '';
    final options =
        (component['options'] as List?)?.cast<Map<String, Object?>>() ??
            const [];
    final disabled = component['disabled'] as bool? ?? false;
    final defaultValue =
        component['defaultValue'] ?? options.firstOrNull?['value'];
    final currentValue =
        _formState.containsKey(name) ? _formState[name] : defaultValue;
    if (!_formState.containsKey(name)) {
      _setFieldValue(name, currentValue);
    }

    return SegmentedButton<Object?>(
      segments: options
          .map(
            (option) => ButtonSegment<Object?>(
              value: option['value'],
              label: Text(option['label'] as String? ??
                  option['value']?.toString() ??
                  ''),
              icon: option['icon'] != null
                  ? Icon(_iconFromName(option['icon'] as String?))
                  : null,
            ),
          )
          .toList(),
      selected: {currentValue},
      onSelectionChanged: disabled
          ? null
          : (values) {
              final selected = values.firstOrNull;
              setState(() {
                _setFieldValue(name, selected);
              });
              final onChange =
                  component['onChangeAction'] as Map<String, Object?>?;
              if (onChange != null && selected != null) {
                _dispatchAction(
                  onChange,
                  context,
                  payloadOverride: {'value': selected},
                  preference: _ActionLoadingPreference.none,
                );
              }
            },
    );
  }

  Widget _buildFileViewer(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final url = component['url'] as String? ?? component['src'] as String?;
    final title = component['title'] as String? ??
        component['name'] as String? ??
        'Attachment';
    final subtitle = component['subtitle'] as String? ??
        component['description'] as String? ??
        component['mimeType'] as String?;
    final previewType = (component['preview'] as String? ?? '').toLowerCase();
    final actions =
        (component['actions'] as List?)?.cast<Map<String, Object?>>() ??
            const [];

    Widget leading;
    if (previewType == 'image' && url != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    } else {
      leading = const Icon(Icons.insert_drive_file);
    }

    return Card(
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: actions.isEmpty
            ? (url != null
                ? IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () => _dispatchAction(
                      {
                        'type': 'open_url',
                        'payload': {'url': url},
                      },
                      context,
                      preference: _ActionLoadingPreference.none,
                    ),
                  )
                : null)
            : Wrap(
                spacing: 4,
                children: actions
                    .map(
                      (action) => IconButton(
                        icon: Icon(
                          _iconFromName(action['icon'] as String?) ??
                              Icons.open_in_new,
                        ),
                        tooltip: action['label'] as String?,
                        onPressed: () => _dispatchAction(
                          action,
                          context,
                          preference: _ActionLoadingPreference.none,
                        ),
                      ),
                    )
                    .toList(),
              ),
        onTap: url != null
            ? () => _dispatchAction(
                  {
                    'type': 'open_url',
                    'payload': {'url': url},
                  },
                  context,
                  preference: _ActionLoadingPreference.none,
                )
            : null,
      ),
    );
  }

  Widget _buildStatus(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final level = (component['level'] as String? ?? 'info').toLowerCase();
    final message =
        component['message'] as String? ?? component['text'] as String? ?? '';
    final iconData = switch (level) {
      'success' => Icons.check_circle,
      'warning' => Icons.warning_amber,
      'danger' || 'error' => Icons.error,
      _ => Icons.info,
    };
    final color = switch (level) {
      'success' => Colors.green,
      'warning' => Colors.orange,
      'danger' || 'error' => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(iconData, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCode(Map<String, Object?> component, BuildContext context) {
    final value = component['value'] as String? ?? '';
    final typography = widget.controller.options.resolvedTheme?.typography;
    final monospace = typography?.monospaceFontFamily ?? 'monospace';
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: monospace,
            ) ??
        TextStyle(fontFamily: monospace);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(value, style: style),
    );
  }

  Widget _buildBlockquote(
      Map<String, Object?> component, BuildContext context) {
    final value = component['value'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 4)),
      ),
      child: Text(value),
    );
  }

  Widget _buildPill(Map<String, Object?> component, BuildContext context) {
    final label = component['label'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }

  Widget _buildTable(Map<String, Object?> component, BuildContext context) {
    final columnData =
        (component['columns'] as List?)?.map((e) => castMap(e)).toList() ??
            const <Map<String, Object?>>[];
    if (columnData.isEmpty) {
      return const SizedBox.shrink();
    }

    final rowData = (component['rows'] as List?)?.toList() ?? const [];
    final tableId =
        component['id'] as String? ?? component['key'] as String? ?? 'table';
    final sortState =
        _tableSortStates.putIfAbsent(tableId, _TableSortState.new);

    final columns = columnData.indexed
        .map((entry) => _TableColumnConfig.fromJson(entry.$1, entry.$2))
        .toList(growable: false);
    if (columns.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = _buildTableRows(rowData, columns, context);
    if (sortState.columnIndex != null &&
        sortState.columnIndex! >= 0 &&
        sortState.columnIndex! < columns.length) {
      final column = columns[sortState.columnIndex!];
      rows.sort(
        (a, b) => _compareSortValues(
          a.cells[column.index].sortValue,
          b.cells[column.index].sortValue,
          sortState.ascending,
        ),
      );
    }

    final theme = Theme.of(context);
    final striped = component['striped'] as bool? ?? false;
    final dense =
        (component['density'] as String?)?.toLowerCase().trim() == 'compact';
    final columnSpacing =
        (component['columnSpacing'] as num?)?.toDouble() ?? (dense ? 20 : 32);
    final horizontalMargin =
        (component['horizontalMargin'] as num?)?.toDouble() ?? 24;
    final caption = component['caption'] as String?;
    final emptyText =
        component['emptyText'] as String? ?? component['emptyState'] as String?;

    final dataColumns = [
      for (final column in columns)
        DataColumn(
          label: column.buildHeader(context),
          numeric: column.numeric,
          tooltip: column.tooltip,
          onSort: column.sortable
              ? (columnIndex, ascending) {
                  setState(() {
                    sortState
                      ..columnIndex = columnIndex
                      ..ascending = ascending;
                  });
                }
              : null,
        ),
    ];

    final dataRows = [
      for (final entry in rows.indexed)
        DataRow.byIndex(
          index: entry.$1,
          color: striped
              ? MaterialStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(MaterialState.selected)) {
                      return theme.colorScheme.primary.withOpacity(0.12);
                    }
                    return entry.$1.isEven
                        ? theme.colorScheme.surfaceVariant.withOpacity(0.35)
                        : null;
                  },
                )
              : null,
          cells: [
            for (final cell in entry.$2.cells) DataCell(cell.child),
          ],
        ),
    ];

    final dataTable = DataTable(
      columns: dataColumns,
      rows: dataRows,
      sortColumnIndex: sortState.columnIndex,
      sortAscending: sortState.ascending,
      columnSpacing: columnSpacing,
      horizontalMargin: horizontalMargin,
      showCheckboxColumn: false,
      dataRowMinHeight: dense ? 40 : null,
      dataRowMaxHeight: dense ? 64 : null,
    );

    final tableWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: dataTable,
    );

    final bodyChildren = <Widget>[
      tableWidget,
      if (rows.isEmpty && emptyText != null && emptyText.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
          ),
        ),
      if (caption != null && caption.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            caption,
            style: theme.textTheme.bodySmall,
          ),
        ),
    ];

    final decorated = _decorateBox(
      context: context,
      component: component,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: bodyChildren,
      ),
    );

    Widget result = decorated.child;
    if (decorated.flex != null) {
      result = _FlexMaybe(flex: decorated.flex!, child: result);
    }
    return result;
  }

  Widget _buildTabs(Map<String, Object?> component, BuildContext context) {
    final tabs =
        (component['tabs'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            tabs: [
              for (final tab in tabs)
                Tab(text: tab['label'] as String? ?? 'Tab'),
            ],
          ),
          SizedBox(
            height: 200,
            child: TabBarView(
              children: [
                for (final tab in tabs)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildChildren(tab['children'], context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(Map<String, Object?> component, BuildContext context) {
    var data =
        (component['data'] as List?)?.map((row) => castMap(row)).toList() ??
            <Map<String, Object?>>[];
    var series =
        (component['series'] as List?)?.map((row) => castMap(row)).toList() ??
            <Map<String, Object?>>[];
    final datasets =
        (component['datasets'] as List?)?.map((row) => castMap(row)).toList() ??
            <Map<String, Object?>>[];

    if (series.isEmpty && datasets.isNotEmpty) {
      final categorySet = <String>{};
      for (final dataset in datasets) {
        final points =
            (dataset['data'] as List?)?.map((point) => castMap(point)) ??
                const Iterable<Map<String, Object?>>.empty();
        for (final point in points) {
          categorySet.add('${point['x']}');
        }
      }
      final categories = categorySet.toList();
      data = [
        for (final category in categories) {'x': category},
      ];

      series = [];
      for (final entry in datasets.indexed) {
        final dataset = entry.$2;
        final label = dataset['label'] as String? ??
            dataset['name'] as String? ??
            'Series ${entry.$1 + 1}';
        final key =
            dataset['dataKey'] as String? ?? dataset['key'] as String? ?? label;
        final type = (dataset['type'] as String? ?? 'bar').toLowerCase();
        series.add({
          'type': type,
          'dataKey': key,
          'label': label,
          'color': dataset['color'],
        });

        final points =
            (dataset['data'] as List?)?.map((point) => castMap(point)) ??
                const Iterable<Map<String, Object?>>.empty();
        for (final row in data) {
          final category = row['x'];
          final match = points.firstWhereOrNull(
            (point) => '${point['x']}' == '$category',
          );
          row[key] = match?['y'];
        }
      }

      if (!component.containsKey('xAxis')) {
        component = {
          ...component,
          'xAxis': 'x',
        };
      }
    }

    if (data.isEmpty || series.isEmpty) {
      return const Text('No chart data available.');
    }

    final xAxisConfig = component['xAxis'];
    String xKey = 'x';
    final Map<Object?, String> xLabels = {};
    bool showXAxis = true;
    if (xAxisConfig is String) {
      xKey = xAxisConfig;
    } else if (xAxisConfig is Map<String, Object?>) {
      xKey = (xAxisConfig['dataKey'] as String?) ?? xKey;
      showXAxis = !(xAxisConfig['hide'] as bool? ?? false);
      final labels = castMap(xAxisConfig['labels']);
      for (final entry in labels.entries) {
        xLabels[entry.key] = entry.value?.toString() ?? '';
      }
    }

    final categories = <String>[];
    final seen = <String>{};
    for (final row in data) {
      final raw = row[xKey];
      final label = (raw ?? '').toString();
      if (seen.add(label)) {
        categories.add(label);
      }
    }
    if (categories.isEmpty) {
      for (var i = 0; i < data.length; i++) {
        categories.add('Row ${i + 1}');
      }
    }

    final palette = <Color>[
      Theme.of(context).colorScheme.primary,
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    final showLegend = component['showLegend'] as bool? ?? true;
    final showTooltip = component['showTooltip'] as bool? ?? true;
    final showYAxis = component['showYAxis'] as bool? ?? true;

    final seriesConfigs = <_SeriesConfig>[];
    var globalMax = 0.0;
    for (final entry in series.indexed) {
      final config = entry.$2;
      final type = (config['type'] as String? ?? 'line').toLowerCase();
      final key = config['dataKey'] as String? ??
          config['key'] as String? ??
          config['label'] as String? ??
          'series_${entry.$1}';
      final label = config['label'] as String? ?? key;
      final color = _colorFromToken(context, config['color']) ??
          palette[entry.$1 % palette.length];
      final values = <double?>[];
      for (final row in data) {
        final value = row[key];
        values.add((value is num) ? value.toDouble() : null);
      }
      final maxValue = values.whereType<double>().fold<double>(0, math.max);
      globalMax = math.max(globalMax, maxValue);

      seriesConfigs.add(
        _SeriesConfig(
          type: type,
          key: key,
          label: label,
          color: color,
          values: values,
        ),
      );
    }

    final allBar = seriesConfigs.every((config) => config.type == 'bar');
    final chartHeight = (component['height'] as num?)?.toDouble() ?? 260;

    Widget chart;
    if (allBar) {
      chart = _buildBarChart(
        context: context,
        categories: categories,
        configs: seriesConfigs,
        showYAxis: showYAxis,
        showXAxis: showXAxis,
        showTooltip: showTooltip,
        xLabels: xLabels,
        maxValue: globalMax,
      );
    } else {
      chart = _buildLineChart(
        context: context,
        categories: categories,
        configs: seriesConfigs,
        showYAxis: showYAxis,
        showXAxis: showXAxis,
        showTooltip: showTooltip,
        xLabels: xLabels,
        maxValue: globalMax,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: chartHeight, child: chart),
        if (showLegend)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final config in seriesConfigs)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: config.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(config.label,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLineChart({
    required BuildContext context,
    required List<String> categories,
    required List<_SeriesConfig> configs,
    required bool showYAxis,
    required bool showXAxis,
    required bool showTooltip,
    required Map<Object?, String> xLabels,
    required double maxValue,
  }) {
    final lineBars = <LineChartBarData>[];
    for (final entry in configs.indexed) {
      if (entry.$2.type == 'bar') continue;
      final isArea = entry.$2.type == 'area';
      final spots = <FlSpot>[];
      for (var i = 0; i < entry.$2.values.length; i++) {
        final value = entry.$2.values[i];
        if (value != null) {
          spots.add(FlSpot(i.toDouble(), value));
        }
      }
      lineBars.add(
        LineChartBarData(
          spots: spots,
          color: entry.$2.color,
          isCurved: entry.$2.type != 'line' ? true : (configs.length <= 1),
          barWidth: 3,
          preventCurveOverShooting: true,
          dotData: FlDotData(
            show: configs.length <= 2,
          ),
          belowBarData: BarAreaData(
            show: isArea,
            color: entry.$2.color.withValues(alpha: 0.20),
          ),
        ),
      );
    }

    final bottomTitles = SideTitles(
      showTitles: showXAxis,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.toInt();
        if (index < 0 || index >= categories.length) {
          return const SizedBox.shrink();
        }
        final raw = categories[index];
        final label = xLabels[raw] ?? raw;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );

    final leftTitles = SideTitles(
      showTitles: showYAxis,
      reservedSize: 40,
      getTitlesWidget: (value, meta) {
        return Text(
          value.toStringAsFixed(0),
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: showTooltip,
          handleBuiltInTouches: true,
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: bottomTitles),
          leftTitles: AxisTitles(sideTitles: leftTitles),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        lineBarsData: lineBars,
        minX: 0,
        maxX: (categories.length - 1).toDouble(),
        minY: 0,
        maxY: maxValue == 0 ? 10 : maxValue * 1.2,
      ),
    );
  }

  Widget _buildBarChart({
    required BuildContext context,
    required List<String> categories,
    required List<_SeriesConfig> configs,
    required bool showYAxis,
    required bool showXAxis,
    required bool showTooltip,
    required Map<Object?, String> xLabels,
    required double maxValue,
  }) {
    final groups = <BarChartGroupData>[];
    for (var index = 0; index < categories.length; index++) {
      final rods = <BarChartRodData>[];
      for (final config in configs.indexed) {
        final value = config.$2.values[index]?.toDouble() ?? 0;
        rods.add(
          BarChartRodData(
            toY: value,
            width: 16,
            borderRadius: BorderRadius.circular(6),
            color: config.$2.color,
          ),
        );
      }
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: rods,
          barsSpace: 8,
        ),
      );
    }

    final bottomTitles = SideTitles(
      showTitles: showXAxis,
      getTitlesWidget: (value, meta) {
        final index = value.toInt();
        if (index < 0 || index >= categories.length) {
          return const SizedBox.shrink();
        }
        final raw = categories[index];
        final label = xLabels[raw] ?? raw;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
      interval: 1,
    );

    final leftTitles = SideTitles(
      showTitles: showYAxis,
      reservedSize: 40,
      getTitlesWidget: (value, meta) {
        return Text(
          value.toStringAsFixed(0),
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(enabled: showTooltip),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: bottomTitles),
          leftTitles: AxisTitles(sideTitles: leftTitles),
        ),
        barGroups: groups,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        maxY: maxValue == 0 ? 10 : maxValue * 1.2,
      ),
    );
  }

  Widget? _buildListStatus(Object? status, BuildContext context) {
    final widget = _buildWidgetStatus(status, context);
    if (widget != null) {
      return widget;
    }
    if (status is String && status.isNotEmpty) {
      return Text(
        status,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      );
    }
    return null;
  }

  EdgeInsets _cardPaddingForSize(String size) {
    switch (size) {
      case 'sm':
        return const EdgeInsets.all(12);
      case 'lg':
        return const EdgeInsets.all(24);
      case 'full':
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 28);
      default:
        return const EdgeInsets.all(16);
    }
  }

  Widget? _buildWidgetStatus(Object? status, BuildContext context) {
    if (status == null) return null;
    if (status is String) {
      if (status.isEmpty) return null;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withValues(
                alpha: 0.6,
              ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      );
    }
    if (status is Map<String, Object?>) {
      final text = status['text'] as String? ?? '';
      if (text.isEmpty) return null;
      final iconName = status['icon'] as String?;
      final faviconUrl = status['favicon'] as String?;
      final frame = status['frame'] as bool? ?? false;
      final theme = Theme.of(context);
      final badgeColor =
          theme.colorScheme.surfaceVariant.withValues(alpha: 0.85);
      final outline = theme.colorScheme.outlineVariant.withOpacity(0.6);

      Widget? leading;
      if (faviconUrl != null && faviconUrl.isNotEmpty) {
        leading = Container(
          width: 20,
          height: 20,
          padding: frame ? const EdgeInsets.all(2) : EdgeInsets.zero,
          decoration: frame
              ? BoxDecoration(
                  border: Border.all(color: outline),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(imageUrl: faviconUrl, fit: BoxFit.cover),
          ),
        );
      } else if (iconName != null && iconName.isNotEmpty) {
        final icon = _iconFromName(iconName);
        if (icon != null) {
          leading = Icon(icon, size: 18, color: theme.colorScheme.primary);
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return null;
  }

  Widget _buildCardActionButton({
    required BuildContext context,
    required String label,
    required Map<String, Object?> action,
    required bool includeForm,
    required bool isPrimary,
    required String actionKey,
  }) {
    final hasAction = action.isNotEmpty;
    final isLoading = _cardActionPendingKey == actionKey;
    final onPressed = hasAction && !isLoading
        ? () => _handleCardAction(
              action,
              context,
              includeForm: includeForm,
              pendingKey: actionKey,
            )
        : null;

    final buttonChild = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : Text(label);

    if (isPrimary) {
      return FilledButton(
        onPressed: onPressed,
        child: buttonChild,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      child: buttonChild,
    );
  }

  Future<void> _handleCardAction(
    Map<String, Object?> action,
    BuildContext context, {
    required bool includeForm,
    required String pendingKey,
  }) async {
    setState(() => _cardActionPendingKey = pendingKey);
    try {
      await _dispatchAction(
        action,
        context,
        includeFormState: includeForm,
        preference: _ActionLoadingPreference.container,
      );
    } finally {
      if (mounted && _cardActionPendingKey == pendingKey) {
        setState(() => _cardActionPendingKey = null);
      }
    }
  }

  Alignment _alignmentFromTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.justify:
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.left:
        return Alignment.centerLeft;
    }
  }

  FocusNode _carouselFocusNodeFor(String key) {
    return _carouselFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'carousel:$key'),
    );
  }

  List<_CarouselSlide> _resolveCarouselSlides(
    Map<String, Object?> component,
    BuildContext context,
  ) {
    final items = (component['items'] as List?)
        ?.map((item) => castMap(item))
        .toList(growable: false);
    if (items != null && items.isNotEmpty) {
      return [
        for (final item in items)
          _CarouselSlide(
            identifier: item['key'] as String?,
            child: _buildCarouselSlideContent(item, context),
            title: item['title'] as String?,
            subtitle: item['subtitle'] as String?,
            description:
                item['description'] as String? ?? item['caption'] as String?,
            badge: item['badge'] as String?,
            tags: (item['tags'] as List?)
                    ?.whereType<String>()
                    .toList(growable: false) ??
                const [],
          ),
      ];
    }

    final children = _buildChildren(component['children'], context);
    return [
      for (final child in children) _CarouselSlide(child: child),
    ];
  }

  Widget _buildCarouselSlide({
    required BuildContext context,
    required _CarouselSlide slide,
    required int index,
    required int count,
  }) {
    Widget content = FocusTraversalGroup(
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: slide.child,
      ),
    );

    if (slide.hasMeta) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          content,
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildCarouselMeta(slide, context),
          ),
        ],
      );
    }

    return Semantics(
      label: slide.title ?? 'Slide ${index + 1}',
      value: slide.subtitle ?? slide.description,
      hint: 'Slide ${index + 1} of $count',
      child: content,
    );
  }

  Widget _buildCarouselMeta(
    _CarouselSlide slide,
    BuildContext context,
  ) {
    if (!slide.hasMeta) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final content = <Widget>[];
    if (slide.badge != null && slide.badge!.isNotEmpty) {
      content.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            slide.badge!,
            style: textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      content.add(const SizedBox(height: 8));
    }

    if (slide.title != null && slide.title!.isNotEmpty) {
      content.add(
        Text(
          slide.title!,
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (slide.subtitle != null && slide.subtitle!.isNotEmpty) {
      content.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            slide.subtitle!,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
      );
    }

    if (slide.description != null && slide.description!.isNotEmpty) {
      content.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            slide.description!,
            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ),
      );
    }

    if (slide.tags.isNotEmpty) {
      content.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final tag in slide.tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: content,
      ),
    );
  }

  Widget _buildCarouselSlideContent(
    Map<String, Object?> item,
    BuildContext context,
  ) {
    final children = _buildChildren(item['children'], context);
    if (children.isNotEmpty) {
      if (children.length == 1) {
        return children.first;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    final child = item['child'];
    if (child is Map<String, Object?>) {
      return _buildComponent(child, context);
    }
    final imageUrl = item['image'] as String? ?? item['src'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover);
    }
    final text = item['text'] as String?;
    if (text != null && text.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  KeyEventResult _handleCarouselKey(
    KeyEvent event,
    PageController controller,
    int slideCount,
    bool loop,
  ) {
    if (slideCount <= 1 || !controller.hasClients) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final current = controller.page?.round() ?? controller.initialPage;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final next = loop
          ? (current + 1) % slideCount
          : math.min(current + 1, slideCount - 1);
      if (!loop && next == current) return KeyEventResult.ignored;
      _animateCarousel(controller, next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final previous = loop
          ? (current - 1 + slideCount) % slideCount
          : math.max(current - 1, 0);
      if (!loop && previous == current) return KeyEventResult.ignored;
      _animateCarousel(controller, previous);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _animateCarousel(controller, 0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _animateCarousel(controller, slideCount - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _animateCarousel(PageController controller, int page) {
    if (!controller.hasClients) return;
    controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  _TimelineAlignment _resolveTimelineAlignment(
    String? token,
    _TimelineAlignment fallback,
  ) {
    final normalized = token?.toLowerCase().trim();
    switch (normalized) {
      case 'start':
      case 'left':
        return _TimelineAlignment.start;
      case 'alternate':
      case 'center':
        return _TimelineAlignment.alternate;
      case 'end':
      case 'right':
        return _TimelineAlignment.end;
      default:
        return fallback;
    }
  }

  _TimelineLineStyle _resolveTimelineLineStyle(
    String? token,
    _TimelineLineStyle fallback,
  ) {
    final normalized = token?.toLowerCase().trim();
    switch (normalized) {
      case 'dashed':
      case 'dotted':
        return _TimelineLineStyle.dashed;
      default:
        return fallback;
    }
  }

  List<_TableRowModel> _buildTableRows(
    List<Object?> rows,
    List<_TableColumnConfig> columns,
    BuildContext context,
  ) {
    final results = <_TableRowModel>[];
    for (final row in rows) {
      final cells = <_TableCellData>[];
      for (final column in columns) {
        final value = _resolveTableCellValue(row, column);
        cells.add(
          _TableCellData(
            child: _buildTableCellWidget(value, column, context),
            sortValue: _extractTableSortValue(value),
          ),
        );
      }
      results.add(_TableRowModel(cells: cells));
    }
    return results;
  }

  Object? _resolveTableCellValue(Object? row, _TableColumnConfig column) {
    if (row is Map<String, Object?>) {
      final cells = row['cells'];
      if (cells is List && column.index < cells.length) {
        final value = cells[column.index];
        return value is Map<String, Object?> ? value : value;
      }
      final values = row['values'];
      if (values is Map<String, Object?> && column.dataKey != null) {
        final key = column.dataKey!;
        if (values.containsKey(key)) {
          return values[key];
        }
      }
      if (column.dataKey != null && row.containsKey(column.dataKey)) {
        return row[column.dataKey!];
      }
      if (row.containsKey(column.label)) {
        return row[column.label];
      }
      if (row.containsKey('value')) {
        return row['value'];
      }
      return null;
    }
    if (row is List) {
      if (column.index < row.length) {
        final value = row[column.index];
        return value is Map<String, Object?> ? value : value;
      }
      return null;
    }
    return row;
  }

  Object? _extractTableSortValue(Object? value) {
    if (value is Map<String, Object?>) {
      final map = value;
      if (map['sortValue'] != null) return map['sortValue'];
      if (map['value'] != null) return map['value'];
      if (map['text'] != null) return map['text'];
      if (map['label'] != null) return map['label'];
    }
    return value;
  }

  Widget _buildTableCellWidget(
    Object? value,
    _TableColumnConfig column,
    BuildContext context,
  ) {
    if (value is Map) {
      final map = castMap(value);
      if (map.containsKey('type')) {
        return _buildComponent(map, context);
      }
      final status = _buildWidgetStatus(map['status'], context);
      if (status != null) {
        return status;
      }
      final text = map['text'] as String? ??
          map['label'] as String? ??
          map['value']?.toString() ??
          '';
      final iconName = map['icon'] as String?;
      final icon = _iconFromName(iconName);
      final iconColor = _colorFromToken(context, map['iconColor']);
      final alignToken =
          (map['align'] as String? ?? map['textAlign'] as String?)
              ?.toLowerCase()
              .trim();
      final textAlign = switch (alignToken) {
        'center' => TextAlign.center,
        'end' || 'right' => TextAlign.right,
        'start' || 'left' => TextAlign.left,
        _ => column.textAlign ??
            (column.numeric ? TextAlign.right : TextAlign.left),
      };
      final alignment = _alignmentFromTextAlign(textAlign);
      Widget labelWidget = Text(
        text,
        textAlign: textAlign,
        style: Theme.of(context).textTheme.bodyMedium,
      );
      if (icon != null) {
        labelWidget = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: textAlign == TextAlign.right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: iconColor ?? Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 6),
            Flexible(child: labelWidget),
          ],
        );
      }
      return Align(
        alignment: alignment,
        child: labelWidget,
      );
    }

    if (value is Widget) {
      return value;
    }

    final textAlign =
        column.textAlign ?? (column.numeric ? TextAlign.right : TextAlign.left);
    return Align(
      alignment: _alignmentFromTextAlign(textAlign),
      child: Text(
        value?.toString() ?? '',
        textAlign: textAlign,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  int _compareSortValues(Object? a, Object? b, bool ascending) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    int result;
    if (a is num && b is num) {
      result = a.compareTo(b);
    } else if (a is DateTime && b is DateTime) {
      result = a.compareTo(b);
    } else if (a is bool && b is bool) {
      result = (a ? 1 : 0).compareTo(b ? 1 : 0);
    } else if (a is String && b is String) {
      result = a.toLowerCase().compareTo(b.toLowerCase());
    } else {
      final aString = a.toString().toLowerCase();
      final bString = b.toString().toLowerCase();
      result = aString.compareTo(bString);
    }

    return ascending ? result : -result;
  }

  Axis _resolveAxis(Map<String, Object?> component) {
    final type = (component['type'] as String? ?? '').toLowerCase();
    final direction = (component['direction'] as String?)?.toLowerCase().trim();
    if (type == 'row') {
      return Axis.horizontal;
    }
    if (type == 'column' || type == 'col') {
      return Axis.vertical;
    }
    if (direction == 'row' || direction == 'horizontal') {
      return Axis.horizontal;
    }
    if (direction == 'column' ||
        direction == 'col' ||
        direction == 'vertical') {
      return Axis.vertical;
    }
    return Axis.vertical;
  }

  CrossAxisAlignment _mapCrossAxisAlignment(String? align, Axis axis) {
    switch (align) {
      case 'center':
        return CrossAxisAlignment.center;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'baseline':
        return axis == Axis.horizontal
            ? CrossAxisAlignment.baseline
            : CrossAxisAlignment.start;
      default:
        return CrossAxisAlignment.start;
    }
  }

  MainAxisAlignment _mapMainAxisAlignment(String? justify) {
    switch (justify) {
      case 'center':
        return MainAxisAlignment.center;
      case 'end':
        return MainAxisAlignment.end;
      case 'between':
        return MainAxisAlignment.spaceBetween;
      case 'around':
        return MainAxisAlignment.spaceAround;
      case 'evenly':
        return MainAxisAlignment.spaceEvenly;
      default:
        return MainAxisAlignment.start;
    }
  }

  WrapAlignment _mapWrapAlignment(String? value) {
    switch (value) {
      case 'center':
        return WrapAlignment.center;
      case 'end':
        return WrapAlignment.end;
      case 'between':
        return WrapAlignment.spaceBetween;
      case 'around':
        return WrapAlignment.spaceAround;
      case 'evenly':
        return WrapAlignment.spaceEvenly;
      default:
        return WrapAlignment.start;
    }
  }

  WrapCrossAlignment _mapWrapCrossAlignment(String? value) {
    switch (value) {
      case 'center':
        return WrapCrossAlignment.center;
      case 'end':
        return WrapCrossAlignment.end;
      default:
        return WrapCrossAlignment.start;
    }
  }

  List<Widget> _withGapBetween(
    List<Widget> children,
    double gap,
    Axis axis,
  ) {
    if (children.length <= 1 || gap <= 0) {
      return children;
    }
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(
          axis == Axis.horizontal
              ? SizedBox(width: gap)
              : SizedBox(height: gap),
        );
      }
      spaced.add(children[i]);
    }
    return spaced;
  }

  double? _spacingToDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty ||
          normalized == 'auto' ||
          normalized == 'fit-content') {
        return null;
      }
      final scaleValue = _spacingScale[normalized];
      if (scaleValue != null) {
        return scaleValue;
      }
      if (normalized.endsWith('rem')) {
        final number = double.tryParse(
          normalized.substring(0, normalized.length - 3).trim(),
        );
        if (number != null) {
          return number * 16;
        }
      }
      if (normalized.endsWith('px')) {
        final number = double.tryParse(
          normalized.substring(0, normalized.length - 2).trim(),
        );
        if (number != null) {
          return number;
        }
      }
      final number = double.tryParse(normalized);
      if (number != null) {
        return number;
      }
      final match = RegExp(r'(-?\d+(\.\d+)?)').firstMatch(normalized);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  double? _parseDimension(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty ||
          normalized == 'auto' ||
          normalized == 'fit-content') {
        return null;
      }
      if (normalized == 'full' || normalized == '100%') {
        return double.infinity;
      }
      if (normalized.endsWith('%')) {
        final number = double.tryParse(
          normalized.substring(0, normalized.length - 1).trim(),
        );
        if (number != null && number >= 100) {
          return double.infinity;
        }
        return null;
      }
      final scaleValue = _spacingScale[normalized];
      if (scaleValue != null) {
        return scaleValue;
      }
      if (normalized.endsWith('rem')) {
        final number = double.tryParse(
          normalized.substring(0, normalized.length - 3).trim(),
        );
        if (number != null) {
          return number * 16;
        }
      }
      if (normalized.endsWith('px')) {
        final number = double.tryParse(
          normalized.substring(0, normalized.length - 2).trim(),
        );
        if (number != null) {
          return number;
        }
      }
      final explicit = double.tryParse(normalized);
      if (explicit != null) {
        return explicit;
      }
      final match = RegExp(r'(-?\d+(\.\d+)?)').firstMatch(normalized);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
      return null;
    }
    return _spacingToDouble(raw);
  }

  double? _parseAspectRatio(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      final normalized = raw.trim();
      if (normalized.contains('/')) {
        final parts = normalized.split('/');
        if (parts.length == 2) {
          final left = double.tryParse(parts[0]);
          final right = double.tryParse(parts[1]);
          if (left != null && right != null && right != 0) {
            return left / right;
          }
        }
      }
      return double.tryParse(normalized);
    }
    return null;
  }

  BorderRadius? _borderRadiusFrom(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      return BorderRadius.circular(raw.toDouble());
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'none') {
        return BorderRadius.zero;
      }
      if (normalized == 'full' || normalized == '100%') {
        return BorderRadius.circular(999);
      }
      final value = _spacingToDouble(raw);
      if (value != null) {
        return BorderRadius.circular(value);
      }
    }
    if (raw is Map<String, Object?>) {
      double? resolve(Object? value) => _spacingToDouble(value);
      final topLeft = resolve(raw['topLeft']) ?? resolve(raw['tl']);
      final topRight = resolve(raw['topRight']) ?? resolve(raw['tr']);
      final bottomLeft = resolve(raw['bottomLeft']) ?? resolve(raw['bl']);
      final bottomRight = resolve(raw['bottomRight']) ?? resolve(raw['br']);
      if (topLeft == null &&
          topRight == null &&
          bottomLeft == null &&
          bottomRight == null) {
        return null;
      }
      return BorderRadius.only(
        topLeft: Radius.circular(topLeft ?? 0),
        topRight: Radius.circular(topRight ?? 0),
        bottomLeft: Radius.circular(bottomLeft ?? 0),
        bottomRight: Radius.circular(bottomRight ?? 0),
      );
    }
    return null;
  }

  BoxBorder? _borderFrom(BuildContext context, Object? raw) {
    if (raw == null) return null;
    BorderSide? parseSide(Object? value) {
      if (value == null) return null;
      if (value is num || value is String) {
        final width = _spacingToDouble(value) ?? 1;
        final color = Theme.of(context).dividerColor;
        return BorderSide(width: width, color: color);
      }
      if (value is Map<String, Object?>) {
        final width = _spacingToDouble(value['size']) ?? 1;
        final color = _colorFromToken(context, value['color']) ??
            Theme.of(context).dividerColor;
        return BorderSide(width: width, color: color);
      }
      return null;
    }

    if (raw is num || raw is String) {
      final side = parseSide(raw) ?? BorderSide.none;
      return side == BorderSide.none
          ? null
          : Border.all(width: side.width, color: side.color);
    }

    if (raw is Map<String, Object?>) {
      if (raw.containsKey('size') || raw.containsKey('color')) {
        final side = parseSide(raw);
        if (side == null || side == BorderSide.none) {
          return null;
        }
        return Border.all(width: side.width, color: side.color);
      }

      final horizontal = parseSide(raw['x']);
      final vertical = parseSide(raw['y']);

      final top = parseSide(raw['top']) ?? vertical ?? BorderSide.none;
      final bottom = parseSide(raw['bottom']) ?? vertical ?? BorderSide.none;
      final left = parseSide(raw['left']) ?? horizontal ?? BorderSide.none;
      final right = parseSide(raw['right']) ?? horizontal ?? BorderSide.none;

      if (top == BorderSide.none &&
          bottom == BorderSide.none &&
          left == BorderSide.none &&
          right == BorderSide.none) {
        return null;
      }

      return Border(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
      );
    }

    return null;
  }

  BoxConstraints? _boxConstraintsFrom(Map<String, Object?> component) {
    double? minWidth = _parseDimension(component['minWidth']);
    double? minHeight = _parseDimension(component['minHeight']);
    double? maxWidth = _parseDimension(component['maxWidth']);
    double? maxHeight = _parseDimension(component['maxHeight']);

    final minSize = _parseDimension(component['minSize']);
    final maxSize = _parseDimension(component['maxSize']);

    if (minSize != null) {
      minWidth ??= minSize;
      minHeight ??= minSize;
    }
    if (maxSize != null) {
      maxWidth ??= maxSize;
      maxHeight ??= maxSize;
    }

    if (minWidth == null &&
        minHeight == null &&
        maxWidth == null &&
        maxHeight == null) {
      return null;
    }

    return BoxConstraints(
      minWidth: minWidth ?? 0,
      minHeight: minHeight ?? 0,
      maxWidth: maxWidth ?? double.infinity,
      maxHeight: maxHeight ?? double.infinity,
    );
  }

  _DecoratedBoxResult _decorateBox({
    required BuildContext context,
    required Map<String, Object?> component,
    required Widget child,
    bool applyMargin = true,
  }) {
    final padding = _edgeInsets(component['padding']);
    final marginValue = _edgeInsets(component['margin']);
    final background = _colorFromToken(context, component['background']);
    final border = _borderFrom(context, component['border']);
    final borderRadius = _borderRadiusFrom(component['radius']);
    final width = _parseDimension(component['width'] ?? component['size']);
    final height = _parseDimension(component['height'] ?? component['size']);
    final constraints = _boxConstraintsFrom(component);
    final aspectRatio = _parseAspectRatio(component['aspectRatio']);
    final flex = _parseFlex(component['flex']);

    final decoration =
        (background != null || border != null || borderRadius != null)
            ? BoxDecoration(
                color: background,
                border: border,
                borderRadius: borderRadius,
              )
            : null;

    final needsContainer = padding != null ||
        decoration != null ||
        width != null ||
        height != null ||
        constraints != null ||
        (applyMargin && marginValue != null);

    Widget result = child;
    if (needsContainer) {
      result = Container(
        margin: applyMargin ? marginValue : null,
        padding: padding,
        decoration: decoration,
        width: width,
        height: height,
        constraints: constraints,
        clipBehavior: borderRadius != null ? Clip.antiAlias : Clip.none,
        child: result,
      );
    }

    if (aspectRatio != null) {
      result = AspectRatio(aspectRatio: aspectRatio, child: result);
    }

    return _DecoratedBoxResult(
      child: result,
      flex: flex,
      margin: applyMargin ? null : marginValue,
      borderRadius: borderRadius,
    );
  }

  int? _parseFlex(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      final value = raw.toInt();
      return value > 0 ? value : null;
    }
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty || normalized == 'auto') {
        return null;
      }
      final number = int.tryParse(normalized);
      if (number != null) {
        return number > 0 ? number : null;
      }
      final match = RegExp(r'(\d+)').firstMatch(normalized);
      if (match != null) {
        final value = int.tryParse(match.group(1)!);
        if (value != null && value > 0) {
          return value;
        }
      }
    }
    return null;
  }

  List<Widget> _buildChildren(Object? children, BuildContext context) {
    if (children is List) {
      return [
        for (final child in children)
          if (child is Map<String, Object?>) _buildComponent(child, context),
      ];
    }
    return const [];
  }

  EdgeInsetsGeometry? _edgeInsets(Object? value) {
    final uniform = _spacingToDouble(value);
    if (uniform != null) {
      return EdgeInsets.all(uniform);
    }
    if (value is Map<String, Object?>) {
      final horizontal = _spacingToDouble(value['x']);
      final vertical = _spacingToDouble(value['y']);
      final top = _spacingToDouble(value['top']) ?? vertical ?? 0;
      final bottom = _spacingToDouble(value['bottom']) ?? vertical ?? 0;
      final left = _spacingToDouble(value['left']) ?? horizontal ?? 0;
      final right = _spacingToDouble(value['right']) ?? horizontal ?? 0;
      return EdgeInsets.only(
        top: top,
        right: right,
        bottom: bottom,
        left: left,
      );
    }
    return null;
  }

  Key _resolveComponentKey(Map<String, Object?> component) {
    final key = component['key'];
    if (key is String && key.isNotEmpty) {
      return ValueKey<String>('widget.key.$key');
    }
    final id = component['id'];
    if (id is String && id.isNotEmpty) {
      return ValueKey<String>('widget.id.$id');
    }
    return ValueKey<String>(jsonEncode(component));
  }

  void _setFieldValue(String name, Object? value) {
    if (name.isEmpty) return;
    _formState[name] = value;
  }

  void _handleFieldInteraction(
    String name, {
    bool markTouched = false,
    bool validate = false,
  }) {
    if (name.isEmpty) return;
    if (markTouched) {
      _touchedFields.add(name);
    }
    if (!(validate || _touchedFields.contains(name))) {
      return;
    }
    final value = _formState[name];
    final error = _computeFieldError(name, value);
    final previousError = _fieldErrors[name];
    if (previousError == error || (previousError == null && error == null)) {
      return;
    }
    if (mounted) {
      setState(() {
        if (error != null && error.isNotEmpty) {
          _fieldErrors[name] = error;
        } else {
          _fieldErrors.remove(name);
        }
      });
    } else {
      if (error != null && error.isNotEmpty) {
        _fieldErrors[name] = error;
      } else {
        _fieldErrors.remove(name);
      }
    }
  }

  bool _validateFields(
    Iterable<String> fieldNames, {
    bool markTouched = false,
  }) {
    bool hasError = false;
    final nextErrors = <String, String>{};
    for (final name in fieldNames) {
      if (name.isEmpty) continue;
      if (markTouched) {
        _touchedFields.add(name);
      }
      final value = _formState[name];
      final error = _computeFieldError(name, value);
      if (error != null && error.isNotEmpty) {
        hasError = true;
        nextErrors[name] = error;
      }
    }

    if (mounted) {
      setState(() {
        for (final name in fieldNames) {
          if (nextErrors.containsKey(name)) {
            _fieldErrors[name] = nextErrors[name]!;
          } else {
            _fieldErrors.remove(name);
          }
        }
      });
    } else {
      for (final entry in nextErrors.entries) {
        _fieldErrors[entry.key] = entry.value;
      }
      for (final name in fieldNames) {
        if (!nextErrors.containsKey(name)) {
          _fieldErrors.remove(name);
        }
      }
    }

    return !hasError;
  }

  String? _computeFieldError(String name, Object? value) {
    final component = _formComponents[name];
    if (component == null) {
      return null;
    }
    final type = (component['type'] as String? ?? '').toLowerCase();
    final required = component['required'] as bool? ?? false;
    final errorText = component['errorText'] as String?;

    String requiredMessage(String fallback) =>
        errorText ?? component['requiredErrorText'] as String? ?? fallback;

    switch (type) {
      case 'checkbox':
      case 'toggle':
        final checked = value as bool? ?? false;
        if (required && !checked) {
          return requiredMessage('This option must be selected.');
        }
        return null;
    }

    if (_isValueEmpty(value)) {
      return required ? requiredMessage('This field is required.') : null;
    }

    switch (type) {
      case 'input':
      case 'text':
      case 'textarea':
        final stringValue = value?.toString() ?? '';
        final pattern = component['pattern'] as String?;
        if (pattern != null && pattern.isNotEmpty) {
          try {
            final regexp = RegExp(pattern);
            if (!regexp.hasMatch(stringValue)) {
              return component['patternErrorText'] as String? ??
                  'Value does not match the required pattern.';
            }
          } catch (_) {
            // ignore invalid regex.
          }
        }
        final minLength = (component['minLength'] as num?)?.toInt();
        if (minLength != null && stringValue.length < minLength) {
          return component['minLengthErrorText'] as String? ??
              'Must be at least $minLength characters.';
        }
        final maxLength = (component['maxLength'] as num?)?.toInt();
        if (maxLength != null && stringValue.length > maxLength) {
          return component['maxLengthErrorText'] as String? ??
              'Must be at most $maxLength characters.';
        }
        final inputType =
            (component['inputType'] as String? ?? '').toLowerCase();
        if (inputType == 'number' || inputType == 'numeric') {
          final number = num.tryParse(stringValue);
          if (number == null) {
            return 'Enter a valid number.';
          }
          final min = (component['min'] as num?)?.toDouble();
          if (min != null && number < min) {
            return component['minErrorText'] as String? ??
                'Must be at least ${min.toStringAsFixed(0)}.';
          }
          final max = (component['max'] as num?)?.toDouble();
          if (max != null && number > max) {
            return component['maxErrorText'] as String? ??
                'Must be less than or equal to ${max.toStringAsFixed(0)}.';
          }
        }
        return null;
      case 'select':
      case 'select.single':
      case 'select.native':
      case 'radio.group':
        if (value == null || (value is String && value.trim().isEmpty)) {
          return requiredMessage('Please make a selection.');
        }
        return null;
      case 'select.multi':
      case 'chips':
      case 'checkbox.group':
        final listValue =
            value is List ? value : (value is Iterable ? value.toList() : null);
        if (listValue == null || listValue.isEmpty) {
          return requiredMessage('Select at least one option.');
        }
        return null;
      case 'otp':
        final stringValue = value?.toString() ?? '';
        final length = (component['length'] as num?)?.toInt();
        if (length != null && stringValue.length != length) {
          return 'Enter the $length-digit code.';
        }
        return null;
      case 'date.picker':
        final mode = (component['mode'] as String? ?? 'date').toLowerCase();
        final minRaw = component['min'] as String?;
        final maxRaw = component['max'] as String?;
        if (mode == 'time') {
          final time = _tryParseTimeOfDay(value?.toString());
          if (time == null) {
            return 'Enter a valid time.';
          }
          final minTime = _tryParseTimeOfDay(minRaw);
          if (minTime != null && _compareTimeOfDay(time, minTime) < 0) {
            return 'Time must be after ${_formatTimeOfDay(minTime)}.';
          }
          final maxTime = _tryParseTimeOfDay(maxRaw);
          if (maxTime != null && _compareTimeOfDay(time, maxTime) > 0) {
            return 'Time must be before ${_formatTimeOfDay(maxTime)}.';
          }
          return null;
        } else {
          final date = DateTime.tryParse(value?.toString() ?? '');
          if (date == null) {
            return 'Enter a valid date.';
          }
          final minDate = DateTime.tryParse(minRaw ?? '');
          if (minDate != null && date.isBefore(minDate)) {
            return 'Date must be on or after '
                '${DateFormat.yMMMd().format(minDate)}.';
          }
          final maxDate = DateTime.tryParse(maxRaw ?? '');
          if (maxDate != null && date.isAfter(maxDate)) {
            return 'Date must be on or before '
                '${DateFormat.yMMMd().format(maxDate)}.';
          }
          return null;
        }
      case 'slider':
        final number = (value as num?)?.toDouble();
        final min = (component['min'] as num?)?.toDouble();
        final max = (component['max'] as num?)?.toDouble();
        if (number == null) {
          return requiredMessage('Select a value.');
        }
        if (min != null && number < min) {
          return component['minErrorText'] as String? ??
              'Value must be at least $min.';
        }
        if (max != null && number > max) {
          return component['maxErrorText'] as String? ??
              'Value must be at most $max.';
        }
        return null;
      case 'stepper':
      case 'number.stepper':
        final number = (value as num?)?.toInt();
        final min = (component['min'] as num?)?.toInt();
        final max = (component['max'] as num?)?.toInt();
        if (number == null) {
          return requiredMessage('Select a value.');
        }
        if (min != null && number < min) {
          return component['minErrorText'] as String? ??
              'Value must be at least $min.';
        }
        if (max != null && number > max) {
          return component['maxErrorText'] as String? ??
              'Value must be at most $max.';
        }
        return null;
      case 'signature':
        final hasBytes = value is List && value.isNotEmpty;
        if (required && !hasBytes) {
          return requiredMessage('Signature required.');
        }
        return null;
      default:
        return null;
    }
  }

  bool _isValueEmpty(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  Set<String> _collectFieldNames(Object? node) {
    final result = <String>{};
    void walk(Object? value) {
      if (value is Map<String, Object?>) {
        final name = value['name'];
        if (name is String && name.isNotEmpty) {
          result.add(name);
        }
        for (final key in [
          'children',
          'items',
          'rows',
          'columns',
          'steps',
          'sections',
          'panels',
          'tabs',
          'content',
          'fields',
        ]) {
          final child = value[key];
          if (child != null) {
            walk(child);
          }
        }
      } else if (value is List) {
        for (final entry in value) {
          walk(entry);
        }
      }
    }

    walk(node);
    return result;
  }

  String? _formatDateDisplay(String? value, String mode) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (mode == 'time') {
      final time = _tryParseTimeOfDay(value);
      if (time == null) return value;
      return _formatTimeOfDay(time);
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      return value;
    }
    final local = date.toLocal();
    if (mode == 'datetime') {
      return DateFormat.yMMMd().add_jm().format(local);
    }
    return DateFormat.yMMMd().format(local);
  }

  TimeOfDay? _tryParseTimeOfDay(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final iso = DateTime.tryParse(value);
    if (iso != null) {
      return TimeOfDay(hour: iso.hour, minute: iso.minute);
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(value);
    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      return TimeOfDay(hour: hour % 24, minute: minute % 60);
    }
    return null;
  }

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final minutesA = a.hour * 60 + a.minute;
    final minutesB = b.hour * 60 + b.minute;
    return minutesA.compareTo(minutesB);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final dateTime = DateTime(
      1970,
      1,
      1,
      time.hour,
      time.minute,
    );
    return DateFormat.jm().format(dateTime);
  }

  Future<void> _submitForm(
    Map<String, Object?> action,
    BuildContext context, {
    required Iterable<String> fieldNames,
  }) async {
    final isValid = _validateFields(fieldNames, markTouched: true);
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fix the highlighted fields.'),
          ),
        );
      }
      return;
    }

    await _dispatchAction(
      action,
      context,
      payloadOverride: {
        'form': Map<String, Object?>.from(_formState),
      },
      preference: _ActionLoadingPreference.auto,
      actionSource: action,
    );
  }

  Future<void> _dispatchAction(
    Map<String, Object?> action,
    BuildContext context, {
    Map<String, Object?>? payloadOverride,
    bool includeFormState = false,
    _ActionLoadingPreference preference = _ActionLoadingPreference.auto,
    Map<String, Object?>? actionSource,
  }) async {
    final payload = <String, Object?>{
      ...castMap(action['payload']),
    };
    if (payloadOverride != null && payloadOverride.isNotEmpty) {
      payload.addAll(payloadOverride);
    }
    if (includeFormState) {
      payload['form'] = Map<String, Object?>.from(_formState);
    }

    final includePayload =
        payload.isNotEmpty || action.containsKey('payload') || includeFormState;

    final normalizedAction = {
      ...action,
      if (includePayload) 'payload': payload,
    };
    final resolvedBehavior = _resolveActionLoadingBehavior(
      action['loadingBehavior'],
      preference,
    );
    final handler = (action['handler'] as String?)?.toLowerCase().trim();
    final isClientHandler = handler == 'client';
    final shouldSelf = resolvedBehavior == _ActionLoadingPreference.self &&
        actionSource != null;
    final shouldContainer =
        resolvedBehavior == _ActionLoadingPreference.container;

    final source = actionSource;

    if ((shouldSelf || shouldContainer) && mounted) {
      setState(() {
        if (shouldSelf && source != null) {
          _pendingSelfActions.add(source);
        }
        if (shouldContainer) {
          _containerLoadingDepth += 1;
        }
      });
    } else {
      if (shouldSelf && source != null) {
        _pendingSelfActions.add(source);
      }
      if (shouldContainer) {
        _containerLoadingDepth += 1;
      }
    }

    try {
      final widgetsOptions = widget.controller.options.widgets;
      final onWidgetAction = widgetsOptions?.onAction;
      if (onWidgetAction != null) {
        final widgetAction = WidgetAction(
          type: normalizedAction['type'] as String? ?? '',
          payload: castMap(normalizedAction['payload']),
        );
        await Future<void>.value(
          onWidgetAction(
            widgetAction,
            WidgetItemContext(id: widget.item.id, widget: widget.widgetJson),
          ),
        );
      }
      if (!isClientHandler) {
        await widget.controller.sendCustomAction(
          normalizedAction,
          itemId: widget.item.id,
        );
      } else if (widgetsOptions?.onAction == null) {
        debugPrint(
          'ChatKit: received client-handled action '
          '"${normalizedAction['type'] ?? ''}" but no widgets.onAction handler is registered.',
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $error')),
        );
      }
    } finally {
      if (shouldSelf || shouldContainer) {
        if (mounted) {
          setState(() {
            if (shouldSelf && source != null) {
              _pendingSelfActions.remove(source);
            }
            if (shouldContainer) {
              _containerLoadingDepth = math.max(0, _containerLoadingDepth - 1);
            }
          });
        } else {
          if (shouldSelf && source != null) {
            _pendingSelfActions.remove(source);
          }
          if (shouldContainer) {
            _containerLoadingDepth = math.max(0, _containerLoadingDepth - 1);
          }
        }
      }
    }
  }

  Color? _colorFromToken(BuildContext context, Object? token) {
    if (token == null) {
      return null;
    }
    if (token is Map<String, Object?>) {
      final brightness = Theme.of(context).brightness;
      final preferredKey = brightness == Brightness.dark ? 'dark' : 'light';
      final candidate =
          token[preferredKey] ?? token['default'] ?? token.values.firstOrNull;
      return _colorFromToken(context, candidate);
    }
    if (token is String) {
      final normalized = token.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (normalized.startsWith('#')) {
        return _parseHexColor(normalized);
      }
      switch (normalized) {
        case 'primary':
          return Theme.of(context).colorScheme.primary;
        case 'onprimary':
          return Theme.of(context).colorScheme.onPrimary;
        case 'secondary':
          return Theme.of(context).colorScheme.secondary;
        case 'onsecondary':
          return Theme.of(context).colorScheme.onSecondary;
        case 'surface':
          return Theme.of(context).colorScheme.surface;
        case 'onsurface':
          return Theme.of(context).colorScheme.onSurface;
        case 'success':
          return Colors.green;
        case 'danger':
        case 'error':
          return Colors.redAccent;
        case 'warning':
        case 'caution':
          return Colors.amber;
        case 'info':
          return Colors.blueAccent;
        case 'discovery':
          return Colors.purpleAccent;
      }

      final shadeMatch =
          RegExp(r'([a-z]+)[-_](\d{2,3})').firstMatch(normalized);
      if (shadeMatch != null) {
        final base = shadeMatch.group(1)!;
        final shadeValue = int.tryParse(shadeMatch.group(2)!);
        if (shadeValue != null) {
          final swatch = _materialColorFor(base);
          if (swatch != null) {
            return swatch[shadeValue] ?? swatch;
          }
        }
      }

      final swatch = _materialColorFor(normalized);
      if (swatch != null) {
        return swatch;
      }

      return _parseHexColor(normalized);
    }
    return null;
  }

  @visibleForTesting
  PageController? debugCarouselController(String carouselId) {
    return _pageControllers['carousel::$carouselId'];
  }

  @visibleForTesting
  void debugRequestFocusForCarousel(String carouselId) {
    _carouselFocusNodes['carousel::$carouselId']?.requestFocus();
  }

  Color? _parseHexColor(String value) {
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'ff$hex';
    }
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) {
      return null;
    }
    return Color(intValue);
  }

  MaterialColor? _materialColorFor(String name) {
    switch (name) {
      case 'red':
        return Colors.red;
      case 'pink':
        return Colors.pink;
      case 'purple':
        return Colors.purple;
      case 'deep-purple':
      case 'deeppurple':
        return Colors.deepPurple;
      case 'indigo':
        return Colors.indigo;
      case 'blue':
        return Colors.blue;
      case 'light-blue':
      case 'lightblue':
        return Colors.lightBlue;
      case 'cyan':
        return Colors.cyan;
      case 'teal':
        return Colors.teal;
      case 'green':
        return Colors.green;
      case 'light-green':
      case 'lightgreen':
        return Colors.lightGreen;
      case 'lime':
        return Colors.lime;
      case 'yellow':
        return Colors.yellow;
      case 'amber':
        return Colors.amber;
      case 'orange':
        return Colors.orange;
      case 'deep-orange':
      case 'deeporange':
        return Colors.deepOrange;
      case 'brown':
        return Colors.brown;
      case 'blue-grey':
      case 'bluegray':
      case 'bluegrey':
        return Colors.blueGrey;
      case 'grey':
      case 'gray':
        return Colors.grey;
    }
    return null;
  }

  IconData? _iconFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    switch (name) {
      case 'analytics':
        return Icons.analytics;
      case 'atom':
        return Icons.ac_unit;
      case 'bolt':
        return Icons.bolt;
      case 'book-open':
        return Icons.menu_book;
      case 'book-clock':
        return Icons.book_online;
      case 'book-closed':
        return Icons.book;
      case 'calendar':
        return Icons.calendar_today;
      case 'chart':
        return Icons.bar_chart;
      case 'check':
        return Icons.check;
      case 'check-circle':
        return Icons.check_circle_outline;
      case 'check-circle-filled':
        return Icons.check_circle;
      case 'chevron-left':
        return Icons.chevron_left;
      case 'chevron-right':
        return Icons.chevron_right;
      case 'circle-question':
        return Icons.help_outline;
      case 'compass':
        return Icons.explore;
      case 'confetti':
        return Icons.celebration;
      case 'cube':
        return Icons.all_inbox;
      case 'desktop':
        return Icons.desktop_windows;
      case 'document':
        return Icons.description;
      case 'dot':
        return Icons.circle;
      case 'dots-horizontal':
        return Icons.more_horiz;
      case 'dots-vertical':
        return Icons.more_vert;
      case 'empty-circle':
        return Icons.circle_outlined;
      case 'external-link':
        return Icons.open_in_new;
      case 'globe':
        return Icons.public;
      case 'keys':
        return Icons.vpn_key;
      case 'lab':
        return Icons.science;
      case 'images':
        return Icons.photo_library;
      case 'info':
        return Icons.info_outline;
      case 'lifesaver':
        return Icons.support;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'mail':
        return Icons.mail_outline;
      case 'map-pin':
        return Icons.location_pin;
      case 'maps':
        return Icons.map;
      case 'mobile':
        return Icons.smartphone;
      case 'notebook':
        return Icons.note;
      case 'notebook-pencil':
        return Icons.edit_note;
      case 'page-blank':
        return Icons.article_outlined;
      case 'phone':
        return Icons.phone;
      case 'play':
        return Icons.play_arrow;
      case 'plus':
        return Icons.add;
      case 'profile':
        return Icons.person_outline;
      case 'profile-card':
        return Icons.badge_outlined;
      case 'reload':
        return Icons.refresh;
      case 'star':
        return Icons.star_border;
      case 'star-filled':
        return Icons.star;
      case 'search':
        return Icons.search;
      case 'sparkle':
        return Icons.auto_awesome;
      case 'sparkle-double':
        return Icons.auto_awesome_mosaic;
      case 'square-code':
        return Icons.code;
      case 'square-image':
        return Icons.image;
      case 'square-text':
        return Icons.note_outlined;
      case 'suitcase':
        return Icons.work_outline;
      case 'settings-slider':
        return Icons.tune;
      case 'user':
        return Icons.person;
    }
    return null;
  }

  PageController _pageControllerFor(
    String key, {
    double viewportFraction = 1.0,
  }) {
    final existing = _pageControllers[key];
    if (existing != null &&
        (existing.viewportFraction - viewportFraction).abs() > 0.001) {
      existing.dispose();
      final controller = PageController(viewportFraction: viewportFraction);
      _pageControllers[key] = controller;
      return controller;
    }
    return _pageControllers.putIfAbsent(
      key,
      () => PageController(viewportFraction: viewportFraction),
    );
  }

  SignatureController _signatureControllerFor(String name) {
    return _signatureControllers.putIfAbsent(
      name,
      () => SignatureController(
        penStrokeWidth: 2,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
      ),
    );
  }

  Map<String, Object?> castMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value
          .map((key, value) => MapEntry(key.toString(), value as Object?));
    }
    return {};
  }
}

enum _TimelineAlignment { start, end, alternate }

enum _TimelineLineStyle { solid, dashed }

class _SingleSelectResult {
  const _SingleSelectResult({this.value, this.cleared = false});

  final Object? value;
  final bool cleared;
}

class _MultiSelectResult {
  const _MultiSelectResult({required this.values, this.cleared = false});

  final Set<Object?> values;
  final bool cleared;
}

class _SelectOptionGroup {
  const _SelectOptionGroup({this.label, required this.options});

  final String? label;
  final List<_SelectOption> options;
}

class _SelectOption {
  const _SelectOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.disabled = false,
  });

  factory _SelectOption.fromMap(Map<String, Object?> map) {
    final value = map.containsKey('value') ? map['value'] : map['id'];
    final label = map['label'] as String? ?? value?.toString() ?? '';
    return _SelectOption(
      value: value,
      label: label,
      description: map['description'] as String? ?? map['subtitle'] as String?,
      icon: map['icon'] as String?,
      disabled: map['disabled'] as bool? ?? false,
    );
  }

  final Object? value;
  final String label;
  final String? description;
  final String? icon;
  final bool disabled;
}

class _TableSortState {
  _TableSortState({this.columnIndex, this.ascending = true});

  int? columnIndex;
  bool ascending;
}

class _TableColumnConfig {
  _TableColumnConfig({
    required this.index,
    required this.label,
    this.dataKey,
    this.sortable = false,
    this.numeric = false,
    this.textAlign,
    this.tooltip,
  });

  factory _TableColumnConfig.fromJson(
    int index,
    Map<String, Object?> json,
  ) {
    final label = json['label'] as String? ??
        json['title'] as String? ??
        'Column ${index + 1}';
    final dataKey = json['dataKey'] as String? ?? json['key'] as String?;
    final sortable = json['sortable'] as bool? ?? false;
    final alignToken =
        (json['align'] as String? ?? json['textAlign'] as String?)
            ?.toLowerCase()
            .trim();
    final numeric = (json['numeric'] as bool?) ??
        (alignToken == 'end' || alignToken == 'right');
    final textAlign = switch (alignToken) {
      'center' => TextAlign.center,
      'end' || 'right' => TextAlign.right,
      'start' || 'left' => TextAlign.left,
      _ => null,
    };
    final tooltip = json['tooltip'] as String?;
    return _TableColumnConfig(
      index: index,
      label: label,
      dataKey: dataKey,
      sortable: sortable,
      numeric: numeric,
      textAlign: textAlign,
      tooltip: tooltip,
    );
  }

  final int index;
  final String label;
  final String? dataKey;
  final bool sortable;
  final bool numeric;
  final TextAlign? textAlign;
  final String? tooltip;

  Widget buildHeader(BuildContext context) {
    final textAlignValue =
        textAlign ?? (numeric ? TextAlign.right : TextAlign.left);
    final alignment = textAlignValue == TextAlign.right
        ? Alignment.centerRight
        : (textAlignValue == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft);
    return Align(
      alignment: alignment,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TableRowModel {
  const _TableRowModel({required this.cells});

  final List<_TableCellData> cells;
}

class _TableCellData {
  const _TableCellData({
    required this.child,
    this.sortValue,
  });

  final Widget child;
  final Object? sortValue;
}

class _CarouselSlide {
  const _CarouselSlide({
    required this.child,
    this.identifier,
    this.title,
    this.subtitle,
    this.description,
    this.badge,
    this.tags = const [],
  });

  final Widget child;
  final String? identifier;
  final String? title;
  final String? subtitle;
  final String? description;
  final String? badge;
  final List<String> tags;

  bool get hasMeta =>
      (title != null && title!.isNotEmpty) ||
      (subtitle != null && subtitle!.isNotEmpty) ||
      (description != null && description!.isNotEmpty) ||
      (badge != null && badge!.isNotEmpty) ||
      tags.isNotEmpty;
}

class _TimelineConnectorPainter extends CustomPainter {
  const _TimelineConnectorPainter({
    required this.color,
    required this.style,
  });

  final Color color;
  final _TimelineLineStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final x = size.width / 2;
    if (style == _TimelineLineStyle.dashed) {
      const dashLength = 6.0;
      const gap = 4.0;
      double y = 0;
      while (y < size.height) {
        final endY = math.min(y + dashLength, size.height);
        canvas.drawLine(Offset(x, y), Offset(x, endY), paint);
        y += dashLength + gap;
      }
    } else {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_TimelineConnectorPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.style != style;
  }
}

enum _ActionLoadingPreference { auto, none, self, container }

class _DecoratedBoxResult {
  const _DecoratedBoxResult({
    required this.child,
    this.flex,
    this.margin,
    this.borderRadius,
  });

  final Widget child;
  final int? flex;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
}

class _FlexMaybe extends StatelessWidget {
  const _FlexMaybe({
    required this.flex,
    required this.child,
  });

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasFlexAncestor =
        context.findAncestorWidgetOfExactType<Flex>() != null;
    if (!hasFlexAncestor) {
      return child;
    }
    return Flexible(
      flex: flex,
      fit: FlexFit.tight,
      child: child,
    );
  }
}

class _SeriesConfig {
  const _SeriesConfig({
    required this.type,
    required this.key,
    required this.label,
    required this.color,
    required this.values,
  });

  final String type;
  final String key;
  final String label;
  final Color color;
  final List<double?> values;
}
