import 'package:flutter/widgets.dart';

/// The outline of a spotlight cut-out.
///
/// Use [SpotShape.auto] (the default) to mirror the target's own rounding where
/// keyspot can detect it, or pick an explicit shape.
sealed class SpotShape {
  /// Const constructor for subclasses.
  const SpotShape();

  /// A circle that circumscribes the padded target rect.
  const factory SpotShape.circle() = SpotShapeCircle;

  /// A rounded rectangle with the given corner [radius].
  const factory SpotShape.rrect({double radius}) = SpotShapeRRect;

  /// A rounded rectangle whose corner radius is half its shortest side.
  const factory SpotShape.stadium() = SpotShapeStadium;

  /// Mirrors the target's own rounding where it can be detected, falling back
  /// to a circle for square-ish targets and a 12px rounded rect otherwise.
  ///
  /// This is best-effort: it inspects the target's render object (and one level
  /// of descendants) for a clip, physical shape or box decoration. It is
  /// deliberately forgiving, and never throws.
  const factory SpotShape.auto() = SpotShapeAuto;

  /// A fully custom outline built from the padded target rect.
  const factory SpotShape.path(Path Function(Rect targetRect) builder) =
      SpotShapePath;
}

/// A circular spotlight. See [SpotShape.circle].
final class SpotShapeCircle extends SpotShape {
  /// Creates a circular spotlight.
  const SpotShapeCircle();

  @override
  bool operator ==(Object other) => other is SpotShapeCircle;

  @override
  int get hashCode => (SpotShapeCircle).hashCode;
}

/// A rounded-rectangle spotlight. See [SpotShape.rrect].
final class SpotShapeRRect extends SpotShape {
  /// Creates a rounded-rectangle spotlight with corner [radius].
  const SpotShapeRRect({this.radius = 12.0});

  /// The corner radius, in logical pixels.
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is SpotShapeRRect && other.radius == radius;

  @override
  int get hashCode => Object.hash(SpotShapeRRect, radius);
}

/// A stadium (pill) spotlight. See [SpotShape.stadium].
final class SpotShapeStadium extends SpotShape {
  /// Creates a stadium spotlight.
  const SpotShapeStadium();

  @override
  bool operator ==(Object other) => other is SpotShapeStadium;

  @override
  int get hashCode => (SpotShapeStadium).hashCode;
}

/// A spotlight whose shape is inferred from the target. See [SpotShape.auto].
final class SpotShapeAuto extends SpotShape {
  /// Creates an auto-resolving spotlight shape.
  const SpotShapeAuto();

  @override
  bool operator ==(Object other) => other is SpotShapeAuto;

  @override
  int get hashCode => (SpotShapeAuto).hashCode;
}

/// A spotlight with a caller-supplied outline. See [SpotShape.path].
final class SpotShapePath extends SpotShape {
  /// Creates a spotlight whose outline is produced by [builder].
  const SpotShapePath(this.builder);

  /// Builds the cut-out path from the padded target rect.
  final Path Function(Rect targetRect) builder;

  @override
  bool operator ==(Object other) =>
      other is SpotShapePath && other.builder == builder;

  @override
  int get hashCode => Object.hash(SpotShapePath, builder);
}
