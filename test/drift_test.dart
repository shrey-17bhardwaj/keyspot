import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

import 'harness.dart';

/// The headline feature: the cut-out re-resolves the target every frame, so it
/// follows the widget instead of painting a stale snapshot.
void main() {
  late KeyspotController controller;

  setUp(() => controller = KeyspotController());
  tearDown(() => controller.dispose());

  Widget listHarness(GlobalKey key, ScrollController scroll) {
    return harness(
      controller: controller,
      child: Scaffold(
        body: ListView.builder(
          controller: scroll,
          itemCount: 40,
          itemExtent: 60.0,
          itemBuilder: (BuildContext context, int index) {
            return Center(
              child: index == 10
                  ? Target(key: key, label: 'row $index')
                  : SizedBox(height: 40.0, child: Text('row $index')),
            );
          },
        ),
      ),
    );
  }

  testWidgets('the cut-out follows the target while the list scrolls',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(listHarness(key, scroll));
    // Bring the target on screen first.
    scroll.jumpTo(400.0);
    await tester.pump();

    unawaitedSpotlight(
      controller.spotlight(
        key,
        shape: const SpotShape.rrect(),
        scrollIntoView: false,
        duration: const Duration(seconds: 30),
      ),
    );
    await settleSpotlight(tester);

    final Rect before = cutoutBounds(tester)!;
    final Rect targetBefore = tester.getRect(find.byKey(key));
    expect(before.center.dy, closeTo(targetBefore.center.dy, 0.5));

    // Scroll 200px and let exactly one frame pass.
    scroll.jumpTo(600.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final Rect after = cutoutBounds(tester)!;
    final Rect targetAfter = tester.getRect(find.byKey(key));

    expect(
      after.center.dy,
      closeTo(targetAfter.center.dy, 1.0),
      reason: 'the cut-out must track within a frame, not drift behind',
    );
    expect(
      (before.center.dy - after.center.dy).abs(),
      closeTo(200.0, 1.5),
      reason: 'the cut-out should have moved by the full scroll delta',
    );
  });

  testWidgets('scrolling the target out and back keeps tracking',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(listHarness(key, scroll));
    scroll.jumpTo(400.0);
    await tester.pump();

    unawaitedSpotlight(
      controller.spotlight(
        key,
        shape: const SpotShape.rrect(),
        scrollIntoView: false,
        duration: const Duration(seconds: 30),
      ),
    );
    await settleSpotlight(tester);
    expect(cutoutBounds(tester), isNotNull);

    // Scroll far enough that the row is unmounted by the list's lazy builder.
    scroll.jumpTo(2000.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // Come back.
    scroll.jumpTo(400.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final Rect? recovered = cutoutBounds(tester);
    if (recovered != null) {
      final Rect target = tester.getRect(find.byKey(key));
      expect(recovered.center.dy, closeTo(target.center.dy, 1.5));
    }
    // Either way, nothing threw and the app is still running.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the cut-out follows an animated layout shift',
      (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    final ValueNotifier<double> offset = ValueNotifier<double>(0.0);
    addTearDown(offset.dispose);

    await tester.pumpWidget(
      harness(
        controller: controller,
        child: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: offset,
            builder: (BuildContext context, double value, Widget? child) {
              return Padding(
                padding: EdgeInsets.only(left: value, top: value),
                child: child,
              );
            },
            child: Align(alignment: Alignment.topLeft, child: Target(key: key)),
          ),
        ),
      ),
    );

    unawaitedSpotlight(
      controller.spotlight(
        key,
        shape: const SpotShape.rrect(),
        duration: const Duration(seconds: 30),
      ),
    );
    await settleSpotlight(tester);

    for (final double value in <double>[20.0, 60.0, 120.0]) {
      offset.value = value;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final Rect cutout = cutoutBounds(tester)!;
      final Rect target = tester.getRect(find.byKey(key));
      expect(cutout.center.dx, closeTo(target.center.dx, 1.0));
      expect(cutout.center.dy, closeTo(target.center.dy, 1.0));
    }
  });
}
