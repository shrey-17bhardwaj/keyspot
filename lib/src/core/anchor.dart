import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// An angle with an explicit unit.
///
/// Keyspot never guesses whether a bare `double` means degrees or radians, so
/// every rotation argument takes one of these:
///
/// ```dart
/// const Rotation.degrees(-95);
/// const Rotation.radians(math.pi / 4);
/// const Rotation.none();
/// ```
@immutable
class Rotation {
  /// Creates a rotation of [radians] radians.
  const Rotation.radians(double radians) : _radians = radians;

  /// Creates a rotation of [degrees] degrees.
  const Rotation.degrees(double degrees)
      : _radians = degrees * (math.pi / 180.0);

  /// A rotation of zero.
  const Rotation.none() : _radians = 0.0;

  final double _radians;

  /// This rotation expressed in radians.
  double get radians => _radians;

  /// This rotation expressed in degrees.
  double get degrees => _radians * (180.0 / math.pi);

  /// Whether this rotation is (very close to) zero.
  bool get isZero => _radians.abs() < 1e-9;

  /// Linearly interpolates between two rotations in radian space.
  ///
  /// Interpolation is taken along the shortest signed path between the two
  /// angles, so animating from 350 to 10 degrees sweeps 20 degrees, not 340.
  static Rotation lerp(Rotation a, Rotation b, double t) {
    const double twoPi = math.pi * 2;
    double delta = (b._radians - a._radians) % twoPi;
    if (delta > math.pi) {
      delta -= twoPi;
    } else if (delta < -math.pi) {
      delta += twoPi;
    }
    return Rotation.radians(a._radians + delta * t);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Rotation && other._radians == _radians);

  @override
  int get hashCode => _radians.hashCode;

  @override
  String toString() => 'Rotation.degrees(${degrees.toStringAsFixed(1)})';
}

/// A point on, or relative to, a target widget.
///
/// The preferred form is [Anchor.key], which resolves live against a
/// [GlobalKey] every frame so it follows the widget through scrolls, resizes
/// and layout changes. [Anchor.offset] is the escape hatch for cases where no
/// key exists.
@immutable
class Anchor {
  /// Anchors to [key]'s widget, at the given [alignment] within its bounds.
  ///
  /// [alignment] follows Flutter's -1..1 convention, so
  /// `Alignment.bottomCenter` is the bottom edge midpoint. Pass an
  /// [AlignmentDirectional] to have the horizontal axis follow the ambient
  /// [TextDirection].
  const Anchor.key(GlobalKey key,
      {AlignmentGeometry alignment = Alignment.center})
      : _key = key,
        _alignment = alignment,
        _offset = null;

  /// Anchors to a fixed point in global (screen) coordinates.
  const Anchor.offset(Offset globalOffset)
      : _key = null,
        _alignment = Alignment.center,
        _offset = globalOffset;

  final GlobalKey? _key;
  final AlignmentGeometry _alignment;
  final Offset? _offset;

  /// The target key, or null for an [Anchor.offset].
  GlobalKey? get key => _key;

  /// Where within the target's bounds this anchor sits.
  AlignmentGeometry get alignment => _alignment;

  /// The fixed global offset, or null for an [Anchor.key].
  Offset? get offset => _offset;

  /// Whether this anchor tracks a widget rather than a fixed point.
  bool get isKeyed => _key != null;

  /// Resolves this anchor to a point inside [rect].
  ///
  /// [rect] is the target's bounds; it is ignored for [Anchor.offset].
  Offset resolveWithin(Rect rect, TextDirection direction) {
    final Offset? fixed = _offset;
    if (fixed != null) {
      return fixed;
    }
    return _alignment.resolve(direction).withinRect(rect);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Anchor &&
        other._key == _key &&
        other._alignment == _alignment &&
        other._offset == _offset;
  }

  @override
  int get hashCode => Object.hash(_key, _alignment, _offset);

  @override
  String toString() =>
      isKeyed ? 'Anchor.key($_key, $_alignment)' : 'Anchor.offset($_offset)';
}

/// Sugar for building an [Anchor] straight from a [GlobalKey].
extension KeyspotAnchorX on GlobalKey {
  /// Returns an [Anchor.key] for this key at [alignment].
  ///
  /// ```dart
  /// await keyspot.pointer.moveTo(sendButtonKey.anchor(Alignment.topCenter));
  /// ```
  Anchor anchor([AlignmentGeometry alignment = Alignment.center]) =>
      Anchor.key(this, alignment: alignment);
}
