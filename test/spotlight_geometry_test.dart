import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

import 'harness.dart';

void main() {
  late KeyspotController controller;

  setUp(() => controller = KeyspotController());
  tearDown(() => controller.dispose());

  testWidgets('cut-out matches the target rect plus padding',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(body: Center(child: Target(key: key))),
      ),
    );

    final Rect target = tester.getRect(find.byKey(key));
    unawaitedSpotlight(
        controller.spotlight(key, shape: const SpotShape.rrect()));
    await settleSpotlight(tester);

    final Rect? cutout = cutoutBounds(tester);
    expect(cutout, isNotNull);
    // Default padding is 12 on every side.
    expect(cutout!.left, closeTo(target.left - 12.0, 0.5));
    expect(cutout.top, closeTo(target.top - 12.0, 0.5));
    expect(cutout.width, closeTo(target.width + 24.0, 0.5));
    expect(cutout.height, closeTo(target.height + 24.0, 0.5));
  });

  testWidgets('padding inflates the cut-out', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(body: Center(child: Target(key: key))),
      ),
    );

    final Rect target = tester.getRect(find.byKey(key));
    unawaitedSpotlight(
      controller.spotlight(
        key,
        shape: const SpotShape.rrect(),
        padding: const EdgeInsets.only(
            left: 4.0, top: 8.0, right: 16.0, bottom: 32.0),
      ),
    );
    await settleSpotlight(tester);

    final Rect cutout = cutoutBounds(tester)!;
    expect(cutout.left, closeTo(target.left - 4.0, 0.5));
    expect(cutout.top, closeTo(target.top - 8.0, 0.5));
    expect(cutout.right, closeTo(target.right + 16.0, 0.5));
    expect(cutout.bottom, closeTo(target.bottom + 32.0, 0.5));
  });

  testWidgets('off-centre targets are tracked correctly',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: Target(key: key),
          ),
        ),
      ),
    );

    final Rect target = tester.getRect(find.byKey(key));
    unawaitedSpotlight(
        controller.spotlight(key, shape: const SpotShape.rrect()));
    await settleSpotlight(tester);

    final Rect cutout = cutoutBounds(tester)!;
    expect(cutout.center.dx, closeTo(target.center.dx, 0.5));
    expect(cutout.center.dy, closeTo(target.center.dy, 0.5));
  });

  testWidgets('nothing is painted before a spotlight is requested',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(body: Center(child: Target(key: key))),
      ),
    );
    expect(spotlightPainter(tester), isNull);
    expect(controller.isSpotlightActive, isFalse);
  });

  testWidgets('the spotlight is torn down after it resolves',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(body: Center(child: Target(key: key))),
      ),
    );

    unawaitedSpotlight(
      controller.spotlight(key, duration: const Duration(milliseconds: 200)),
    );
    await settleSpotlight(tester);
    expect(controller.isSpotlightActive, isTrue);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.isSpotlightActive, isFalse);
    expect(spotlightPainter(tester), isNull);
  });
}
