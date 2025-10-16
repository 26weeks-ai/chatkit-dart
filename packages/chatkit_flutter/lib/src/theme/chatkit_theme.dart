import 'dart:math' as math;

import 'package:chatkit_core/chatkit_core.dart';
import 'package:flutter/material.dart';

/// Core theme data for ChatKit Flutter surfaces.
///
/// This class centralises the palette, spacing, radii, typography and
/// component-level styling required to achieve visual parity with ChatKit-JS
/// while still honouring [`ThemeOption`] overrides provided by host apps.
@immutable
class ChatKitThemeData {
  const ChatKitThemeData({
    required this.materialTheme,
    required this.palette,
    required this.spacing,
    required this.radii,
    required this.typography,
    required this.components,
    required this.shadows,
  });

  final ThemeData materialTheme;
  final ChatKitPalette palette;
  final ChatKitSpacing spacing;
  final ChatKitRadii radii;
  final ChatKitTypography typography;
  final ChatKitComponentStyles components;
  final ChatKitShadows shadows;

  ChatKitThemeData copyWith({
    ThemeData? materialTheme,
    ChatKitPalette? palette,
    ChatKitSpacing? spacing,
    ChatKitRadii? radii,
    ChatKitTypography? typography,
    ChatKitComponentStyles? components,
    ChatKitShadows? shadows,
  }) {
    return ChatKitThemeData(
      materialTheme: materialTheme ?? this.materialTheme,
      palette: palette ?? this.palette,
      spacing: spacing ?? this.spacing,
      radii: radii ?? this.radii,
      typography: typography ?? this.typography,
      components: components ?? this.components,
      shadows: shadows ?? this.shadows,
    );
  }

  /// Builds a theme from the resolved [ThemeOption] provided by ChatKit core.
  ///
  /// [base] is the host theme and [platformBrightness] reflects the current
  /// system brightness, supporting `ColorSchemeOption.system`.
  factory ChatKitThemeData.fromOptions({
    required ThemeData base,
    ThemeOption? option,
    Brightness? platformBrightness,
  }) {
    final spacing = ChatKitSpacing.defaults(density: option?.density);
    final radii = ChatKitRadii.fromBase(
      option?.shapes?.radius ?? _baseRadiusForPreset(option?.radius),
    );

    final material = _resolveMaterialTheme(
      base: base,
      option: option,
      radii: radii,
      spacing: spacing,
      platformBrightness: platformBrightness,
    );

    final palette = ChatKitPalette.fromMaterial(
      material,
      option?.color?.grayscale,
    );
    final typography = ChatKitTypography.fromTheme(material.textTheme);

    final elevations = option?.elevations;
    final components = ChatKitComponentStyles(
      surface: ChatKitSurfaceStyle(
        background: material.colorScheme.surface,
        foreground: material.colorScheme.onSurface,
        border: material.colorScheme.outlineVariant,
        elevation: elevations?.surface ?? 0,
        radius: radii.card,
      ),
      composer: _surfaceFromOptions(
        base: ChatKitSurfaceStyle(
          background: material.colorScheme.surface,
          foreground: material.colorScheme.onSurface,
          border: material.colorScheme.outlineVariant,
          elevation: elevations?.composer ?? 6,
          radius: radii.composer,
        ),
        overrides: option?.components?.composer,
      ),
      history: _surfaceFromOptions(
        base: ChatKitSurfaceStyle(
          background: palette.surfaceContainerHigh,
          foreground: material.colorScheme.onSurface,
          border: material.colorScheme.outlineVariant,
          elevation: elevations?.history ?? 4,
          radius: radii.card,
        ),
        overrides: option?.components?.history,
      ),
      assistantBubble: _surfaceFromOptions(
        base: ChatKitSurfaceStyle(
          background: palette.surfaceContainer,
          foreground: material.colorScheme.onSurface,
          border: palette.borderMuted,
          elevation: elevations?.assistantBubble ?? 0,
          radius: radii.messageBubble,
        ),
        overrides: option?.components?.assistantBubble,
      ),
      userBubble: _surfaceFromOptions(
        base: ChatKitSurfaceStyle(
          background: palette.primaryStrong,
          foreground: palette.onPrimaryStrong,
          border: palette.primaryStrongBorder,
          elevation: elevations?.userBubble ?? 0,
          radius: radii.messageBubble,
        ),
        overrides: option?.components?.userBubble,
      ),
    );

    final shadows = ChatKitShadows.defaults(palette);

    return ChatKitThemeData(
      materialTheme: material,
      palette: palette,
      spacing: spacing,
      radii: radii,
      typography: typography,
      components: components,
      shadows: shadows,
    );
  }

  static ThemeData _resolveMaterialTheme({
    required ThemeData base,
    required ChatKitRadii radii,
    required ChatKitSpacing spacing,
    ThemeOption? option,
    Brightness? platformBrightness,
  }) {
    ThemeData material;
    switch (option?.colorScheme) {
      case ColorSchemeOption.dark:
        material = ThemeData(
          brightness: Brightness.dark,
          useMaterial3: false,
        );
        break;
      case ColorSchemeOption.light:
        material = ThemeData(
          brightness: Brightness.light,
          useMaterial3: false,
        );
        break;
      case ColorSchemeOption.system:
        final brightness = platformBrightness ?? base.brightness;
        material = ThemeData(
          brightness: brightness,
          useMaterial3: false,
        );
        break;
      case null:
        material = base.copyWith(useMaterial3: false);
        break;
    }

    material = material.copyWith(
      visualDensity: _visualDensityForOption(option?.density),
    );

    var scheme = material.colorScheme;

    final accent = option?.color?.accent;
    if (accent != null) {
      final primaryAccent = _parseColor(accent.primary);
      final adjustedPrimary =
          _applyAccentLevel(primaryAccent, accent.level) ?? primaryAccent;
      scheme = scheme.copyWith(
        primary: adjustedPrimary ?? scheme.primary,
        onPrimary: _parseColor(accent.onPrimary) ?? scheme.onPrimary,
        secondary: _parseColor(accent.secondary) ?? scheme.secondary,
        onSecondary: _parseColor(accent.onSecondary) ?? scheme.onSecondary,
      );
    }

    final surface = option?.color?.surface;
    Color? scaffoldBackground;
    Color? canvasColor;
    if (surface != null) {
      final primarySurface = _parseColor(surface.primary);
      final secondarySurface = _parseColor(surface.secondary);
      final tertiarySurface = _parseColor(surface.tertiary);
      final quaternarySurface = _parseColor(surface.quaternary);
      final backgroundSurface = _parseColor(surface.background);
      final foregroundSurface = _parseColor(surface.foreground);
      scheme = scheme.copyWith(
        surface: primarySurface ?? backgroundSurface ?? scheme.surface,
        surfaceTint: secondarySurface ?? scheme.surfaceTint,
        onSurface: foregroundSurface ?? scheme.onSurface,
      );
      scaffoldBackground =
          tertiarySurface ?? primarySurface ?? backgroundSurface;
      canvasColor = quaternarySurface;
    }

    material = material.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          scaffoldBackground ?? material.scaffoldBackgroundColor,
      canvasColor: canvasColor ?? material.canvasColor,
    );

    // Typography overrides.
    final typography = option?.typography;
    if (typography != null) {
      TextTheme textTheme = material.textTheme;
      TextTheme primaryTextTheme = material.primaryTextTheme;

      if (typography.fontFamily != null) {
        textTheme = textTheme.apply(fontFamily: typography.fontFamily);
        primaryTextTheme =
            primaryTextTheme.apply(fontFamily: typography.fontFamily);
      }

      final baseSize = typography.baseSize;
      if (baseSize != null && baseSize > 0) {
        final factor = baseSize / 16.0;
        textTheme = textTheme.apply(fontSizeFactor: factor);
        primaryTextTheme = primaryTextTheme.apply(fontSizeFactor: factor);
      }

      material = material.copyWith(
        textTheme: textTheme,
        primaryTextTheme: primaryTextTheme,
      );
    }

    // Shape overrides.
    final baseRadius = radii.card;
    final roundedRectangle = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(baseRadius),
    );
    final bottomSheetRadius = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(baseRadius),
      ),
    );

    // Compose component defaults that match ChatKit-JS.
    material = material.copyWith(
      cardTheme: material.cardTheme.copyWith(
        shape: roundedRectangle,
        elevation: option?.elevations?.surface ?? 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: const Color(0x00000000),
      ),
      dialogTheme: material.dialogTheme.copyWith(
        shape: roundedRectangle,
        surfaceTintColor: const Color(0x00000000),
      ),
      bottomSheetTheme: material.bottomSheetTheme.copyWith(
        shape: bottomSheetRadius,
        elevation: option?.elevations?.surface ?? 8,
        backgroundColor: material.colorScheme.surface,
        surfaceTintColor: const Color(0x00000000),
      ),
      inputDecorationTheme: _inputDecorationTheme(material, spacing, radii),
      filledButtonTheme: _filledButtonTheme(material, spacing, radii),
      outlinedButtonTheme: _outlinedButtonTheme(material, spacing, radii),
      textButtonTheme: _textButtonTheme(material, spacing, radii),
      elevatedButtonTheme: _elevatedButtonTheme(material, spacing, radii),
      iconButtonTheme: _iconButtonTheme(material, radii),
      chipTheme: material.chipTheme.copyWith(
        shape: StadiumBorder(
          side: BorderSide(color: material.colorScheme.outlineVariant),
        ),
        labelPadding: EdgeInsets.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xxs,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xxs,
        ),
      ),
      dropdownMenuTheme: material.dropdownMenuTheme.copyWith(
        inputDecorationTheme:
            _inputDecorationTheme(material, spacing, radii).copyWith(
          filled: true,
        ),
      ),
      dataTableTheme: material.dataTableTheme.copyWith(
        headingRowColor: WidgetStateProperty.all(
          material.colorScheme.surfaceContainerHighest,
        ),
        headingTextStyle: material.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: material.textTheme.bodyMedium,
        dividerThickness: 1,
        columnSpacing: spacing.lg,
      ),
    );

    return material;
  }

  static double _baseRadiusForPreset(ThemeRadiusOption? preset) {
    switch (preset) {
      case ThemeRadiusOption.pill:
        return 24;
      case ThemeRadiusOption.round:
        return 18;
      case ThemeRadiusOption.soft:
        return 12;
      case ThemeRadiusOption.sharp:
        return 6;
      case null:
        return 12;
    }
  }

  static VisualDensity _visualDensityForOption(ThemeDensityOption? density) {
    switch (density) {
      case ThemeDensityOption.compact:
        return VisualDensity.compact;
      case ThemeDensityOption.spacious:
        return VisualDensity.comfortable;
      case ThemeDensityOption.normal:
      case null:
        return VisualDensity.standard;
    }
  }

  static Color? _applyAccentLevel(Color? color, int? level) {
    if (color == null || level == null) {
      return color;
    }
    final int clamped = level.clamp(0, 3).toInt();
    if (clamped == 0) {
      return color;
    }
    final hsl = HSLColor.fromColor(color);
    final lightnessAdjust = 0.04 * clamped;
    final saturationAdjust = 0.02 * clamped;
    final newLightness =
        (hsl.lightness + lightnessAdjust).clamp(0.0, 1.0).toDouble();
    final newSaturation =
        (hsl.saturation - saturationAdjust).clamp(0.0, 1.0).toDouble();
    return hsl
        .withLightness(newLightness)
        .withSaturation(newSaturation)
        .toColor();
  }

  static Color _resolveGrayscaleTone({
    required GrayscaleOptions? options,
    required String? explicit,
    required double targetLightness,
    required Color fallback,
    double saturation = 0.08,
  }) {
    final parsed = _parseColor(explicit);
    if (parsed != null) {
      return parsed;
    }
    if (options?.hue != null) {
      return _grayscaleFromHue(
        options!,
        targetLightness: targetLightness,
        saturation: saturation,
      );
    }
    return fallback;
  }

  static Color _grayscaleFromHue(
    GrayscaleOptions options, {
    required double targetLightness,
    double saturation = 0.08,
  }) {
    final hue = options.hue ?? 210;
    final int tint = options.tintStep?.clamp(0, 9).toInt() ?? 4;
    final int shade = options.shade?.clamp(-4, 4).toInt() ?? 0;
    final tintOffset = (tint - 4) * 0.012;
    final shadeOffset = shade * 0.02;
    final computedLightness =
        (targetLightness + tintOffset - shadeOffset).clamp(0.02, 0.98).toDouble();
    final computedSaturation =
        (saturation + shade * 0.01).clamp(0.0, 1.0).toDouble();

    return HSLColor.fromAHSL(
      1,
      hue,
      computedSaturation,
      computedLightness,
    ).toColor();
  }

  static InputDecorationTheme _inputDecorationTheme(
    ThemeData material,
    ChatKitSpacing spacing,
    ChatKitRadii radii,
  ) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: const BorderSide(color: Color(0x00000000), width: 0),
    );
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: BorderSide(
        color: material.colorScheme.outlineVariant,
        width: 1,
      ),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: BorderSide(
        color: material.colorScheme.primary,
        width: 1.5,
      ),
    );
    return InputDecorationTheme(
      filled: true,
      isDense: true,
      fillColor: material.colorScheme.surfaceContainerHigh,
      hintStyle: material.textTheme.bodyMedium?.copyWith(
        color: material.colorScheme.onSurface.withValues(alpha: 0.55),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.sm,
      ),
      border: baseBorder,
      enabledBorder: outlineBorder,
      disabledBorder: baseBorder,
      focusedBorder: focusBorder,
      errorBorder: outlineBorder.copyWith(
        borderSide: BorderSide(
          color: material.colorScheme.error,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: focusBorder.copyWith(
        borderSide: BorderSide(
          color: material.colorScheme.error,
          width: 1.5,
        ),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(
    ThemeData material,
    ChatKitSpacing spacing,
    ChatKitRadii radii,
  ) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(spacing.xxxl, spacing.xxl),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.button),
        ),
        textStyle: material.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
    ThemeData material,
    ChatKitSpacing spacing,
    ChatKitRadii radii,
  ) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(spacing.xxxl, spacing.xxl),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.sm,
        ),
        side: BorderSide(color: material.colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.button),
        ),
        textStyle: material.textTheme.labelLarge,
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(
    ThemeData material,
    ChatKitSpacing spacing,
    ChatKitRadii radii,
  ) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: Size(spacing.xxxl, spacing.xxl),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.button),
        ),
        textStyle: material.textTheme.labelLarge,
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(
    ThemeData material,
    ChatKitSpacing spacing,
    ChatKitRadii radii,
  ) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(spacing.xxxl, spacing.xxl),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.button),
        ),
        textStyle: material.textTheme.labelLarge,
      ),
    );
  }

  static IconButtonThemeData _iconButtonTheme(
    ThemeData material,
    ChatKitRadii radii,
  ) {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.icon),
        ),
        minimumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        backgroundColor: const Color(0x00000000),
        foregroundColor: material.colorScheme.onSurface,
      ),
    );
  }

  static ChatKitSurfaceStyle _surfaceFromOptions({
    required ChatKitSurfaceStyle base,
    ThemeComponentStyle? overrides,
  }) {
    if (overrides == null) {
      return base;
    }
    return ChatKitSurfaceStyle(
      background: _parseColor(overrides.background) ?? base.background,
      foreground: _parseColor(overrides.text) ?? base.foreground,
      border: _parseColor(overrides.border) ?? base.border,
      elevation: overrides.elevation ?? base.elevation,
      radius: overrides.radius ?? base.radius,
    );
  }

  static Color? _parseColor(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
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
}

/// Inherited theme scope used to expose [ChatKitThemeData] down the tree.
class ChatKitTheme extends InheritedWidget {
  const ChatKitTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ChatKitThemeData data;

  static ChatKitThemeData of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChatKitTheme>();
    assert(scope != null,
        'ChatKitTheme.of() called with no ChatKitTheme in context.');
    return scope!.data;
  }

  @override
  bool updateShouldNotify(ChatKitTheme oldWidget) => data != oldWidget.data;
}

/// Palette tokens derived from the resolved [ThemeData].
@immutable
class ChatKitPalette {
  const ChatKitPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.primary,
    required this.onPrimary,
    required this.primaryStrong,
    required this.onPrimaryStrong,
    required this.primaryStrongBorder,
    required this.secondary,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSurfaceSubtle,
    required this.borderStrong,
    required this.borderMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.overlayStrong,
    required this.overlayWeak,
    required this.transparent,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color primary;
  final Color onPrimary;
  final Color primaryStrong;
  final Color onPrimaryStrong;
  final Color primaryStrongBorder;
  final Color secondary;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color onSurfaceSubtle;
  final Color borderStrong;
  final Color borderMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color overlayStrong;
  final Color overlayWeak;
  final Color transparent;

  factory ChatKitPalette.fromMaterial(
    ThemeData material,
    GrayscaleOptions? grayscale,
  ) {
    final scheme = material.colorScheme;
    final brightness = scheme.brightness;
    final onSurface = ChatKitThemeData._resolveGrayscaleTone(
      options: grayscale,
      explicit: grayscale?.label1,
      targetLightness: brightness == Brightness.dark ? 0.88 : 0.12,
      fallback: scheme.onSurface,
      saturation: 0.12,
    );
    final onSurfaceMuted = onSurface.withValues(alpha: 0.72);
    final onSurfaceSubtle = onSurface.withValues(alpha: 0.55);
    final borderFallback = ChatKitThemeData._resolveGrayscaleTone(
      options: grayscale,
      explicit: grayscale?.border,
      targetLightness: brightness == Brightness.dark ? 0.55 : 0.7,
      fallback: scheme.outlineVariant,
      saturation: 0.08,
    );
    final overlayTint = ChatKitThemeData._resolveGrayscaleTone(
      options: grayscale,
      explicit: grayscale?.tintColor ?? grayscale?.tint,
      targetLightness: brightness == Brightness.dark ? 0.25 : 0.2,
      fallback: onSurface,
      saturation: 0.12,
    );
    final background = ChatKitThemeData._resolveGrayscaleTone(
      options: grayscale,
      explicit: grayscale?.background,
      targetLightness: brightness == Brightness.dark ? 0.08 : 0.98,
      fallback: material.scaffoldBackgroundColor,
      saturation: 0.04,
    );

    return ChatKitPalette(
      background: background,
      surface: scheme.surface,
      surfaceAlt: scheme.surfaceContainerHighest,
      surfaceContainer: scheme.surface.withValues(alpha: 0.98),
      surfaceContainerHigh: scheme.surface.withValues(alpha: 0.95),
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      primaryStrong: scheme.primary,
      onPrimaryStrong: scheme.onPrimary,
      primaryStrongBorder: scheme.primaryContainer.withValues(alpha: 0.45),
      secondary: scheme.secondary,
      onSurface: onSurface,
      onSurfaceMuted: onSurfaceMuted,
      onSurfaceSubtle: onSurfaceSubtle,
      borderStrong: borderFallback,
      borderMuted: scheme.outlineVariant,
      success: const Color(0xFF12B76A),
      warning: const Color(0xFFF79009),
      danger: const Color(0xFFD92D20),
      info: const Color(0xFF1570EF),
      overlayStrong: overlayTint.withValues(alpha: 0.65),
      overlayWeak: overlayTint.withValues(alpha: 0.35),
      transparent: const Color(0x00000000),
    );
  }
}

/// Standard spacing scale (multiples of 4) used across ChatKit surfaces.
@immutable
class ChatKitSpacing {
  const ChatKitSpacing({
    required this.xxxs,
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
  });

  final double xxxs;
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;

  factory ChatKitSpacing.defaults({ThemeDensityOption? density}) {
    final scale = switch (density) {
      ThemeDensityOption.compact => 0.88,
      ThemeDensityOption.spacious => 1.15,
      _ => 1.0,
    };
    double scaleValue(double value) =>
        (value * scale * 100).roundToDouble() / 100;

    return ChatKitSpacing(
      xxxs: scaleValue(2),
      xxs: scaleValue(4),
      xs: scaleValue(8),
      sm: scaleValue(12),
      md: scaleValue(16),
      lg: scaleValue(20),
      xl: scaleValue(24),
      xxl: scaleValue(32),
      xxxl: scaleValue(40),
    );
  }
}

/// Radii tokens centralising curvature across surfaces.
@immutable
class ChatKitRadii {
  const ChatKitRadii({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.full,
    required this.field,
    required this.button,
    required this.icon,
    required this.card,
    required this.composer,
    required this.messageBubble,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;
  final double field;
  final double button;
  final double icon;
  final double card;
  final double composer;
  final double messageBubble;

  factory ChatKitRadii.fromBase(double? base) {
    final core = base ?? 12;
    return ChatKitRadii(
      xs: math.max(2, core * 0.25),
      sm: math.max(4, core * 0.4),
      md: math.max(6, core * 0.6),
      lg: math.max(8, core * 0.8),
      xl: math.max(12, core * 1.0),
      full: 999,
      field: math.max(10, core * 0.9),
      button: math.max(10, core * 0.9),
      icon: 20,
      card: math.max(12, core),
      composer: math.max(20, core * 1.4),
      messageBubble: math.max(12, core),
    );
  }
}

/// Encapsulates typography primitives consumed by style helpers.
@immutable
class ChatKitTypography {
  const ChatKitTypography({
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.headlineSmall,
  });

  final TextStyle? bodyMedium;
  final TextStyle? bodySmall;
  final TextStyle? labelLarge;
  final TextStyle? labelMedium;
  final TextStyle? headlineSmall;

  factory ChatKitTypography.fromTheme(TextTheme textTheme) {
    return ChatKitTypography(
      bodyMedium: textTheme.bodyMedium,
      bodySmall: textTheme.bodySmall,
      labelLarge: textTheme.labelLarge,
      labelMedium: textTheme.labelMedium,
      headlineSmall: textTheme.headlineSmall,
    );
  }
}

/// Container for component-level surface tokens.
@immutable
class ChatKitComponentStyles {
  const ChatKitComponentStyles({
    required this.surface,
    required this.composer,
    required this.history,
    required this.assistantBubble,
    required this.userBubble,
  });

  final ChatKitSurfaceStyle surface;
  final ChatKitSurfaceStyle composer;
  final ChatKitSurfaceStyle history;
  final ChatKitSurfaceStyle assistantBubble;
  final ChatKitSurfaceStyle userBubble;
}

/// Describes a single surface's colours, radius, border and elevation.
@immutable
class ChatKitSurfaceStyle {
  const ChatKitSurfaceStyle({
    required this.background,
    required this.foreground,
    this.border,
    this.elevation = 0,
    this.radius,
  });

  final Color background;
  final Color foreground;
  final Color? border;
  final double elevation;
  final double? radius;
}

/// Drop shadow presets used for key elevations like composer overlays.
@immutable
class ChatKitShadows {
  const ChatKitShadows({
    required this.none,
    required this.soft,
    required this.medium,
    required this.strong,
  });

  final List<BoxShadow> none;
  final List<BoxShadow> soft;
  final List<BoxShadow> medium;
  final List<BoxShadow> strong;

  factory ChatKitShadows.defaults(ChatKitPalette palette) {
    return ChatKitShadows(
      none: const <BoxShadow>[],
      soft: <BoxShadow>[
        BoxShadow(
          color: palette.overlayWeak.withValues(alpha: 0.18),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      medium: <BoxShadow>[
        BoxShadow(
          color: palette.overlayWeak.withValues(alpha: 0.22),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      strong: <BoxShadow>[
        BoxShadow(
          color: palette.overlayStrong.withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
