import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

import '../main.dart';

/// The money demo: a target that never stops moving, with the spotlight glued
/// to it. A one-shot `localToGlobal` snapshot falls apart here immediately.
class DriftTortureTestDemo extends StatefulWidget {
  /// Creates the demo.
  const DriftTortureTestDemo({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  State<DriftTortureTestDemo> createState() => _DriftTortureTestDemoState();
}

class _DriftTortureTestDemoState extends State<DriftTortureTestDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  final GlobalKey _movingKey = GlobalKey();
  bool _resizing = true;

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Drift torture test',
      subtitle: 'Orbiting, rotating, resizing — the overlays stay glued.',
      body: AnimatedBuilder(
        animation: _orbit,
        builder: (BuildContext context, Widget? child) {
          final double t = _orbit.value * 2 * math.pi;
          final double scale = _resizing ? 1.0 + 0.35 * math.sin(t * 1.7) : 1.0;
          return Center(
            child: SizedBox(
              width: 320.0,
              height: 320.0,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Transform.translate(
                    offset: Offset(110.0 * math.cos(t), 110.0 * math.sin(t)),
                    child: Transform.rotate(
                      angle: t,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          key: _movingKey,
          width: 96.0,
          height: 64.0,
          decoration: BoxDecoration(
            color: Colors.pinkAccent,
            borderRadius: BorderRadius.circular(16.0),
          ),
          alignment: Alignment.center,
          child: const Text('Catch me!', style: TextStyle(color: Colors.white)),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => widget.keyspot.spotlight(
            _movingKey,
            shape: const SpotShape.rrect(radius: 16.0),
            // Hot pink to match the fugitive, white rim for contrast on the
            // dim while it flies over anything.
            rings: const <RingStyle>[
              RingStyle(color: Color(0xFFFF4081), width: 5.0),
              RingStyle(
                color: Color(0xFFFFFFFF),
                width: 2.0,
                gap: 4.0,
                pulse: RingPulse(
                  minOpacity: 0.4,
                  maxOpacity: 1.0,
                  period: Duration(milliseconds: 500),
                ),
              ),
            ],
            barrier: const SpotBarrier.dismissOnTap(),
            duration: const Duration(minutes: 5),
          ),
          child: const Text('Spotlight the moving target'),
        ),
        FilledButton.tonal(
          onPressed: () => widget.keyspot.pointer.show(_movingKey.anchor()),
          child: const Text('Pin the pointer on it'),
        ),
        OutlinedButton(
          onPressed: () => setState(() => _resizing = !_resizing),
          child: Text(_resizing ? 'Stop the resizing' : 'Resize it too'),
        ),
        TextButton(
          onPressed: () {
            widget.keyspot.hideSpotlight();
            widget.keyspot.pointer.hide();
          },
          child: const Text('Clear overlays'),
        ),
      ],
    );
  }
}
