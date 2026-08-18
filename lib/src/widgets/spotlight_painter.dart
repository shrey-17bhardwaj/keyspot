import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/ring_style.dart';

/// Paints the dim layer, the rings, and the cut-out.
///
/// The whole thing is composited in one [Canvas.saveLayer] so the cut-out can
/// be punched with [BlendMode.clear]; each ring gets its own layer so clearing
/// its inner edge never eats into the dim behind it.
class SpotlightPainter extends CustomPainter {
  /// Creates a spotlight painter.
  const SpotlightPainter({
    required this.cutout,
    required this.barrierColor,
    required this.barrierOpacity,
    required this.rings,
    required this.ringOpacities,
    required this.globalOpacity,
  });

  /// The cut-out outline, already scaled for the entry animation.
  final Path? cutout;

  /// The dim colour.
  final Color barrierColor;

  /// The dim opacity at full strength.
  final double barrierOpacity;

  /// The rings to draw, innermost first.
  final List<RingStyle> rings;

  /// The current pulse opacity multiplier for each entry in [rings].
  final List<double> ringOpacities;

  /// Multiplies everything, for the exit fade.
  final double globalOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (globalOpacity <= 0.0) {
      return;
    }
    final Rect bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(
      bounds,
      Paint()
        ..color = applyOpacity(barrierColor, barrierOpacity * globalOpacity),
    );

    final Path? path = cutout;
    if (path != null) {
      double distance = 0.0;
      for (int i = 0; i < rings.length; i++) {
        final RingStyle ring = rings[i];
        final double inner = distance + ring.gap;
        final double outer = inner + ring.width;
        distance = outer;
        if (ring.width <= 0.0) {
          continue;
        }
        final double opacity =
            (i < ringOpacities.length ? ringOpacities[i] : 1.0) * globalOpacity;
        if (opacity <= 0.0) {
          continue;
        }
        // Each ring is an annulus from `inner` to `outer` outside the cut-out
        // outline. Draw it in its own layer: a wide stroke, minus a narrower
        // one. Without the layer the subtraction would punch through the dim.
        canvas.saveLayer(bounds, Paint());
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = outer * 2.0
            ..color = applyOpacity(ring.color, opacity),
        );
        if (inner > 0.0) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = inner * 2.0
              ..blendMode = BlendMode.clear,
          );
        }
        canvas.restore();
      }
      canvas.drawPath(path, Paint()..blendMode = BlendMode.clear);
    }
    canvas.restore();
  }

  /// Applies [opacity] to [color].
  ///
  /// Deliberately built on [Color.withAlpha] rather than the deprecated
  /// `withOpacity`, so the package analyses clean across every supported
  /// Flutter version. Any alpha already on [color] is replaced, not multiplied:
  /// pass opaque colours and use the opacity knobs to fade them.
  static Color applyOpacity(Color color, double opacity) =>
      color.withAlpha((255.0 * opacity.clamp(0.0, 1.0)).round());

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.cutout != cutout ||
        oldDelegate.barrierColor != barrierColor ||
        oldDelegate.barrierOpacity != barrierOpacity ||
        oldDelegate.globalOpacity != globalOpacity ||
        !listEquals(oldDelegate.rings, rings) ||
        !listEquals(oldDelegate.ringOpacities, ringOpacities);
  }
}
