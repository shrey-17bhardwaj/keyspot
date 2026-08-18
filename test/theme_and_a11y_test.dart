import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

import 'harness.dart';

void main() {
  late KeyspotController controller;

  setUp(() => controller = KeyspotController());
  tearDown(() => controller.dispose());

  group('theme resolution', () {
    testWidgets('an explicit scope theme wins over the ThemeExtension',
        (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              KeyspotTheme(barrierOpacity: 0.1, rings: <RingStyle>[]),
            ],
          ),
          home: KeyspotScope(
            controller: controller,
            theme: const KeyspotTheme(
              barrierOpacity: 0.9,
              rings: <RingStyle>[],
              entryDuration: Duration(milliseconds: 100),
            ),
            child: Scaffold(body: Center(child: Target(key: key))),
          ),
        ),
      );

      unawaitedSpotlight(
        controller.spotlight(key, duration: const Duration(seconds: 30)),
      );
      await settleSpotlight(tester, entry: const Duration(milliseconds: 100));

      expect(spotlightPainter(tester)!.barrierOpacity, closeTo(0.9, 0.01));
    });

    testWidgets('the ThemeExtension is used when the scope has no theme',
        (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              KeyspotTheme(
                barrierOpacity: 0.25,
                rings: <RingStyle>[],
                entryDuration: Duration(milliseconds: 100),
              ),
            ],
          ),
          home: KeyspotScope(
            controller: controller,
            child: Scaffold(body: Center(child: Target(key: key))),
          ),
        ),
      );

      unawaitedSpotlight(
        controller.spotlight(key, duration: const Duration(seconds: 30)),
      );
      await settleSpotlight(tester, entry: const Duration(milliseconds: 100));

      expect(spotlightPainter(tester)!.barrierOpacity, closeTo(0.25, 0.01));
    });

    testWidgets('an explicit rings argument beats the theme',
        (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        harness(
          controller: controller,
          child: Scaffold(body: Center(child: Target(key: key))),
        ),
      );

      unawaitedSpotlight(
        controller.spotlight(
          key,
          rings: const <RingStyle>[],
          duration: const Duration(seconds: 30),
        ),
      );
      await settleSpotlight(tester);

      expect(spotlightPainter(tester)!.rings, isEmpty);
    });

    test('KeyspotTheme lerps its fields', () {
      const KeyspotTheme a = KeyspotTheme(barrierOpacity: 0.0);
      const KeyspotTheme b = KeyspotTheme(barrierOpacity: 1.0);
      final KeyspotTheme mid = a.lerp(b, 0.5);
      expect(mid.barrierOpacity, closeTo(0.5, 1e-9));
    });

    test('KeyspotTheme copyWith preserves untouched fields', () {
      const KeyspotTheme base = KeyspotTheme(barrierOpacity: 0.42);
      expect(base.copyWith().barrierOpacity, 0.42);
      expect(base.copyWith(barrierOpacity: 0.1).barrierOpacity, 0.1);
      expect(base.copyWith(barrierOpacity: 0.1).rings, base.rings);
    });
  });

  group('accessibility', () {
    testWidgets('reduced motion skips the entry animation',
        (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        harness(
          controller: controller,
          disableAnimations: true,
          theme: const KeyspotTheme(
            entryDuration: Duration(seconds: 5),
            rings: <RingStyle>[],
          ),
          child: Scaffold(body: Center(child: Target(key: key))),
        ),
      );

      unawaitedSpotlight(
        controller.spotlight(
          key,
          shape: const SpotShape.rrect(),
          duration: const Duration(seconds: 30),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Without the short-circuit the cut-out would still be scaled to nothing.
      final Rect? cutout = cutoutBounds(tester);
      expect(cutout, isNotNull);
      final Rect target = tester.getRect(find.byKey(key));
      expect(cutout!.width, closeTo(target.width + 24.0, 1.0));
    });

    testWidgets('a semantic label is announced', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      final List<String> announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        (Object? message) async {
          if (message is Map<Object?, Object?> &&
              message['type'] == 'announce') {
            final Object? data = message['data'];
            if (data is Map<Object?, Object?> && data['message'] is String) {
              announcements.add(data['message']! as String);
            }
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        );
      });

      await tester.pumpWidget(
        harness(
          controller: controller,
          child: Scaffold(body: Center(child: Target(key: key))),
        ),
      );

      unawaitedSpotlight(
        controller.spotlight(
          key,
          semanticLabel: 'Compose a message here',
          duration: const Duration(seconds: 30),
        ),
      );
      await settleSpotlight(tester);

      expect(announcements, contains('Compose a message here'));
    });

    testWidgets('RTL flips a directional anchor', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        harness(
          controller: controller,
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: Target(key: key, width: 200.0))),
        ),
      );

      await controller.pointer.show(
        Anchor.key(key, alignment: AlignmentDirectional.centerStart),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final Finder hand = find.byWidgetPredicate(
        (Widget widget) =>
            widget is CustomPaint && widget.painter is DefaultHandPainter,
      );
      expect(hand, findsOneWidget);

      final Rect target = tester.getRect(find.byKey(key));
      // centerStart in RTL is the right-hand edge.
      expect(tester.getCenter(hand).dx, greaterThan(target.center.dx));
    });
  });

  group('tracking modes', () {
    testWidgets('TrackingMode.once takes a single snapshot',
        (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      final ValueNotifier<double> shift = ValueNotifier<double>(0.0);
      addTearDown(shift.dispose);
      final List<Rect?> seen = <Rect?>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: <Widget>[
              ValueListenableBuilder<double>(
                valueListenable: shift,
                builder: (BuildContext context, double value, Widget? child) {
                  return Padding(
                    padding: EdgeInsets.only(top: value),
                    child: child,
                  );
                },
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Target(key: key),
                ),
              ),
              KeyspotAnchorTracker(
                targetKey: key,
                mode: TrackingMode.once,
                builder: (BuildContext context, Rect? rect) {
                  seen.add(rect);
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final Rect? first = seen.last;
      expect(first, isNotNull);

      shift.value = 150.0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(seen.last, first, reason: 'once must not re-measure');
    });

    testWidgets('TrackingMode.everyFrame follows a moving target',
        (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      final ValueNotifier<double> shift = ValueNotifier<double>(0.0);
      addTearDown(shift.dispose);
      Rect? latest;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: <Widget>[
              ValueListenableBuilder<double>(
                valueListenable: shift,
                builder: (BuildContext context, double value, Widget? child) {
                  return Padding(
                    padding: EdgeInsets.only(top: value),
                    child: child,
                  );
                },
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Target(key: key),
                ),
              ),
              KeyspotAnchorTracker(
                targetKey: key,
                builder: (BuildContext context, Rect? rect) {
                  latest = rect;
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final double before = latest!.top;

      shift.value = 150.0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(latest!.top, closeTo(before + 150.0, 1.0));
    });
  });
}
