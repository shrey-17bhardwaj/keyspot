import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

import 'harness.dart';

void main() {
  testWidgets('an unresolvable target resolves the future and paints nothing',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey never = GlobalKey();

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    SpotlightOutcome? outcome;
    controller
        .spotlight(never, retryFrames: 2)
        .then((SpotlightOutcome value) => outcome = value);

    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(outcome, SpotlightOutcome.cancelled);
    expect(spotlightPainter(tester), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a target unmounted mid-spotlight fades out and resolves',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();
    final ValueNotifier<bool> present = ValueNotifier<bool>(true);
    addTearDown(present.dispose);

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: present,
              builder: (BuildContext context, bool visible, Widget? _) {
                return visible
                    ? Target(key: key)
                    : const SizedBox(width: 80.0, height: 40.0);
              },
            ),
          ),
        ),
      ),
    );

    SpotlightOutcome? outcome;
    controller
        .spotlight(
          key,
          shape: const SpotShape.rrect(),
          duration: const Duration(seconds: 30),
        )
        .then((SpotlightOutcome value) => outcome = value);
    await settleSpotlight(tester);
    expect(cutoutBounds(tester), isNotNull);

    present.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(outcome, isNotNull, reason: 'the future must not hang forever');
    expect(controller.isSpotlightActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second spotlight replaces the first',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey a = GlobalKey();
    final GlobalKey b = GlobalKey();

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(left: 20.0, top: 60.0, child: Target(key: a)),
              Positioned(left: 20.0, top: 400.0, child: Target(key: b)),
            ],
          ),
        ),
      ),
    );

    SpotlightOutcome? first;
    controller
        .spotlight(
          a,
          shape: const SpotShape.rrect(),
          duration: const Duration(seconds: 30),
        )
        .then((SpotlightOutcome value) => first = value);
    await settleSpotlight(tester);
    final Rect firstRect = cutoutBounds(tester)!;

    controller
        .spotlight(
          b,
          shape: const SpotShape.rrect(),
          duration: const Duration(seconds: 30),
        )
        .ignore();
    await settleSpotlight(tester);

    expect(first, SpotlightOutcome.cancelled);
    final Rect secondRect = cutoutBounds(tester)!;
    expect(secondRect.center.dy, greaterThan(firstRect.center.dy + 100.0));
    expect(controller.isSpotlightActive, isTrue);
  });

  testWidgets('disposing mid-spotlight completes the future without throwing',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    final GlobalKey key = GlobalKey();

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(body: Center(child: Target(key: key))),
      ),
    );

    SpotlightOutcome? outcome;
    controller
        .spotlight(key, duration: const Duration(seconds: 30))
        .then((SpotlightOutcome value) => outcome = value);
    await settleSpotlight(tester);

    controller.dispose();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(outcome, SpotlightOutcome.cancelled);
    expect(tester.takeException(), isNull);

    // Post-dispose calls are inert rather than fatal.
    expect(await controller.spotlight(key), SpotlightOutcome.cancelled);
  });

  testWidgets('disposing mid-glide does not throw',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    final GlobalKey a = GlobalKey();
    final GlobalKey b = GlobalKey();

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(left: 20.0, top: 60.0, child: Target(key: a)),
              Positioned(left: 20.0, top: 400.0, child: Target(key: b)),
            ],
          ),
        ),
      ),
    );

    await controller.pointer.show(a.anchor());
    await tester.pump(const Duration(milliseconds: 300));

    bool settled = false;
    controller.pointer
        .moveTo(b.anchor(), duration: const Duration(seconds: 2))
        .then((_) => settled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    controller.dispose();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(settled, isA<bool>());
  });

  testWidgets('spotlight without a scope is inert',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(home: Center(child: Target(key: key))),
    );

    expect(await controller.spotlight(key), SpotlightOutcome.cancelled);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hideSpotlight resolves an active spotlight',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(body: Center(child: Target(key: key))),
      ),
    );

    SpotlightOutcome? outcome;
    controller
        .spotlight(key, duration: const Duration(seconds: 30))
        .then((SpotlightOutcome value) => outcome = value);
    await settleSpotlight(tester);

    controller.hideSpotlight().ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(outcome, SpotlightOutcome.cancelled);
    expect(controller.isSpotlightActive, isFalse);
  });

  testWidgets('until() holds the spotlight for exactly its duration',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(body: Center(child: Target(key: key))),
      ),
    );

    final Completer<void> action = Completer<void>();
    SpotlightOutcome? outcome;
    controller
        .spotlight(key, until: () => action.future)
        .then((SpotlightOutcome value) => outcome = value);
    await settleSpotlight(tester);

    // Well past the default 2s duration; `until` must win.
    await tester.pump(const Duration(seconds: 5));
    expect(outcome, isNull);
    expect(controller.isSpotlightActive, isTrue);

    action.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(outcome, SpotlightOutcome.finished);
  });

  testWidgets('a failing until() still resolves the spotlight',
      (WidgetTester tester) async {
    final KeyspotController controller = KeyspotController();
    addTearDown(controller.dispose);
    final GlobalKey key = GlobalKey();

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(body: Center(child: Target(key: key))),
      ),
    );

    SpotlightOutcome? outcome;
    controller
        .spotlight(key, until: () async => throw StateError('boom'))
        .then((SpotlightOutcome value) => outcome = value);
    await settleSpotlight(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expect(outcome, SpotlightOutcome.finished);
    expect(tester.takeException(), isNull);
  });
}
