import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

import '../main.dart';

/// Every [SpotShape], side by side.
class ShapesGalleryDemo extends StatefulWidget {
  /// Creates the demo.
  const ShapesGalleryDemo({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  State<ShapesGalleryDemo> createState() => _ShapesGalleryDemoState();
}

class _ShapesGalleryDemoState extends State<ShapesGalleryDemo> {
  final GlobalKey _circleKey = GlobalKey();
  final GlobalKey _roundedKey = GlobalKey();
  final GlobalKey _pillKey = GlobalKey();
  final GlobalKey _plainKey = GlobalKey();

  // Each shape gets rings in its target's own accent, so the gallery doubles
  // as a ring-customisation gallery.
  Future<void> _show(GlobalKey key, SpotShape shape, List<RingStyle> rings) {
    return widget.keyspot.spotlight(
      key,
      shape: shape,
      rings: rings,
      barrier: const SpotBarrier.dismissOnTap(),
      duration: const Duration(seconds: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Shapes gallery',
      body: Center(
        child: Wrap(
          spacing: 24.0,
          runSpacing: 24.0,
          alignment: WrapAlignment.center,
          children: <Widget>[
            CircleAvatar(key: _circleKey, radius: 36.0, child: const Text('A')),
            Material(
              key: _roundedKey,
              color: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: const SizedBox(
                width: 140.0,
                height: 72.0,
                child: Center(child: Text('rounded 20')),
              ),
            ),
            Material(
              key: _pillKey,
              color: Colors.indigo,
              shape: const StadiumBorder(),
              child: const SizedBox(
                width: 160.0,
                height: 48.0,
                child: Center(child: Text('stadium')),
              ),
            ),
            Container(
              key: _plainKey,
              width: 180.0,
              height: 60.0,
              color: Colors.deepOrange,
              alignment: Alignment.center,
              child: const Text('plain box'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => _show(
            _circleKey,
            const SpotShape.auto(),
            const <RingStyle>[
              RingStyle(color: Color(0xFFFFC107), width: 5.0),
            ],
          ),
          child: const Text('auto → circle'),
        ),
        FilledButton(
          onPressed: () => _show(
            _roundedKey,
            const SpotShape.auto(),
            const <RingStyle>[
              RingStyle(color: Color(0xFF26A69A), width: 4.0),
              RingStyle(color: Color(0xFF80CBC4), width: 2.0, gap: 5.0),
            ],
          ),
          child: const Text('auto → mirrors radius 20'),
        ),
        FilledButton(
          onPressed: () => _show(
            _pillKey,
            const SpotShape.auto(),
            const <RingStyle>[
              RingStyle(color: Color(0xFF7986CB), width: 3.0),
              RingStyle(color: Color(0xFF3F51B5), width: 3.0, gap: 3.0),
              RingStyle(color: Color(0xFF1A237E), width: 3.0, gap: 3.0),
            ],
          ),
          child: const Text('auto → stadium'),
        ),
        FilledButton.tonal(
          onPressed: () => _show(
            _plainKey,
            const SpotShape.circle(),
            const <RingStyle>[
              RingStyle(
                color: Color(0xFFFF7043),
                width: 10.0,
                pulse: RingPulse(
                  minOpacity: 0.5,
                  maxOpacity: 1.0,
                  period: Duration(milliseconds: 800),
                ),
              ),
            ],
          ),
          child: const Text('forced circle'),
        ),
        FilledButton.tonal(
          onPressed: () => _show(
            _plainKey,
            const SpotShape.rrect(radius: 28.0),
            const <RingStyle>[
              RingStyle(color: Color(0xFFFFFFFF), width: 2.0),
              RingStyle(color: Color(0xFFFF5722), width: 6.0, gap: 4.0),
            ],
          ),
          child: const Text('rrect 28'),
        ),
        OutlinedButton(
          onPressed: () => _show(
            _plainKey,
            SpotShape.path((Rect rect) {
              // A diamond, to prove arbitrary outlines work.
              return Path()
                ..moveTo(rect.center.dx, rect.top)
                ..lineTo(rect.right, rect.center.dy)
                ..lineTo(rect.center.dx, rect.bottom)
                ..lineTo(rect.left, rect.center.dy)
                ..close();
            }),
            const <RingStyle>[
              RingStyle(
                color: Color(0xFFE91E63),
                width: 3.0,
                pulse: RingPulse(
                  minOpacity: 0.2,
                  maxOpacity: 1.0,
                  period: Duration(milliseconds: 500),
                ),
              ),
              RingStyle(color: Color(0xFFFFEB3B), width: 2.0, gap: 6.0),
            ],
          ),
          child: const Text('custom diamond path'),
        ),
      ],
    );
  }
}
