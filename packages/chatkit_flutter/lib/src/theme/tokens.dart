import 'package:flutter/material.dart';

class ComponentStyleToken {
  const ComponentStyleToken({
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.elevation,
    this.radius,
  });

  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? elevation;
  final double? radius;

  ComponentStyleToken copyWith({
    Color? backgroundColor,
    Color? textColor,
    Color? borderColor,
    double? elevation,
    double? radius,
  }) {
    return ComponentStyleToken(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      borderColor: borderColor ?? this.borderColor,
      elevation: elevation ?? this.elevation,
      radius: radius ?? this.radius,
    );
  }

  static ComponentStyleToken? lerp(
    ComponentStyleToken? a,
    ComponentStyleToken? b,
    double t,
  ) {
    if (a == null && b == null) {
      return null;
    }
    return ComponentStyleToken(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      textColor: Color.lerp(a?.textColor, b?.textColor, t),
      borderColor: Color.lerp(a?.borderColor, b?.borderColor, t),
      elevation: _lerpDouble(a?.elevation, b?.elevation, t),
      radius: _lerpDouble(a?.radius, b?.radius, t),
    );
  }

  static double? _lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    return (a ?? 0) + ((b ?? 0) - (a ?? 0)) * t;
  }
}

class ChatKitThemeTokens extends ThemeExtension<ChatKitThemeTokens> {
  const ChatKitThemeTokens({
    this.backgroundGradient,
    this.surfaceElevation,
    this.historyElevation,
    this.historyStyle,
    this.composerStyle,
    this.assistantBubbleStyle,
    this.userBubbleStyle,
  });

  final Gradient? backgroundGradient;
  final double? surfaceElevation;
  final double? historyElevation;
  final ComponentStyleToken? historyStyle;
  final ComponentStyleToken? composerStyle;
  final ComponentStyleToken? assistantBubbleStyle;
  final ComponentStyleToken? userBubbleStyle;

  @override
  ChatKitThemeTokens copyWith({
    Gradient? backgroundGradient,
    double? surfaceElevation,
    double? historyElevation,
    ComponentStyleToken? historyStyle,
    ComponentStyleToken? composerStyle,
    ComponentStyleToken? assistantBubbleStyle,
    ComponentStyleToken? userBubbleStyle,
  }) {
    return ChatKitThemeTokens(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      surfaceElevation: surfaceElevation ?? this.surfaceElevation,
      historyElevation: historyElevation ?? this.historyElevation,
      historyStyle: historyStyle ?? this.historyStyle,
      composerStyle: composerStyle ?? this.composerStyle,
      assistantBubbleStyle: assistantBubbleStyle ?? this.assistantBubbleStyle,
      userBubbleStyle: userBubbleStyle ?? this.userBubbleStyle,
    );
  }

  @override
  ChatKitThemeTokens lerp(
    ThemeExtension<ChatKitThemeTokens>? other,
    double t,
  ) {
    if (other is! ChatKitThemeTokens) {
      return this;
    }
    return ChatKitThemeTokens(
      backgroundGradient: Gradient.lerp(
        backgroundGradient,
        other.backgroundGradient,
        t,
      ),
      surfaceElevation: ComponentStyleToken._lerpDouble(
        surfaceElevation,
        other.surfaceElevation,
        t,
      ),
      historyElevation: ComponentStyleToken._lerpDouble(
        historyElevation,
        other.historyElevation,
        t,
      ),
      historyStyle: ComponentStyleToken.lerp(
        historyStyle,
        other.historyStyle,
        t,
      ),
      composerStyle: ComponentStyleToken.lerp(
        composerStyle,
        other.composerStyle,
        t,
      ),
      assistantBubbleStyle: ComponentStyleToken.lerp(
        assistantBubbleStyle,
        other.assistantBubbleStyle,
        t,
      ),
      userBubbleStyle: ComponentStyleToken.lerp(
        userBubbleStyle,
        other.userBubbleStyle,
        t,
      ),
    );
  }
}
