import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/spot_shape.dart';

/// Builds the cut-out outline for [shape] over [rect].
///
/// [targetKey] is only consulted for [SpotShape.auto]; pass null to make `auto`
/// fall back to its geometric heuristic.
Path buildSpotPath(SpotShape shape, Rect rect, {GlobalKey? targetKey}) {
  final SpotShape resolved =
      shape is SpotShapeAuto ? resolveAutoSpotShape(targetKey, rect) : shape;
  switch (resolved) {
    case SpotShapePath(:final builder):
      return builder(rect);
    case SpotShapeCircle():
      final double radius =
          math.sqrt(rect.width * rect.width + rect.height * rect.height) / 2.0;
      return Path()
        ..addOval(Rect.fromCircle(center: rect.center, radius: radius));
    case SpotShapeStadium():
      final double radius = math.min(rect.width, rect.height) / 2.0;
      return Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    case SpotShapeRRect(:final radius):
      final double capped =
          math.min(radius, math.min(rect.width, rect.height) / 2.0);
      return Path()
        ..addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(math.max(0.0, capped))),
        );
    case SpotShapeAuto():
      // resolveAutoSpotShape never returns auto; this arm keeps the switch
      // exhaustive.
      return Path()
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12.0)));
  }
}

/// Infers a concrete shape for [SpotShape.auto].
///
/// Detection order:
///
/// 1. The target's own render object, then one level of descendants, is
///    inspected for a clip, physical shape or box decoration that carries a
///    corner radius or a circular/stadium outline.
/// 2. Failing that, targets whose width and height are within 20% of each other
///    are given a circle.
/// 3. Everything else gets a 12px rounded rectangle.
///
/// Never throws; any inspection failure falls through to the geometric rules.
SpotShape resolveAutoSpotShape(GlobalKey? targetKey, Rect rect) {
  final SpotShape? detected = _detectShape(targetKey);
  if (detected != null) {
    return detected;
  }
  final double shorter = math.min(rect.width, rect.height);
  final double longer = math.max(rect.width, rect.height);
  if (longer <= 0.0) {
    return const SpotShape.rrect();
  }
  if (shorter / longer >= 0.8) {
    return const SpotShape.circle();
  }
  return const SpotShape.rrect();
}

SpotShape? _detectShape(GlobalKey? targetKey) {
  if (targetKey == null) {
    return null;
  }
  final RenderObject? root = targetKey.currentContext?.findRenderObject();
  if (root == null) {
    return null;
  }
  try {
    final SpotShape? own = _shapeOf(root);
    if (own != null) {
      return own;
    }
    SpotShape? childShape;
    root.visitChildren((RenderObject child) {
      childShape ??= _shapeOf(child);
    });
    return childShape;
  } catch (_) {
    return null;
  }
}

SpotShape? _shapeOf(RenderObject object) {
  if (object is RenderClipOval) {
    return const SpotShape.circle();
  }
  if (object is RenderClipRRect) {
    return _fromRadius(object.borderRadius);
  }
  if (object is RenderPhysicalModel) {
    if (object.shape == BoxShape.circle) {
      return const SpotShape.circle();
    }
    return _fromRadius(object.borderRadius);
  }
  if (object is RenderPhysicalShape) {
    final CustomClipper<Path>? clipper = object.clipper;
    if (clipper is ShapeBorderClipper) {
      return _fromShapeBorder(clipper.shape);
    }
    return null;
  }
  if (object is RenderDecoratedBox) {
    final Decoration decoration = object.decoration;
    if (decoration is BoxDecoration) {
      if (decoration.shape == BoxShape.circle) {
        return const SpotShape.circle();
      }
      return _fromRadius(decoration.borderRadius);
    }
    if (decoration is ShapeDecoration) {
      return _fromShapeBorder(decoration.shape);
    }
  }
  return null;
}

SpotShape? _fromShapeBorder(ShapeBorder border) {
  if (border is CircleBorder) {
    return const SpotShape.circle();
  }
  if (border is StadiumBorder) {
    return const SpotShape.stadium();
  }
  if (border is RoundedRectangleBorder) {
    return _fromRadius(border.borderRadius);
  }
  return null;
}

SpotShape? _fromRadius(BorderRadiusGeometry? geometry) {
  if (geometry == null) {
    return null;
  }
  final BorderRadius radius = geometry.resolve(TextDirection.ltr);
  final double corner = radius.topLeft.x;
  if (corner <= 0.0) {
    return null;
  }
  return SpotShape.rrect(radius: corner);
}
