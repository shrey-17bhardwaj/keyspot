import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

import 'harness.dart';

void main() {
  late KeyspotController controller;

  setUp(() => controller = KeyspotController());
  tearDown(() => controller.dispose());

  Future<List<GlobalKey>> mount(WidgetTester tester, int count) async {
    final List<GlobalKey> keys =
        List<GlobalKey>.generate(count, (int _) => GlobalKey());
    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              for (int i = 0; i < count; i++)
                Target(key: keys[i], label: 'step $i'),
            ],
          ),
        ),
      ),
    );
    return keys;
  }

  testWidgets('timed steps advance and the tour completes',
      (WidgetTester tester) async {
    final List<GlobalKey> keys = await mount(tester, 3);
    final KeyspotTour tour = KeyspotTour(
      id: 'timed',
      steps: <KeyspotStep>[
        for (int i = 0; i < 3; i++)
          KeyspotStep(
            id: 'step$i',
            targetKey: keys[i],
            shape: const SpotShape.rrect(),
            advance: const StepAdvance.after(Duration(milliseconds: 200)),
          ),
      ],
    );

    TourResult? result;
    controller.startTour(tour).then((TourResult value) => result = value);

    for (int i = 0; i < 3; i++) {
      await settleSpotlight(tester);
      expect(controller.activeTour?.index, i, reason: 'on step $i');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump();

    expect(result, TourResult.completed);
    expect(controller.activeTour, isNull);
  });

  testWidgets('manual steps wait for next()', (WidgetTester tester) async {
    final List<GlobalKey> keys = await mount(tester, 2);
    final KeyspotTour tour = KeyspotTour(
      id: 'manual',
      steps: <KeyspotStep>[
        for (int i = 0; i < 2; i++)
          KeyspotStep(
            id: 'step$i',
            targetKey: keys[i],
            shape: const SpotShape.rrect(),
            advance: StepAdvance.manual,
          ),
      ],
    );

    TourResult? result;
    controller.startTour(tour).then((TourResult value) => result = value);
    await settleSpotlight(tester);

    // Time alone must not advance a manual step.
    await tester.pump(const Duration(seconds: 5));
    expect(controller.activeTour?.index, 0);

    controller.activeTour!.next().ignore();
    await settleSpotlight(tester);
    expect(controller.activeTour?.index, 1);

    controller.activeTour!.next().ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(result, TourResult.completed);
  });

  testWidgets('previous() steps back', (WidgetTester tester) async {
    final List<GlobalKey> keys = await mount(tester, 3);
    final KeyspotTour tour = KeyspotTour(
      id: 'back',
      steps: <KeyspotStep>[
        for (int i = 0; i < 3; i++)
          KeyspotStep(
            id: 'step$i',
            targetKey: keys[i],
            shape: const SpotShape.rrect(),
            advance: StepAdvance.manual,
          ),
      ],
    );

    controller.startTour(tour).ignore();
    await settleSpotlight(tester);

    controller.activeTour!.next().ignore();
    await settleSpotlight(tester);
    expect(controller.activeTour?.index, 1);

    controller.activeTour!.previous().ignore();
    await settleSpotlight(tester);
    expect(controller.activeTour?.index, 0);

    // previous() on the first step is a no-op, not an underflow.
    controller.activeTour!.previous().ignore();
    await settleSpotlight(tester);
    expect(controller.activeTour?.index, 0);
  });

  testWidgets('skip() ends the tour as skipped', (WidgetTester tester) async {
    final List<GlobalKey> keys = await mount(tester, 3);
    final KeyspotTour tour = KeyspotTour(
      id: 'skip',
      steps: <KeyspotStep>[
        for (int i = 0; i < 3; i++)
          KeyspotStep(
            id: 'step$i',
            targetKey: keys[i],
            shape: const SpotShape.rrect(),
            advance: StepAdvance.manual,
          ),
      ],
    );

    TourResult? result;
    controller.startTour(tour).then((TourResult value) => result = value);
    await settleSpotlight(tester);

    controller.activeTour!.skip().ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(result, TourResult.skipped);
    expect(controller.activeTour, isNull);
  });

  testWidgets('storage marks a completed tour seen exactly once',
      (WidgetTester tester) async {
    final List<GlobalKey> keys = await mount(tester, 1);
    final InMemoryTourStorage storage = InMemoryTourStorage();
    final KeyspotTour tour = KeyspotTour(
      id: 'once',
      storage: storage,
      steps: <KeyspotStep>[
        KeyspotStep(
          id: 'only',
          targetKey: keys[0],
          shape: const SpotShape.rrect(),
          advance: const StepAdvance.after(Duration(milliseconds: 150)),
        ),
      ],
    );

    TourResult? first;
    controller.startTour(tour).then((TourResult value) => first = value);
    await settleSpotlight(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(first, TourResult.completed);
    expect(storage.seenTourIds, contains('once'));

    // A second run is skipped without showing anything.
    final TourResult second = await controller.startTour(tour);
    expect(second, TourResult.skipped);
    expect(spotlightPainter(tester), isNull);
  });

  testWidgets('a step content card is built with the live rect and session',
      (WidgetTester tester) async {
    final List<GlobalKey> keys = await mount(tester, 1);
    Rect? seenRect;
    int? seenIndex;

    final KeyspotTour tour = KeyspotTour(
      id: 'content',
      steps: <KeyspotStep>[
        KeyspotStep(
          id: 'only',
          targetKey: keys[0],
          shape: const SpotShape.rrect(),
          advance: StepAdvance.manual,
          contentBuilder:
              (BuildContext context, Rect rect, TourSession session) {
            seenRect = rect;
            seenIndex = session.index;
            return const Text('Tap here to compose');
          },
        ),
      ],
    );

    controller.startTour(tour).ignore();
    await settleSpotlight(tester);

    expect(find.text('Tap here to compose'), findsOneWidget);
    expect(seenIndex, 0);
    expect(seenRect, isNotNull);
    final Rect target = tester.getRect(find.byKey(keys[0]));
    expect(seenRect!.center.dy, closeTo(target.center.dy, 1.0));

    controller.activeTour!.skip().ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('onEnter runs before the spotlight appears',
      (WidgetTester tester) async {
    final List<GlobalKey> keys = await mount(tester, 1);
    final List<String> log = <String>[];

    final KeyspotTour tour = KeyspotTour(
      id: 'enter',
      steps: <KeyspotStep>[
        KeyspotStep(
          id: 'only',
          targetKey: keys[0],
          shape: const SpotShape.rrect(),
          advance: const StepAdvance.after(Duration(milliseconds: 150)),
          onEnter: (TourSession session) async {
            log.add('enter:${session.index}');
          },
        ),
      ],
    );

    controller.startTour(tour).ignore();
    await settleSpotlight(tester);
    expect(log, <String>['enter:0']);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('a throwing onEnter does not strand the tour',
      (WidgetTester tester) async {
    final List<GlobalKey> keys = await mount(tester, 1);
    final KeyspotTour tour = KeyspotTour(
      id: 'throwing',
      steps: <KeyspotStep>[
        KeyspotStep(
          id: 'only',
          targetKey: keys[0],
          shape: const SpotShape.rrect(),
          advance: const StepAdvance.after(Duration(milliseconds: 150)),
          onEnter: (TourSession session) async => throw StateError('boom'),
        ),
      ],
    );

    TourResult? result;
    controller.startTour(tour).then((TourResult value) => result = value);
    await settleSpotlight(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(result, TourResult.completed);
  });

  testWidgets('an empty tour completes immediately',
      (WidgetTester tester) async {
    await mount(tester, 1);
    const KeyspotTour tour = KeyspotTour(id: 'empty', steps: <KeyspotStep>[]);
    expect(await controller.startTour(tour), TourResult.completed);
  });
}
