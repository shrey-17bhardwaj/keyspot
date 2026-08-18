import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

import 'harness.dart';

void main() {
  late KeyspotController controller;

  setUp(() => controller = KeyspotController());
  tearDown(() => controller.dispose());

  Future<GlobalKey> mount(
    WidgetTester tester, {
    required VoidCallback onTargetPressed,
    VoidCallback? onBackgroundPressed,
  }) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBackgroundPressed,
                  child: const SizedBox.expand(),
                ),
              ),
              Center(child: Target(key: key, onTap: onTargetPressed)),
            ],
          ),
        ),
      ),
    );
    return key;
  }

  testWidgets('block absorbs taps outside the cut-out',
      (WidgetTester tester) async {
    int background = 0;
    final GlobalKey key = await mount(
      tester,
      onTargetPressed: () {},
      onBackgroundPressed: () => background++,
    );

    unawaitedSpotlight(
      controller.spotlight(
        key,
        shape: const SpotShape.rrect(),
        duration: const Duration(seconds: 30),
      ),
    );
    await settleSpotlight(tester);

    await tester.tapAt(const Offset(20.0, 20.0));
    await tester.pump();

    expect(background, 0, reason: 'the barrier should have eaten the tap');
    expect(controller.isSpotlightActive, isTrue);
  });

  testWidgets('passthrough lets taps reach the app',
      (WidgetTester tester) async {
    int background = 0;
    final GlobalKey key = await mount(
      tester,
      onTargetPressed: () {},
      onBackgroundPressed: () => background++,
    );

    unawaitedSpotlight(
      controller.spotlight(
        key,
        shape: const SpotShape.rrect(),
        barrier: const SpotBarrier.passthrough(),
        duration: const Duration(seconds: 30),
      ),
    );
    await settleSpotlight(tester);

    await tester.tapAt(const Offset(20.0, 20.0));
    await tester.pump();

    expect(background, 1);
  });

  testWidgets('dismissOnTap resolves on an outside tap only',
      (WidgetTester tester) async {
    final GlobalKey key = await mount(tester, onTargetPressed: () {});

    SpotlightOutcome? outcome;
    controller
        .spotlight(
          key,
          shape: const SpotShape.rrect(),
          barrier: const SpotBarrier.dismissOnTap(),
          duration: const Duration(seconds: 30),
        )
        .then((SpotlightOutcome value) => outcome = value);
    await settleSpotlight(tester);

    // Inside the cut-out: absorbed, no dismissal.
    await tester.tapAt(tester.getCenter(find.byKey(key)));
    await tester.pump();
    expect(outcome, isNull);

    // Outside: dismisses.
    await tester.tapAt(const Offset(20.0, 20.0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(outcome, SpotlightOutcome.dismissedByUser);
  });

  testWidgets('dismissOnTap with outsideOnly false dismisses anywhere',
      (WidgetTester tester) async {
    final GlobalKey key = await mount(tester, onTargetPressed: () {});

    SpotlightOutcome? outcome;
    controller
        .spotlight(
          key,
          shape: const SpotShape.rrect(),
          barrier: const SpotBarrier.dismissOnTap(outsideOnly: false),
          duration: const Duration(seconds: 30),
        )
        .then((SpotlightOutcome value) => outcome = value);
    await settleSpotlight(tester);

    await tester.tapAt(tester.getCenter(find.byKey(key)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(outcome, SpotlightOutcome.dismissedByUser);
  });

  testWidgets('targetOnly forwards the tap to the real widget and resolves',
      (WidgetTester tester) async {
    int targetTaps = 0;
    int background = 0;
    int callbackFired = 0;
    final GlobalKey key = await mount(
      tester,
      onTargetPressed: () => targetTaps++,
      onBackgroundPressed: () => background++,
    );

    SpotlightOutcome? outcome;
    controller
        .spotlight(
          key,
          shape: const SpotShape.rrect(),
          barrier: SpotBarrier.targetOnly(onTargetTap: () => callbackFired++),
          duration: const Duration(seconds: 30),
        )
        .then((SpotlightOutcome value) => outcome = value);
    await settleSpotlight(tester);

    // Outside stays blocked.
    await tester.tapAt(const Offset(20.0, 20.0));
    await tester.pump();
    expect(background, 0);
    expect(outcome, isNull);

    // The target itself receives the tap.
    await tester.tapAt(tester.getCenter(find.byKey(key)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(targetTaps, 1, reason: 'the real button must still fire');
    expect(callbackFired, 1);
    expect(outcome, SpotlightOutcome.targetTapped);
  });
}
