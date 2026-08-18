import 'package:flutter/widgets.dart';

/// What the pointer is currently doing.
///
/// Styling reacts to this: the glow dot lerps from
/// [PointerStyle.dotColor] to [PointerStyle.arrivedDotColor] on [arrived].
enum PointerPhase {
  /// Mounted and stationary, having never moved or after being told to stop.
  idle,

  /// Mid-glide between two anchors.
  moving,

  /// Finished a glide. Set exactly when the glide animation completes, never
  /// before.
  arrived,
}

/// The trajectory the pointer follows between two anchors.
sealed class MotionPath {
  /// Const constructor for subclasses.
  const MotionPath();

  /// Travel in a straight line. This is the default.
  static const MotionPath line = MotionPathLine();

  /// Travel along a quadratic arc bulging perpendicular to the direct line.
  ///
  /// [MotionPathArc.height] is the bulge as a fraction of the distance
  /// travelled; positive values bow to the left of the direction of travel.
  /// An arc reads as a deliberate drag far better than a straight line does.
  const factory MotionPath.arc({double height}) = MotionPathArc;
}

/// See [MotionPath.line].
final class MotionPathLine extends MotionPath {
  /// Creates a straight-line motion path.
  const MotionPathLine();

  @override
  bool operator ==(Object other) => other is MotionPathLine;

  @override
  int get hashCode => (MotionPathLine).hashCode;
}

/// See [MotionPath.arc].
final class MotionPathArc extends MotionPath {
  /// Creates an arced motion path bulging by [height] of the travel distance.
  const MotionPathArc({this.height = 0.25});

  /// The bulge, as a fraction of the distance between the two anchors.
  final double height;

  @override
  bool operator ==(Object other) =>
      other is MotionPathArc && other.height == height;

  @override
  int get hashCode => Object.hash(MotionPathArc, height);
}

/// Computes the point at [t] (0..1) along [path] from [start] to [end].
Offset resolveMotionPoint(MotionPath path, Offset start, Offset end, double t) {
  switch (path) {
    case MotionPathLine():
      return Offset.lerp(start, end, t) ?? end;
    case MotionPathArc(:final height):
      final Offset delta = end - start;
      final Offset normal = Offset(-delta.dy, delta.dx);
      final double length = normal.distance;
      final Offset unitNormal = length == 0.0 ? Offset.zero : normal / length;
      final Offset control =
          (start + end) / 2.0 + unitNormal * (delta.distance * height);
      final double inverse = 1.0 - t;
      return start * (inverse * inverse) +
          control * (2.0 * inverse * t) +
          end * (t * t);
  }
}
