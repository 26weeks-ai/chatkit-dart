import 'package:flutter/material.dart';

import 'chatkit_theme.dart';

enum ChatKitButtonVariant { solid, soft, outline, ghost }

enum ChatKitButtonSize { sm, md, lg }

enum ChatKitIconButtonVariant { solid, subtle, ghost }

/// Convenience helpers that translate [ChatKitThemeData] tokens into
/// consumable Flutter styles for inputs, buttons, charts, and feedback.
class ChatKitStyles {
  const ChatKitStyles._();

  static InputDecoration inputDecoration(
    BuildContext context, {
    String? label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helper,
    String? error,
    bool withBorder = false,
    bool dense = true,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final material = Theme.of(context);
    final theme = ChatKitTheme.of(context);
    final palette = theme.palette;
    final spacing = theme.spacing;
    final radii = theme.radii;

    final resolvedPadding = contentPadding ??
        EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: dense ? spacing.sm : spacing.md,
        );

    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: BorderSide(
        color: withBorder ? palette.borderMuted : palette.transparent,
        width: withBorder ? 1 : 0,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radii.field),
      borderSide: BorderSide(
        color: withBorder ? palette.primary : palette.borderStrong,
        width: withBorder ? 1.5 : 1,
      ),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      errorText: error,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: dense,
      filled: true,
      fillColor: palette.surfaceContainerHigh,
      contentPadding: resolvedPadding,
      border: baseBorder,
      enabledBorder: baseBorder,
      disabledBorder: baseBorder,
      focusedBorder: focusedBorder,
      errorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: palette.danger, width: 1.5),
      ),
      focusedErrorBorder: focusedBorder.copyWith(
        borderSide: BorderSide(color: palette.danger, width: 1.5),
      ),
      hintStyle: material.textTheme.bodyMedium?.copyWith(
        color: palette.onSurfaceSubtle,
      ),
    );
  }

  static ButtonStyle buttonStyle(
    BuildContext context, {
    ChatKitButtonVariant variant = ChatKitButtonVariant.solid,
    ChatKitButtonSize size = ChatKitButtonSize.md,
    bool danger = false,
  }) {
    final material = Theme.of(context);
    final theme = ChatKitTheme.of(context);
    final palette = theme.palette;
    final spacing = theme.spacing;
    final radii = theme.radii;

    final padding = switch (size) {
      ChatKitButtonSize.sm => EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
      ChatKitButtonSize.lg => EdgeInsets.symmetric(
          horizontal: spacing.xl,
          vertical: spacing.md,
        ),
      ChatKitButtonSize.md => EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.sm,
        ),
    };

    final minimumSize = switch (size) {
      ChatKitButtonSize.sm => Size(spacing.xxl, spacing.xl),
      ChatKitButtonSize.lg => Size(spacing.xxxl, spacing.xxl),
      ChatKitButtonSize.md => Size(spacing.xxxl, spacing.xxl),
    };

    final background = danger ? palette.danger : palette.primary;
    final foreground = danger ? palette.onSurface : palette.onPrimary;
    final dangerSoft = palette.danger.withValues(alpha: 0.12);
    final primarySoft = palette.primary.withValues(alpha: 0.12);

    final baseStyle = ButtonStyle(
      minimumSize: WidgetStateProperty.all(minimumSize),
      padding: WidgetStateProperty.all(padding),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.button),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        material.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return switch (variant) {
      ChatKitButtonVariant.solid => baseStyle.merge(
          ButtonStyle(
            backgroundColor: WidgetStateProperty.all(background),
            foregroundColor: WidgetStateProperty.all(foreground),
            overlayColor: WidgetStateProperty.all(
              foreground.withValues(alpha: 0.08),
            ),
          ),
        ),
      ChatKitButtonVariant.soft => baseStyle.merge(
          ButtonStyle(
            backgroundColor: WidgetStateProperty.all(
              danger ? dangerSoft : primarySoft,
            ),
            foregroundColor: WidgetStateProperty.all(
              danger ? palette.danger : palette.primary,
            ),
            overlayColor: WidgetStateProperty.all(
              (danger ? palette.danger : palette.primary)
                  .withValues(alpha: 0.1),
            ),
          ),
        ),
      ChatKitButtonVariant.outline => baseStyle.merge(
          ButtonStyle(
            backgroundColor: WidgetStateProperty.all(palette.transparent),
            foregroundColor: WidgetStateProperty.all(
              danger ? palette.danger : palette.onSurface,
            ),
            overlayColor: WidgetStateProperty.all(
              (danger ? palette.danger : palette.onSurface)
                  .withValues(alpha: 0.08),
            ),
            side: WidgetStateProperty.all(
              BorderSide(
                color: danger ? palette.danger : palette.borderMuted,
              ),
            ),
          ),
        ),
      ChatKitButtonVariant.ghost => baseStyle.merge(
          ButtonStyle(
            backgroundColor: WidgetStateProperty.all(palette.transparent),
            foregroundColor: WidgetStateProperty.all(
              danger ? palette.danger : palette.onSurface,
            ),
            overlayColor: WidgetStateProperty.all(
              (danger ? palette.danger : palette.onSurface)
                  .withValues(alpha: 0.08),
            ),
          ),
        ),
    };
  }

  static ButtonStyle iconButton(
    BuildContext context, {
    ChatKitIconButtonVariant variant = ChatKitIconButtonVariant.subtle,
    bool danger = false,
  }) {
    final theme = ChatKitTheme.of(context);
    final palette = theme.palette;
    final base = Theme.of(context).iconButtonTheme.style ??
        IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radii.icon),
          ),
          minimumSize: const Size.square(40),
        );

    final background = () {
      switch (variant) {
        case ChatKitIconButtonVariant.solid:
          return danger ? palette.danger : palette.onSurface;
        case ChatKitIconButtonVariant.subtle:
          return danger
              ? palette.danger.withValues(alpha: 0.12)
              : palette.onSurface.withValues(alpha: 0.08);
        case ChatKitIconButtonVariant.ghost:
          return palette.transparent;
      }
    }();

    final foreground = switch (variant) {
      ChatKitIconButtonVariant.solid =>
        danger ? palette.onSurface : palette.surface,
      ChatKitIconButtonVariant.subtle =>
        danger ? palette.danger : palette.onSurface,
      ChatKitIconButtonVariant.ghost =>
        danger ? palette.danger : palette.onSurface,
    };

    final overlay = foreground.withValues(alpha: 0.12);

    return base.merge(
      ButtonStyle(
        backgroundColor: WidgetStateProperty.all(background),
        foregroundColor: WidgetStateProperty.all(foreground),
        overlayColor: WidgetStateProperty.all(overlay),
      ),
    );
  }

  static Color statusColor(BuildContext context, String status) {
    final palette = ChatKitTheme.of(context).palette;
    switch (status) {
      case 'success':
        return palette.success;
      case 'warning':
        return palette.warning;
      case 'danger':
      case 'error':
        return palette.danger;
      case 'info':
      default:
        return palette.info;
    }
  }

  static List<Color> chartPalette(BuildContext context) {
    final palette = ChatKitTheme.of(context).palette;
    final primary = palette.primary;
    final hsl = HSLColor.fromColor(primary);
    return <Color>[
      primary,
      hsl.withHue((hsl.hue + 32) % 360).toColor(),
      hsl.withHue((hsl.hue + 64) % 360).toColor(),
      palette.info,
      palette.success,
      palette.warning,
      palette.danger,
    ];
  }
}
