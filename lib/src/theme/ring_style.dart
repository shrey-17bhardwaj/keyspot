import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Describes how a ring's opacity oscillates over time.
///
/// A pulse animates the ring between [minOpacity] and [maxOpacity] once every
/// [period], reversing at each end. Use [RingPulse.none] for a static ring.
@immutable
class RingPulse {
  /// Creates a pulse that oscillates between [minOpacity] and [maxOpacity].
  const RingPulse({
    this.minOpacity = 0.4,
    this.maxOpacity = 1.0,
    this.period = const Duration(milliseconds: 600),
  })  : assert(minOpacity >= 0.0 && minOpacity <= 1.0,
            'minOpacity must be between 0.0 and 1.0'),
        assert(maxOpacity >= 0.0 && maxOpacity <= 1.0,
            'maxOpacity must be between 0.0 and 1.0');

  /// Creates a pulse that never animates; the ring is drawn fully opaque.
  const RingPulse.none()
      : minOpacity = 1.0,
        maxOpacity = 1.0,
        period = const Duration(milliseconds: 600);

  /// The opacity multiplier at the low point of the pulse.
  final double minOpacity;

  /// The opacity multiplier at the high point of the pulse.
  final double maxOpacity;

  /// How long one half-cycle of the pulse takes.
  final Duration period;

  /// Whether this pulse produces visible motion.
  bool get isAnimated => minOpacity != maxOpacity;

  /// The opacity multiplier at animation value [t], where `t` runs 0..1.
  double opacityAt(double t) =>
      minOpacity + (maxOpacity - minOpacity) * t.clamp(0.0, 1.0);

  /// Returns a copy of this pulse with the given fields replaced.
  RingPulse copyWith({
    double? minOpacity,
    double? maxOpacity,
    Duration? period,
  }) {
    return RingPulse(
      minOpacity: minOpacity ?? this.minOpacity,
      maxOpacity: maxOpacity ?? this.maxOpacity,
      period: period ?? this.period,
    );
  }

  /// Linearly interpolates between two pulses.
  static RingPulse? lerp(RingPulse? a, RingPulse? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return RingPulse(
      minOpacity: lerpDouble(a.minOpacity, b.minOpacity, t) ?? a.minOpacity,
      maxOpacity: lerpDouble(a.maxOpacity, b.maxOpacity, t) ?? a.maxOpacity,
      period: t < 0.5 ? a.period : b.period,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RingPulse &&
        other.minOpacity == minOpacity &&
        other.maxOpacity == maxOpacity &&
        other.period == period;
  }

  @override
  int get hashCode => Object.hash(minOpacity, maxOpacity, period);

  @override
  String toString() =>
      'RingPulse($minOpacity..$maxOpacity over ${period.inMilliseconds}ms)';
}

/// A single ring drawn around a spotlight cut-out.
///
/// Rings are painted from the cut-out outwards in list order: the first ring
/// hugs the cut-out edge, and each subsequent ring sits [gap] logical pixels
/// beyond the previous one.
@immutable
class RingStyle {
  /// Creates a ring of the given [color] and stroke [width].
  const RingStyle({
    required this.color,
    this.width = 8.0,
    this.gap = 0.0,
    this.pulse = const RingPulse(),
  })  : assert(width >= 0.0, 'width must not be negative'),
        assert(gap >= 0.0, 'gap must not be negative');

  /// The stroke colour of the ring.
  final Color color;

  /// The stroke width of the ring, in logical pixels.
  final double width;

  /// The distance between this ring and the previous ring (or the cut-out edge
  /// for the first ring), in logical pixels.
  final double gap;

  /// How this ring's opacity animates over time.
  final RingPulse pulse;

  /// Returns a copy of this ring with the given fields replaced.
  RingStyle copyWith({
    Color? color,
    double? width,
    double? gap,
    RingPulse? pulse,
  }) {
    return RingStyle(
      color: color ?? this.color,
      width: width ?? this.width,
      gap: gap ?? this.gap,
      pulse: pulse ?? this.pulse,
    );
  }

  /// Linearly interpolates between two rings.
  static RingStyle? lerp(RingStyle? a, RingStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return RingStyle(
      color: Color.lerp(a.color, b.color, t) ?? a.color,
      width: lerpDouble(a.width, b.width, t) ?? a.width,
      gap: lerpDouble(a.gap, b.gap, t) ?? a.gap,
      pulse: RingPulse.lerp(a.pulse, b.pulse, t) ?? a.pulse,
    );
  }

  /// Linearly interpolates between two ring lists, element by element.
  static List<RingStyle> lerpList(
    List<RingStyle> a,
    List<RingStyle> b,
    double t,
  ) {
    final int count = a.length > b.length ? a.length : b.length;
    return <RingStyle>[
      for (int i = 0; i < count; i++)
        RingStyle.lerp(
              i < a.length ? a[i] : null,
              i < b.length ? b[i] : null,
              t,
            ) ??
            (i < a.length ? a[i] : b[i]),
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RingStyle &&
        other.color == color &&
        other.width == width &&
        other.gap == gap &&
        other.pulse == pulse;
  }

  @override
  int get hashCode => Object.hash(color, width, gap, pulse);

  @override
  String toString() => 'RingStyle($color, width: $width, gap: $gap)';
}
