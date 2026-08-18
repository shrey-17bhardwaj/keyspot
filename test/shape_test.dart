import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

void main() {
  const Rect wide = Rect.fromLTWH(0.0, 0.0, 200.0, 50.0);
  const Rect square = Rect.fromLTWH(0.0, 0.0, 100.0, 100.0);

  group('buildSpotPath', () {
    test('circle circumscribes the rect', () {
      final Rect bounds =
          buildSpotPath(const SpotShape.circle(), square).getBounds();
      final double diameter = math.sqrt(100.0 * 100.0 + 100.0 * 100.0);
      expect(bounds.width, closeTo(diameter, 0.01));
      expect(bounds.center.dx, closeTo(50.0, 0.01));
    });

    test('rrect keeps the rect bounds', () {
      final Rect bounds =
          buildSpotPath(const SpotShape.rrect(radius: 8.0), wide).getBounds();
      expect(bounds, wide);
    });

    test('rrect radius is capped at half the shortest side', () {
      // A radius of 999 on a 50px-tall rect must not produce a broken path.
      final Rect bounds =
          buildSpotPath(const SpotShape.rrect(radius: 999.0), wide).getBounds();
      expect(bounds, wide);
    });

    test('stadium keeps the rect bounds', () {
      final Rect bounds =
          buildSpotPath(const SpotShape.stadium(), wide).getBounds();
      expect(bounds, wide);
    });

    test('custom builder is used verbatim', () {
      bool called = false;
      final Path path = buildSpotPath(
        SpotShape.path((Rect rect) {
          called = true;
          return Path()..addRect(rect.deflate(10.0));
        }),
        wide,
      );
      expect(called, isTrue);
      expect(path.getBounds(), wide.deflate(10.0));
    });
  });

  group('resolveAutoSpotShape geometry fallback', () {
    test('square-ish targets become circles', () {
      expect(resolveAutoSpotShape(null, square), const SpotShape.circle());
      expect(
        resolveAutoSpotShape(null, const Rect.fromLTWH(0, 0, 100, 85)),
        const SpotShape.circle(),
      );
    });

    test('elongated targets become rounded rectangles', () {
      expect(resolveAutoSpotShape(null, wide), const SpotShape.rrect());
    });

    test('degenerate rects do not throw', () {
      expect(resolveAutoSpotShape(null, Rect.zero), const SpotShape.rrect());
    });
  });

  group('resolveAutoSpotShape render-object detection', () {
    testWidgets('mirrors a ClipRRect radius', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: ClipRRect(
            key: key,
            borderRadius: BorderRadius.circular(24.0),
            child: const SizedBox(width: 200.0, height: 50.0),
          ),
        ),
      );
      final SpotShape shape = resolveAutoSpotShape(key, wide);
      expect(shape, const SpotShape.rrect(radius: 24.0));
    });

    testWidgets('detects a circular decoration', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        Center(
          child: DecoratedBox(
            key: key,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF000000),
            ),
            child: const SizedBox(width: 200.0, height: 50.0),
          ),
        ),
      );
      // Detection wins over the elongated-rect heuristic.
      expect(resolveAutoSpotShape(key, wide), const SpotShape.circle());
    });

    testWidgets('detects a Material rounded border',
        (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Material(
              key: key,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: const SizedBox(width: 200.0, height: 50.0),
            ),
          ),
        ),
      );
      expect(
          resolveAutoSpotShape(key, wide), const SpotShape.rrect(radius: 16.0));
    });

    testWidgets('falls back when nothing is detectable',
        (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        Center(child: SizedBox(key: key, width: 200.0, height: 50.0)),
      );
      expect(resolveAutoSpotShape(key, wide), const SpotShape.rrect());
    });
  });
}
