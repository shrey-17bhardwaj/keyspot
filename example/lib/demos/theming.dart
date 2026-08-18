import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

import '../main.dart';

/// Rings, barrier and a completely custom pointer widget.
class ThemingDemo extends StatefulWidget {
  /// Creates the demo.
  const ThemingDemo({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  State<ThemingDemo> createState() => _ThemingDemoState();
}

class _ThemingDemoState extends State<ThemingDemo> {
  final GlobalKey _targetKey = GlobalKey();

  static const List<RingStyle> _neon = <RingStyle>[
    RingStyle(color: Color(0xFF00E5FF), width: 4.0),
    RingStyle(color: Color(0xFFFF4081), width: 3.0, gap: 6.0),
    RingStyle(
      color: Color(0xFFFFD740),
      width: 2.0,
      gap: 6.0,
      pulse: RingPulse(
          minOpacity: 0.0,
          maxOpacity: 1.0,
          period: Duration(milliseconds: 400)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Theming',
      body: Center(
        child: FilledButton.icon(
          key: _targetKey,
          onPressed: () {},
          icon: const Icon(Icons.rocket_launch),
          label: const Text('Launch'),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => widget.keyspot.spotlight(
            _targetKey,
            rings: _neon,
            barrier: const SpotBarrier.dismissOnTap(),
            duration: const Duration(seconds: 30),
          ),
          child: const Text('Neon rings'),
        ),
        FilledButton.tonal(
          onPressed: () => widget.keyspot.spotlight(
            _targetKey,
            rings: const <RingStyle>[],
            barrier: const SpotBarrier.dismissOnTap(),
            duration: const Duration(seconds: 30),
          ),
          child: const Text('No rings at all'),
        ),
        OutlinedButton(
          onPressed: () => widget.keyspot.pointer.show(
            _targetKey.anchor(Alignment.bottomCenter),
            style: const PointerStyle(
              builder: _emojiPointer,
              size: 48.0,
              hotspot: Alignment.topCenter,
              dotColor: Color(0xFFFFD740),
            ),
          ),
          child: const Text('Emoji pointer'),
        ),
        OutlinedButton(
          onPressed: () => widget.keyspot.pointer.show(
            _targetKey.anchor(Alignment.centerRight),
            style: const PointerStyle(
              builder: _cursorPointer,
              size: 32.0,
              hotspot: Alignment.topLeft,
              showGlowDot: false,
            ),
          ),
          child: const Text('Desktop cursor'),
        ),
        TextButton(
          onPressed: widget.keyspot.pointer.hide,
          child: const Text('Hide pointer'),
        ),
      ],
    );
  }
}

Widget _emojiPointer(BuildContext context) {
  return const FittedBox(child: Text('👆'));
}

Widget _cursorPointer(BuildContext context) {
  return const Icon(Icons.north_west, color: Colors.black87, size: 32.0);
}
