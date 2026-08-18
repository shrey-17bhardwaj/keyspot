import 'package:flutter/widgets.dart';

/// Paints keyspot's built-in pointing hand.
///
/// Deliberately a [CustomPainter] rather than an asset: the package ships no
/// images and depends on nothing but Flutter. Supply
/// [PointerStyle.builder] to use your own artwork instead.
class DefaultHandPainter extends CustomPainter {
  /// Creates a hand painter.
  const DefaultHandPainter({
    required this.fillColor,
    required this.outlineColor,
  });

  /// The hand's fill colour.
  final Color fillColor;

  /// The hand's outline colour.
  final Color outlineColor;

  /// The hand is designed on a 100x100 grid; this is the fingertip's position
  /// on that grid, expressed as an [Alignment].
  static const Alignment fingertip = Alignment(-0.34, -0.92);

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    final Path hand = _buildHand();

    final Paint fill = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = outlineColor;

    canvas.drawPath(hand, fill);
    canvas.drawPath(hand, outline);
    canvas.restore();
  }

  Path _buildHand() {
    // Index finger, pointing up.
    final Path finger = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(24.0, 4.0, 44.0, 62.0),
          const Radius.circular(10.0),
        ),
      );
    // Fist.
    final Path fist = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(20.0, 44.0, 78.0, 94.0),
          const Radius.circular(20.0),
        ),
      );
    // Thumb.
    final Path thumb = Path()
      ..addOval(const Rect.fromLTRB(8.0, 56.0, 40.0, 88.0));
    // Knuckle bumps, so the fist does not read as a plain pill.
    final Path knuckles = Path()
      ..addOval(const Rect.fromLTRB(44.0, 42.0, 66.0, 64.0))
      ..addOval(const Rect.fromLTRB(58.0, 48.0, 80.0, 70.0));

    Path hand = Path.combine(PathOperation.union, fist, finger);
    hand = Path.combine(PathOperation.union, hand, thumb);
    hand = Path.combine(PathOperation.union, hand, knuckles);
    return hand;
  }

  @override
  bool shouldRepaint(covariant DefaultHandPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}
