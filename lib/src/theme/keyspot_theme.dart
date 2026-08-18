import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeExtension;
import 'package:flutter/widgets.dart';

import 'pointer_style.dart';
import 'ring_style.dart';

/// Visual defaults for every keyspot overlay in a subtree.
///
/// Resolution order for any value is: an explicit argument passed to
/// [KeyspotController.spotlight] (or the pointer call), then the theme given to
/// `KeyspotScope`, then `Theme.of(context).extension<KeyspotTheme>()`, then the
/// built-in defaults on this class.
///
/// Because this is a [ThemeExtension] you can also install it globally:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[
///     KeyspotTheme(barrierOpacity: 0.85),
///   ]),
/// )
/// ```
@immutable
class KeyspotTheme extends ThemeExtension<KeyspotTheme> {
  /// Creates a keyspot theme. Every argument has a sensible default.
  const KeyspotTheme({
    this.barrierColor = const Color(0xFF000000),
    this.barrierOpacity = 0.7,
    this.rings = defaultRings,
    this.entryDuration = const Duration(milliseconds: 1000),
    this.exitDuration = const Duration(milliseconds: 150),
    this.dimFraction = 0.3,
    this.pointerStyle = const PointerStyle(),
    this.defaultSpotlightDuration = const Duration(seconds: 2),
  })  : assert(barrierOpacity >= 0.0 && barrierOpacity <= 1.0,
            'barrierOpacity must be between 0.0 and 1.0'),
        assert(dimFraction > 0.0 && dimFraction < 1.0,
            'dimFraction must be between 0.0 and 1.0, exclusive');

  /// The default ring stack: a white ring hugging the cut-out and an accent
  /// ring just outside it.
  static const List<RingStyle> defaultRings = <RingStyle>[
    RingStyle(color: Color(0xFFFFFFFF), width: 6.0),
    RingStyle(color: Color(0xFF4DD0E1), width: 4.0, gap: 4.0),
  ];

  /// The colour the screen is dimmed with outside the cut-out.
  final Color barrierColor;

  /// How opaque the dim layer is at full strength.
  final double barrierOpacity;

  /// The rings drawn around the cut-out, innermost first.
  ///
  /// Pass `const <RingStyle>[]` to a spotlight call to suppress rings entirely.
  final List<RingStyle> rings;

  /// How long the full entry choreography takes.
  ///
  /// The dim fades in over the first [dimFraction] of this duration; the
  /// cut-out and rings scale up over the remainder.
  final Duration entryDuration;

  /// How long the overlay takes to fade out when dismissed.
  final Duration exitDuration;

  /// The fraction of [entryDuration] spent fading the dim layer in.
  final double dimFraction;

  /// Default appearance of the animated pointer.
  final PointerStyle pointerStyle;

  /// How long a spotlight stays up when neither `until` nor `duration` is given.
  final Duration defaultSpotlightDuration;

  @override
  KeyspotTheme copyWith({
    Color? barrierColor,
    double? barrierOpacity,
    List<RingStyle>? rings,
    Duration? entryDuration,
    Duration? exitDuration,
    double? dimFraction,
    PointerStyle? pointerStyle,
    Duration? defaultSpotlightDuration,
  }) {
    return KeyspotTheme(
      barrierColor: barrierColor ?? this.barrierColor,
      barrierOpacity: barrierOpacity ?? this.barrierOpacity,
      rings: rings ?? this.rings,
      entryDuration: entryDuration ?? this.entryDuration,
      exitDuration: exitDuration ?? this.exitDuration,
      dimFraction: dimFraction ?? this.dimFraction,
      pointerStyle: pointerStyle ?? this.pointerStyle,
      defaultSpotlightDuration:
          defaultSpotlightDuration ?? this.defaultSpotlightDuration,
    );
  }

  @override
  KeyspotTheme lerp(covariant ThemeExtension<KeyspotTheme>? other, double t) {
    if (other is! KeyspotTheme) {
      return this;
    }
    return KeyspotTheme(
      barrierColor:
          Color.lerp(barrierColor, other.barrierColor, t) ?? barrierColor,
      barrierOpacity:
          lerpDouble(barrierOpacity, other.barrierOpacity, t) ?? barrierOpacity,
      rings: RingStyle.lerpList(rings, other.rings, t),
      entryDuration: t < 0.5 ? entryDuration : other.entryDuration,
      exitDuration: t < 0.5 ? exitDuration : other.exitDuration,
      dimFraction: lerpDouble(dimFraction, other.dimFraction, t) ?? dimFraction,
      pointerStyle: PointerStyle.lerp(pointerStyle, other.pointerStyle, t) ??
          pointerStyle,
      defaultSpotlightDuration:
          t < 0.5 ? defaultSpotlightDuration : other.defaultSpotlightDuration,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is KeyspotTheme &&
        other.barrierColor == barrierColor &&
        other.barrierOpacity == barrierOpacity &&
        listEquals(other.rings, rings) &&
        other.entryDuration == entryDuration &&
        other.exitDuration == exitDuration &&
        other.dimFraction == dimFraction &&
        other.pointerStyle == pointerStyle &&
        other.defaultSpotlightDuration == defaultSpotlightDuration;
  }

  @override
  int get hashCode => Object.hash(
        barrierColor,
        barrierOpacity,
        Object.hashAll(rings),
        entryDuration,
        exitDuration,
        dimFraction,
        pointerStyle,
        defaultSpotlightDuration,
      );
}
