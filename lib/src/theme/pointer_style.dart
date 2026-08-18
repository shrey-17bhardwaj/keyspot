import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

/// Visual configuration for the animated pointer.
///
/// Supply a [builder] to replace the built-in painted hand with any widget of
/// your own (an emoji, an `Image`, a Lottie animation, a mouse cursor). The
/// package itself has no asset or third-party dependencies.
@immutable
class PointerStyle {
  /// Creates a pointer style.
  const PointerStyle({
    this.builder,
    this.size = 56.0,
    this.handColor = const Color(0xFFFFFFFF),
    this.handOutlineColor = const Color(0x66000000),
    this.dotColor = const Color(0xFF4DD0E1),
    this.arrivedDotColor = const Color(0xFF7C4DFF),
    this.showGlowDot = false,
    this.hotspot = const Alignment(-0.34, -0.92),
    this.flipForRtl = false,
    this.scaleWithTextScaler = false,
  }) : assert(size > 0.0, 'size must be greater than zero');

  /// Builds the pointer widget.
  ///
  /// When null the package paints its built-in pointing hand. The widget is
  /// laid out inside a [size] by [size] box.
  final WidgetBuilder? builder;

  /// The edge length of the square box the pointer is laid out in, in logical
  /// pixels.
  ///
  /// This is a fixed logical size rather than a fraction of the screen, so the
  /// pointer stays usable on desktop windows of any size.
  final double size;

  /// Fill colour of the built-in hand. Ignored when [builder] is supplied.
  final Color handColor;

  /// Outline colour of the built-in hand. Ignored when [builder] is supplied.
  final Color handOutlineColor;

  /// Colour of the glow dot while the pointer is idle or moving.
  final Color dotColor;

  /// Colour the glow dot animates to once the pointer arrives at its target.
  final Color arrivedDotColor;

  /// Whether to paint the pulsing glow dot at the pointer's hotspot.
  ///
  /// Off by default, so the pointer is just the hand. Enable it when you want
  /// an explicit "this exact point" marker at the fingertip; its colour lerps
  /// from [dotColor] to [arrivedDotColor] when a glide arrives.
  final bool showGlowDot;

  /// Which point of the pointer widget sits exactly on the resolved anchor.
  ///
  /// Defaults to the fingertip of the built-in hand. Supply your own value when
  /// using [builder] so your artwork lines up with the target.
  final Alignment hotspot;

  /// Whether to mirror the pointer horizontally in right-to-left locales.
  final bool flipForRtl;

  /// Whether [size] should be multiplied by the ambient
  /// [MediaQueryData.textScaler].
  ///
  /// Off by default: the pointer is a graphic, not text, and scaling it with
  /// text can push it off small screens.
  final bool scaleWithTextScaler;

  /// Returns a copy of this style with the given fields replaced.
  PointerStyle copyWith({
    WidgetBuilder? builder,
    double? size,
    Color? handColor,
    Color? handOutlineColor,
    Color? dotColor,
    Color? arrivedDotColor,
    bool? showGlowDot,
    Alignment? hotspot,
    bool? flipForRtl,
    bool? scaleWithTextScaler,
  }) {
    return PointerStyle(
      builder: builder ?? this.builder,
      size: size ?? this.size,
      handColor: handColor ?? this.handColor,
      handOutlineColor: handOutlineColor ?? this.handOutlineColor,
      dotColor: dotColor ?? this.dotColor,
      arrivedDotColor: arrivedDotColor ?? this.arrivedDotColor,
      showGlowDot: showGlowDot ?? this.showGlowDot,
      hotspot: hotspot ?? this.hotspot,
      flipForRtl: flipForRtl ?? this.flipForRtl,
      scaleWithTextScaler: scaleWithTextScaler ?? this.scaleWithTextScaler,
    );
  }

  /// Linearly interpolates between two pointer styles.
  static PointerStyle? lerp(PointerStyle? a, PointerStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return PointerStyle(
      builder: t < 0.5 ? a.builder : b.builder,
      size: lerpDouble(a.size, b.size, t) ?? a.size,
      handColor: Color.lerp(a.handColor, b.handColor, t) ?? a.handColor,
      handOutlineColor: Color.lerp(a.handOutlineColor, b.handOutlineColor, t) ??
          a.handOutlineColor,
      dotColor: Color.lerp(a.dotColor, b.dotColor, t) ?? a.dotColor,
      arrivedDotColor: Color.lerp(a.arrivedDotColor, b.arrivedDotColor, t) ??
          a.arrivedDotColor,
      showGlowDot: t < 0.5 ? a.showGlowDot : b.showGlowDot,
      hotspot: Alignment.lerp(a.hotspot, b.hotspot, t) ?? a.hotspot,
      flipForRtl: t < 0.5 ? a.flipForRtl : b.flipForRtl,
      scaleWithTextScaler:
          t < 0.5 ? a.scaleWithTextScaler : b.scaleWithTextScaler,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PointerStyle &&
        other.builder == builder &&
        other.size == size &&
        other.handColor == handColor &&
        other.handOutlineColor == handOutlineColor &&
        other.dotColor == dotColor &&
        other.arrivedDotColor == arrivedDotColor &&
        other.showGlowDot == showGlowDot &&
        other.hotspot == hotspot &&
        other.flipForRtl == flipForRtl &&
        other.scaleWithTextScaler == scaleWithTextScaler;
  }

  @override
  int get hashCode => Object.hash(
        builder,
        size,
        handColor,
        handOutlineColor,
        dotColor,
        arrivedDotColor,
        showGlowDot,
        hotspot,
        flipForRtl,
        scaleWithTextScaler,
      );

  @override
  String toString() => 'PointerStyle(size: $size, hotspot: $hotspot)';
}
