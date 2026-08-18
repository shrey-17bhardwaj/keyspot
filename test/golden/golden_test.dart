@Tags(<String>['golden'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

import '../harness.dart';

/// Pixel-snapshot coverage for the painted surfaces: spotlight shapes, ring
/// stacks at pulse extremes, the dim barrier, and the built-in hand.
///
/// Regenerate on macOS only (see CONTRIBUTING.md):
/// `flutter test --update-goldens --tags golden`
void main() {
  Future<void> pumpFixedSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600.0, 400.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpSpotlightScene(
    WidgetTester tester,
    KeyspotController controller,
    GlobalKey key, {
    KeyspotTheme theme = testTheme,
  }) async {
    await pumpFixedSurface(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        child: harness(
          controller: controller,
          theme: theme,
          child: Scaffold(
            backgroundColor: const Color(0xFFECEFF1),
            body: Center(child: Target(key: key)),
          ),
        ),
      ),
    );
  }

  testWidgets('spotlight: circle with a static two-ring stack',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();
    await pumpSpotlightScene(tester, controller, key);

    controller
        .spotlight(
          key,
          shape: const SpotShape.circle(),
          rings: const <RingStyle>[
            RingStyle(
                color: Color(0xFFFFFFFF), width: 6.0, pulse: RingPulse.none()),
            RingStyle(
                color: Color(0xFF00ACC1),
                width: 3.0,
                gap: 5.0,
                pulse: RingPulse.none()),
          ],
          duration: const Duration(seconds: 30),
        )
        .ignore();
    await settleSpotlight(tester);

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/spotlight_circle_rings.png'),
    );
  });

  testWidgets('spotlight: rounded rect', (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();
    await pumpSpotlightScene(tester, controller, key);

    controller
        .spotlight(
          key,
          shape: const SpotShape.rrect(radius: 24.0),
          rings: const <RingStyle>[
            RingStyle(
                color: Color(0xFFFF7043), width: 8.0, pulse: RingPulse.none()),
          ],
          duration: const Duration(seconds: 30),
        )
        .ignore();
    await settleSpotlight(tester);

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/spotlight_rrect.png'),
    );
  });

  testWidgets('spotlight: custom diamond path over the bare barrier',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();
    await pumpSpotlightScene(tester, controller, key);

    controller.spotlight(
      key,
      shape: SpotShape.path((Rect rect) {
        final Rect r = rect.inflate(8.0);
        return Path()
          ..moveTo(r.center.dx, r.top)
          ..lineTo(r.right, r.center.dy)
          ..lineTo(r.center.dx, r.bottom)
          ..lineTo(r.left, r.center.dy)
          ..close();
      }),
      rings: const <RingStyle>[],
      duration: const Duration(seconds: 30),
    ).ignore();
    await settleSpotlight(tester);

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/spotlight_custom_diamond.png'),
    );
  });

  testWidgets('spotlight: pulsing ring caught at its dimmest extreme',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();
    await pumpSpotlightScene(tester, controller, key);

    controller
        .spotlight(
          key,
          shape: const SpotShape.stadium(),
          rings: const <RingStyle>[
            RingStyle(
              color: Color(0xFFFFD740),
              width: 6.0,
              pulse: RingPulse(
                minOpacity: 0.1,
                maxOpacity: 1.0,
                period: Duration(milliseconds: 400),
              ),
            ),
          ],
          duration: const Duration(seconds: 30),
        )
        .ignore();
    // The pulse controller starts at full opacity and reverses; entry pumping
    // consumes 350ms, so one more 50ms pump lands exactly on the 400ms trough.
    await settleSpotlight(tester);
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/spotlight_pulse_min.png'),
    );
  });

  testWidgets('hand: built-in painter at 0 degrees',
      (WidgetTester tester) async {
    await pumpFixedSurface(tester);
    await tester.pumpWidget(_handScene(rotation: 0.0));
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/hand_0deg.png'),
    );
  });

  testWidgets('hand: built-in painter at -95 degrees',
      (WidgetTester tester) async {
    await pumpFixedSurface(tester);
    await tester.pumpWidget(_handScene(rotation: -95.0 * math.pi / 180.0));
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/hand_neg95deg.png'),
    );
  });
}

Widget _handScene({required double rotation}) {
  return Container(
    color: const Color(0xFF37474F),
    alignment: Alignment.center,
    child: RepaintBoundary(
      child: Container(
        color: const Color(0xFF37474F),
        width: 200.0,
        height: 200.0,
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: rotation,
          child: const SizedBox(
            width: 112.0,
            height: 112.0,
            child: CustomPaint(
              painter: DefaultHandPainter(
                fillColor: Color(0xFFFFFFFF),
                outlineColor: Color(0x66000000),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
