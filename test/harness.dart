import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

/// A theme with short, non-pulsing animations.
///
/// Ring pulses repeat forever, which makes `pumpAndSettle` hang; tests pump
/// explicit durations instead and use this theme so the numbers stay readable.
const KeyspotTheme testTheme = KeyspotTheme(
  rings: <RingStyle>[
    RingStyle(
      color: Color(0xFFFFFFFF),
      width: 6.0,
      pulse: RingPulse.none(),
    ),
  ],
  entryDuration: Duration(milliseconds: 300),
  exitDuration: Duration(milliseconds: 100),
  defaultSpotlightDuration: Duration(seconds: 2),
);

/// Wraps [child] in a `MaterialApp` and a [KeyspotScope].
Widget harness({
  required KeyspotController controller,
  required Widget child,
  KeyspotTheme theme = testTheme,
  TextDirection textDirection = TextDirection.ltr,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: textDirection,
      child: Builder(
        builder: (BuildContext context) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations),
            child: KeyspotScope(
              controller: controller,
              theme: theme,
              child: child,
            ),
          );
        },
      ),
    ),
  );
}

/// Pumps far enough for a freshly requested spotlight to finish appearing.
Future<void> settleSpotlight(
  WidgetTester tester, {
  Duration entry = const Duration(milliseconds: 300),
}) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(entry + const Duration(milliseconds: 50));
}

/// The live [SpotlightPainter], or null when no spotlight is on screen.
SpotlightPainter? spotlightPainter(WidgetTester tester) {
  final Finder finder = find.byWidgetPredicate(
    (Widget widget) =>
        widget is CustomPaint && widget.painter is SpotlightPainter,
  );
  if (finder.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<CustomPaint>(finder.first).painter! as SpotlightPainter;
}

/// The bounding box of the current cut-out, or null when nothing is painted.
Rect? cutoutBounds(WidgetTester tester) =>
    spotlightPainter(tester)?.cutout?.getBounds();

/// A plain sized box carrying [key], for use as a spotlight target.
class Target extends StatelessWidget {
  /// Creates a target box.
  const Target({
    super.key,
    this.width = 80.0,
    this.height = 40.0,
    this.onTap,
    this.label = 'target',
  });

  /// The box width.
  final double width;

  /// The box height.
  final double height;

  /// Called when the box is tapped.
  final VoidCallback? onTap;

  /// Debug label.
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF2196F3),
        alignment: Alignment.center,
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Starts a spotlight without awaiting it, which is what tests almost always
/// want: the future does not complete until the spotlight is dismissed.
void unawaitedSpotlight(Future<SpotlightOutcome> future) {
  future.ignore();
}
