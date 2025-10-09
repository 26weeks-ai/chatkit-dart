import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'actions/client_tools.dart';
import 'models/entities.dart';

/// Base interface implemented by API configuration variants.
abstract class ChatKitApiConfig {
  const ChatKitApiConfig();
}

/// Hosted mode configuration that relies on ChatKit-hosted authentication.
@immutable
class HostedApiConfig extends ChatKitApiConfig {
  const HostedApiConfig({
    required this.getClientSecret,
  });

  /// Callback that provides (or refreshes) the client secret used to
  /// authenticate requests against the hosted ChatKit deployment.
  final FutureOr<String> Function(String? currentClientSecret) getClientSecret;
}

/// Custom backend configuration which mirrors the JS `CustomApiConfig`.
@immutable
class CustomApiConfig extends ChatKitApiConfig {
  const CustomApiConfig({
    required this.url,
    this.domainKey,
    this.uploadStrategy,
    this.headersBuilder,
    this.fetchOverride,
  });

  /// Fully-qualified or relative URL for the ChatKit-compatible endpoint.
  final String url;

  /// Optional domain verification key that is sent alongside chat requests.
  final String? domainKey;

  /// Strategy to use for uploading attachments.
  final FileUploadStrategy? uploadStrategy;

  /// Optional hook that allows per-request header customization (e.g. auth).
  final FutureOr<Map<String, String>> Function(http.BaseRequest request)?
      headersBuilder;

  final FutureOr<http.StreamedResponse> Function(http.BaseRequest request)?
      fetchOverride;
}

/// Attachment upload strategies available in JS and mirrored here.
@immutable
sealed class FileUploadStrategy {
  const FileUploadStrategy();
}

/// Upload files via a single POST directly to the specified URL.
class DirectUploadStrategy extends FileUploadStrategy {
  const DirectUploadStrategy({required this.uploadUrl});

  final String uploadUrl;
}

/// Use two-phase uploads where the backend returns a signed URL.
class TwoPhaseUploadStrategy extends FileUploadStrategy {
  const TwoPhaseUploadStrategy();
}

/// The high-level options object accepted by [ChatKitController].
@immutable
class ChatKitOptions {
  const ChatKitOptions({
    required this.api,
    this.transport,
    this.hostedHooks,
    this.locale,
    Object? theme,
    this.initialThread,
    this.onClientTool,
    this.header,
    this.history,
    this.startScreen,
    this.threadItemActions,
    this.composer,
    this.disclaimer,
    this.entities,
    this.widgets,
    this.localizationOverrides,
    this.localization,
  }) : theme = theme;

  final ChatKitApiConfig api;
  final TransportOption? transport;
  final HostedHooksOption? hostedHooks;
  final String? locale;
  final Object? theme;
  final String? initialThread;
  final ChatKitClientToolHandler? onClientTool;
  final HeaderOption? header;
  final HistoryOption? history;
  final StartScreenOption? startScreen;
  final ThreadItemActionsOption? threadItemActions;
  final ComposerOption? composer;
  final DisclaimerOption? disclaimer;
  final EntitiesOption? entities;
  final WidgetsOption? widgets;
  final Map<String, String>? localizationOverrides;
  final LocalizationOption? localization;

  ChatKitOptions copyWith({
    ChatKitApiConfig? api,
    TransportOption? transport,
    String? locale,
    Object? theme,
    String? initialThread,
    ChatKitClientToolHandler? onClientTool,
    HeaderOption? header,
    HistoryOption? history,
    StartScreenOption? startScreen,
    ThreadItemActionsOption? threadItemActions,
    ComposerOption? composer,
    DisclaimerOption? disclaimer,
    EntitiesOption? entities,
    WidgetsOption? widgets,
    Map<String, String>? localizationOverrides,
    LocalizationOption? localization,
  }) {
    return ChatKitOptions(
      api: api ?? this.api,
      transport: transport ?? this.transport,
      hostedHooks: hostedHooks ?? this.hostedHooks,
      locale: locale ?? this.locale,
      theme: theme ?? this.theme,
      initialThread: initialThread ?? this.initialThread,
      onClientTool: onClientTool ?? this.onClientTool,
      header: header ?? this.header,
      history: history ?? this.history,
      startScreen: startScreen ?? this.startScreen,
      threadItemActions: threadItemActions ?? this.threadItemActions,
      composer: composer ?? this.composer,
      disclaimer: disclaimer ?? this.disclaimer,
      entities: entities ?? this.entities,
      widgets: widgets ?? this.widgets,
      localizationOverrides:
          localizationOverrides ?? this.localizationOverrides,
      localization: localization ?? this.localization,
    );
  }

  /// Returns the simple color scheme preset when [theme] was provided as
  /// `'light'`, `'dark'`, or `'system'`.
  ColorSchemeOption? get themeColorScheme {
    final value = theme;
    if (value is ColorSchemeOption) {
      return value;
    }
    if (value is ThemeOption) {
      return value.colorScheme;
    }
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'light':
          return ColorSchemeOption.light;
        case 'dark':
          return ColorSchemeOption.dark;
        case 'system':
          return ColorSchemeOption.system;
      }
    }
    return null;
  }

  /// Returns a [ThemeOption] regardless of whether the caller provided a
  /// string preset, an enum, or a fully-specified theme object.
  ThemeOption? get resolvedTheme {
    final value = theme;
    if (value is ThemeOption) {
      return value;
    }
    final scheme = themeColorScheme;
    if (scheme != null) {
      return ThemeOption(colorScheme: scheme);
    }
    return null;
  }
}

@immutable
class TransportOption {
  const TransportOption({
    this.keepAliveTimeout,
    this.initialBackoff,
    this.maxBackoff,
  });

  final Duration? keepAliveTimeout;
  final Duration? initialBackoff;
  final Duration? maxBackoff;
}

@immutable
class HostedHooksOption {
  const HostedHooksOption({
    this.onAuthExpired,
    this.onAuthRestored,
    this.onStaleClient,
  });

  final VoidCallback? onAuthExpired;
  final VoidCallback? onAuthRestored;
  final FutureOr<void> Function()? onStaleClient;
}

/// Theme options intentionally mirror the TS definitions but favour optional
/// fields to remain forward compatible with new surfaces.
@immutable
class ThemeOption {
  const ThemeOption({
    this.colorScheme,
    this.color,
    this.typography,
    this.shapes,
    this.breakpoints,
    this.backgroundGradient,
    this.elevations,
    this.components,
  });

  final ColorSchemeOption? colorScheme;
  final ThemeColorOptions? color;
  final ThemeTypographyOptions? typography;
  final ThemeShapeOptions? shapes;
  final ThemeBreakpointOptions? breakpoints;
  final ThemeGradientOptions? backgroundGradient;
  final ThemeElevationOptions? elevations;
  final ThemeComponentOptions? components;
}

enum ColorSchemeOption {
  light,
  dark,
  system,
}

@immutable
class ThemeColorOptions {
  const ThemeColorOptions({
    this.grayscale,
    this.accent,
    this.surface,
    this.gradients,
  });

  final GrayscaleOptions? grayscale;
  final AccentColorOptions? accent;
  final SurfaceColorOptions? surface;
  final ThemeGradientOptions? gradients;
}

@immutable
class GrayscaleOptions {
  const GrayscaleOptions({
    this.label0,
    this.label1,
    this.label2,
    this.label3,
    this.border,
    this.background,
    this.tint,
    this.shadow,
  });

  final String? label0;
  final String? label1;
  final String? label2;
  final String? label3;
  final String? border;
  final String? background;
  final String? tint;
  final String? shadow;
}

@immutable
class AccentColorOptions {
  const AccentColorOptions({
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final String? primary;
  final String? onPrimary;
  final String? secondary;
  final String? onSecondary;
}

@immutable
class SurfaceColorOptions {
  const SurfaceColorOptions({
    this.primary,
    this.secondary,
    this.tertiary,
    this.quaternary,
  });

  final String? primary;
  final String? secondary;
  final String? tertiary;
  final String? quaternary;
}

@immutable
class ThemeGradientOptions {
  const ThemeGradientOptions({
    required this.colors,
    this.angle,
  });

  /// List of hex colors applied sequentially in the gradient.
  final List<String> colors;

  /// Optional angle in degrees (0 = left to right, 90 = bottom to top).
  final double? angle;
}

@immutable
class ThemeElevationOptions {
  const ThemeElevationOptions({
    this.surface,
    this.composer,
    this.history,
    this.assistantBubble,
    this.userBubble,
  });

  final double? surface;
  final double? composer;
  final double? history;
  final double? assistantBubble;
  final double? userBubble;
}

@immutable
class ThemeComponentOptions {
  const ThemeComponentOptions({
    this.composer,
    this.history,
    this.assistantBubble,
    this.userBubble,
  });

  final ThemeComponentStyle? composer;
  final ThemeComponentStyle? history;
  final ThemeComponentStyle? assistantBubble;
  final ThemeComponentStyle? userBubble;
}

@immutable
class ThemeComponentStyle {
  const ThemeComponentStyle({
    this.background,
    this.text,
    this.border,
    this.elevation,
    this.radius,
  });

  final String? background;
  final String? text;
  final String? border;
  final double? elevation;
  final double? radius;
}

@immutable
class ThemeTypographyOptions {
  const ThemeTypographyOptions({
    this.fontFamily,
    this.monospaceFontFamily,
  });

  final String? fontFamily;
  final String? monospaceFontFamily;
}

@immutable
class ThemeShapeOptions {
  const ThemeShapeOptions({
    this.radius,
    this.rounding,
  });

  final double? radius;
  final double? rounding;
}

@immutable
class ThemeBreakpointOptions {
  const ThemeBreakpointOptions({
    this.compact,
    this.medium,
    this.expanded,
  });

  final double? compact;
  final double? medium;
  final double? expanded;
}

@immutable
class HeaderOption {
  const HeaderOption({
    this.enabled,
    this.title,
    this.leftAction,
    this.rightAction,
  });

  final bool? enabled;
  final HeaderTitleOption? title;
  final HeaderActionOption? leftAction;
  final HeaderActionOption? rightAction;
}

@immutable
class HeaderTitleOption {
  const HeaderTitleOption({
    this.enabled,
    this.text,
  });

  final bool? enabled;
  final String? text;
}

@immutable
class HeaderActionOption {
  const HeaderActionOption({
    required this.icon,
    required this.onClick,
  });

  final String icon;
  final VoidCallback onClick;
}

typedef VoidCallback = void Function();

class HeaderIcons {
  const HeaderIcons._();

  static const sidebarLeft = 'sidebar-left';
  static const sidebarRight = 'sidebar-right';
  static const sidebarOpenLeft = 'sidebar-open-left';
  static const sidebarOpenRight = 'sidebar-open-right';
  static const sidebarOpenLeftAlt = 'sidebar-open-left-alt';
  static const sidebarOpenRightAlt = 'sidebar-open-right-alt';
  static const sidebarFloatingLeft = 'sidebar-floating-left';
  static const sidebarFloatingRight = 'sidebar-floating-right';
  static const sidebarFloatingOpenLeft = 'sidebar-floating-open-left';
  static const sidebarFloatingOpenRight = 'sidebar-floating-open-right';
  static const sidebarCollapseLeft = 'sidebar-collapse-left';
  static const sidebarCollapseRight = 'sidebar-collapse-right';
  static const collapseLeft = 'collapse-left';
  static const collapseRight = 'collapse-right';
  static const openLeft = 'open-left';
  static const openRight = 'open-right';
  static const doubleChevronLeft = 'double-chevron-left';
  static const doubleChevronRight = 'double-chevron-right';
  static const home = 'home';
  static const homeAlt = 'home-alt';
  static const backSmall = 'back-small';
  static const backLarge = 'back-large';
  static const expandLarge = 'expand-large';
  static const collapseLarge = 'collapse-large';
  static const expandSmall = 'expand-small';
  static const collapseSmall = 'collapse-small';
  static const star = 'star';
  static const starFilled = 'star-filled';
  static const chatTemporary = 'chat-temporary';
  static const settingsCog = 'settings-cog';
  static const grid = 'grid';
  static const dotsHorizontal = 'dots-horizontal';
  static const dotsVertical = 'dots-vertical';
  static const dotsHorizontalCircle = 'dots-horizontal-circle';
  static const dotsVerticalCircle = 'dots-vertical-circle';
  static const menu = 'menu';
  static const menuInverted = 'menu-inverted';
  static const hamburger = 'hamburger';
  static const compose = 'compose';
  static const lightMode = 'light-mode';
  static const darkMode = 'dark-mode';
  static const close = 'close';

  @Deprecated('Use HeaderIcons.compose')
  static const add = compose;
  @Deprecated('Use HeaderIcons.menu')
  static const arrowDown = menu;
  @Deprecated('Use HeaderIcons.backLarge')
  static const arrowLeft = backLarge;
  @Deprecated('Use HeaderIcons.openRight')
  static const arrowRight = openRight;
  @Deprecated('Use HeaderIcons.menu')
  static const arrowUp = menu;
  @Deprecated('Use HeaderIcons.dotsHorizontal')
  static const more = dotsHorizontal;
  @Deprecated('Use HeaderIcons.settingsCog')
  static const settings = settingsCog;
  @Deprecated('Use HeaderIcons.hamburger')
  static const menuLegacy = hamburger;
}

@immutable
class HistoryOption {
  const HistoryOption({
    this.enabled,
    this.showDelete,
    this.showRename,
  });

  final bool? enabled;
  final bool? showDelete;
  final bool? showRename;
}

@immutable
class StartScreenOption {
  const StartScreenOption({
    this.greeting,
    this.prompts,
  });

  final String? greeting;
  final List<StartScreenPrompt>? prompts;
}

@immutable
class StartScreenPrompt {
  const StartScreenPrompt({
    required this.label,
    required this.prompt,
    this.icon,
  });

  final String label;
  final String prompt;
  final String? icon;
}

@immutable
class ThreadItemActionsOption {
  const ThreadItemActionsOption({
    this.feedback,
    this.retry,
    this.share,
    this.shareActions,
  });

  final bool? feedback;
  final bool? retry;
  final bool? share;
  final ShareActionsOption? shareActions;
}

enum ShareTargetType {
  copy,
  system,
  custom,
}

@immutable
class ShareTargetOption {
  const ShareTargetOption({
    required this.id,
    required this.label,
    this.type = ShareTargetType.custom,
    this.description,
    this.icon,
    this.toast,
  });

  final String id;
  final String label;
  final ShareTargetType type;
  final String? description;
  final String? icon;
  final String? toast;
}

@immutable
class ShareActionsOption {
  const ShareActionsOption({
    this.targets,
    this.onSelectTarget,
    this.copyToast,
    this.systemToast,
    this.defaultToast,
  });

  final List<ShareTargetOption>? targets;
  final FutureOr<void> Function(ShareTargetInvocation invocation)?
      onSelectTarget;
  final String? copyToast;
  final String? systemToast;
  final String? defaultToast;
}

@immutable
class ShareTargetInvocation {
  const ShareTargetInvocation({
    required this.targetId,
    required this.itemId,
    required this.threadId,
    required this.text,
  });

  final String targetId;
  final String itemId;
  final String threadId;
  final String text;
}

@immutable
class ComposerOption {
  const ComposerOption({
    this.placeholder,
    this.attachments,
    this.tools,
    this.models,
  });

  final String? placeholder;
  final ComposerAttachmentOption? attachments;
  final List<ToolOption>? tools;
  final List<ModelOption>? models;
}

@immutable
class ComposerAttachmentOption {
  const ComposerAttachmentOption({
    required this.enabled,
    this.maxSize,
    this.maxCount,
    this.accept,
  });

  final bool enabled;
  final int? maxSize;
  final int? maxCount;
  final Map<String, List<String>>? accept;
}

@immutable
class ToolOption {
  const ToolOption({
    String? id,
    @Deprecated('Use id') String? name,
    required this.label,
    this.description,
    this.shortLabel,
    this.placeholderOverride,
    this.icon,
    this.pinned = false,
  })  : assert(id != null || name != null, 'ToolOption.id is required'),
        id = (id ?? name)!;

  final String id;
  final String label;
  final String? description;
  final String? shortLabel;
  final String? placeholderOverride;
  final String? icon;
  final bool pinned;

  @Deprecated('Use id')
  String get name => id;
}

@immutable
class ModelOption {
  const ModelOption({
    required this.id,
    required this.label,
    this.description,
    bool? disabled,
    bool? defaultSelected,
    bool? isDefault,
    bool? defaultOption,
  })  : disabled = disabled ?? false,
        defaultSelected =
            defaultSelected ?? isDefault ?? defaultOption ?? false;

  final String id;
  final String label;
  final String? description;
  final bool disabled;
  final bool defaultSelected;

  @Deprecated('Use defaultSelected')
  bool get isDefault => defaultSelected;
}

@immutable
class DisclaimerOption {
  const DisclaimerOption({
    required this.text,
    this.highContrast,
  });

  final String text;
  final bool? highContrast;
}

@immutable
class EntitiesOption {
  const EntitiesOption({
    this.onTagSearch,
    this.onClick,
    this.onRequestPreview,
  });

  final FutureOr<List<Entity>> Function(String query)? onTagSearch;
  final void Function(Entity entity)? onClick;
  final FutureOr<EntityPreview?> Function(Entity entity)? onRequestPreview;
}

@immutable
class WidgetsOption {
  const WidgetsOption({
    this.onAction,
  });

  final FutureOr<void> Function(
    WidgetAction action,
    WidgetItemContext item,
  )? onAction;
}

@immutable
class LocalizationOption {
  const LocalizationOption({
    this.bundles = const {},
    this.defaultLocale,
    this.loader,
    this.pluralResolver,
  });

  /// Static bundles to register alongside built-in translations.
  final Map<String, Map<String, String>> bundles;

  /// Optional default locale to fall back to when the requested locale is not available.
  final String? defaultLocale;

  /// Optional asynchronous loader invoked when a locale bundle is requested but not cached.
  final FutureOr<Map<String, String>> Function(String locale)? loader;

  /// Optional pluralization resolver to format strings with counts.
  final String Function(
    String key,
    num count, {
    Map<String, Object?> params,
  })? pluralResolver;
}

@immutable
class WidgetAction {
  const WidgetAction({
    required this.type,
    this.payload = const {},
  });

  final String type;
  final Map<String, Object?> payload;
}

@immutable
class WidgetItemContext {
  const WidgetItemContext({
    required this.id,
    required this.widget,
  });

  final String id;
  final Map<String, Object?> widget;
}
