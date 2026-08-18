import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

import 'harness.dart';

void main() {
  late KeyspotController controller;

  setUp(() => controller = KeyspotController());
  tearDown(() => controller.dispose());

  Future<(GlobalKey, GlobalKey)> mount(WidgetTester tester) async {
    final GlobalKey a = GlobalKey();
    final GlobalKey b = GlobalKey();
    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(
                  left: 40.0, top: 100.0, child: Target(key: a, label: 'a')),
              Positioned(
                  left: 40.0, top: 400.0, child: Target(key: b, label: 'b')),
            ],
          ),
        ),
      ),
    );
    return (a, b);
  }

  Offset? handCentre(WidgetTester tester) {
    final Finder finder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is CustomPaint && widget.painter is DefaultHandPainter,
    );
    if (finder.evaluate().isEmpty) {
      return null;
    }
    return tester.getCenter(finder.first);
  }

  testWidgets('show mounts at the anchor and never glides from the origin',
      (WidgetTester tester) async {
    final (GlobalKey a, _) = await mount(tester);

    controller.pointer.show(a.anchor()).ignore();
    await tester.pump();
    await tester.pump();

    final Offset? first = handCentre(tester);
    expect(first, isNotNull);
    // If the pointer had glided in from Offset.zero it would be near the
    // top-left corner on the first frame.
    expect(first!.dx, greaterThan(20.0));
    expect(first.dy, greaterThan(60.0));
  });

  testWidgets('moveTo completes only when the animation finishes',
      (WidgetTester tester) async {
    final (GlobalKey a, GlobalKey b) = await mount(tester);

    await controller.pointer.show(a.anchor());
    await tester.pump(const Duration(milliseconds: 300));

    bool done = false;
    controller.pointer
        .moveTo(b.anchor(), duration: const Duration(milliseconds: 500))
        .then((_) => done = true);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(done, isFalse, reason: 'must not resolve at the halfway point');
    expect(controller.pointer.phase, PointerPhase.moving);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(done, isTrue);
    expect(controller.pointer.phase, PointerPhase.arrived);
  });

  testWidgets('the pointer actually travels between the anchors',
      (WidgetTester tester) async {
    final (GlobalKey a, GlobalKey b) = await mount(tester);

    await controller.pointer.show(a.anchor());
    await tester.pump(const Duration(milliseconds: 300));
    final Offset start = handCentre(tester)!;

    controller.pointer
        .moveTo(b.anchor(), duration: const Duration(milliseconds: 400))
        .ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    final Offset end = handCentre(tester)!;
    expect(end.dy, greaterThan(start.dy + 200.0));
  });

  testWidgets('a second moveTo cancels the first without throwing',
      (WidgetTester tester) async {
    final (GlobalKey a, GlobalKey b) = await mount(tester);

    await controller.pointer.show(a.anchor());
    await tester.pump(const Duration(milliseconds: 300));

    bool firstDone = false;
    controller.pointer
        .moveTo(b.anchor(), duration: const Duration(milliseconds: 800))
        .then((_) => firstDone = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    bool secondDone = false;
    controller.pointer
        .moveTo(a.anchor(), duration: const Duration(milliseconds: 200))
        .then((_) => secondDone = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(firstDone, isTrue, reason: 'cancelled futures must still complete');
    expect(secondDone, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapPulse runs the requested number of pulses',
      (WidgetTester tester) async {
    final (GlobalKey a, _) = await mount(tester);
    await controller.pointer.show(a.anchor());
    await tester.pump(const Duration(milliseconds: 300));

    bool done = false;
    controller.pointer.tapPulse(count: 3).then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(done, isFalse, reason: 'one pulse is not three');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('hide detaches the pointer', (WidgetTester tester) async {
    final (GlobalKey a, _) = await mount(tester);

    await controller.pointer.show(a.anchor());
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.pointer.isVisible, isTrue);
    expect(handCentre(tester), isNotNull);

    controller.pointer.hide().ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(controller.pointer.isVisible, isFalse);
    expect(handCentre(tester), isNull);
  });

  testWidgets('sweep shows, moves and hides in one call',
      (WidgetTester tester) async {
    final (GlobalKey a, GlobalKey b) = await mount(tester);

    bool done = false;
    controller.pointer
        .sweep(
          a.anchor(),
          b.anchor(),
          duration: const Duration(milliseconds: 200),
          dwell: const Duration(milliseconds: 100),
        )
        .then((_) => done = true);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(handCentre(tester), isNotNull);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(done, isTrue);
    expect(controller.pointer.isVisible, isFalse);
  });

  testWidgets('pointer calls are safe with no scope mounted',
      (WidgetTester tester) async {
    final KeyspotController orphan = KeyspotController();
    addTearDown(orphan.dispose);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    await orphan.pointer.show(const Anchor.offset(Offset(10.0, 10.0)));
    await orphan.pointer.moveTo(const Anchor.offset(Offset(20.0, 20.0)));
    await orphan.pointer.tapPulse();
    await orphan.pointer.hide();

    expect(orphan.pointer.isVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion jump-cuts instead of gliding',
      (WidgetTester tester) async {
    final GlobalKey a = GlobalKey();
    final GlobalKey b = GlobalKey();
    await tester.pumpWidget(
      harness(
        controller: controller,
        disableAnimations: true,
        child: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(left: 40.0, top: 100.0, child: Target(key: a)),
              Positioned(left: 40.0, top: 400.0, child: Target(key: b)),
            ],
          ),
        ),
      ),
    );

    await controller.pointer.show(a.anchor());
    await tester.pump();

    bool done = false;
    controller.pointer
        .moveTo(b.anchor(), duration: const Duration(seconds: 5))
        .then((_) => done = true);
    await tester.pump();
    await tester.pump();

    expect(done, isTrue, reason: 'a 5s glide must not be waited out');
    expect(controller.pointer.phase, PointerPhase.arrived);
  });
}
