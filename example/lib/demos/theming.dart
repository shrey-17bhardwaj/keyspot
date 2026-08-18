import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:keyspot/keyspot.dart';

import '../main.dart';

/// Rings, barriers, and the pointer wearing four different costumes.
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
  String _pointerLabel = 'No pointer shown yet — pick a costume below.';

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

  Future<void> _showPointer(
    String label,
    Alignment alignment,
    PointerStyle style,
  ) async {
    setState(() => _pointerLabel = label);
    await widget.keyspot.pointer
        .show(_targetKey.anchor(alignment), style: style);
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Theming',
      subtitle: 'Rings, barriers and custom pointer artwork.',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FilledButton.icon(
              key: _targetKey,
              onPressed: () {},
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Launch'),
            ),
            const SizedBox(height: 48.0),
            Text(
              _pointerLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
          child: const Text('Neon ring stack'),
        ),
        FilledButton.tonal(
          onPressed: () => widget.keyspot.spotlight(
            _targetKey,
            rings: const <RingStyle>[],
            barrier: const SpotBarrier.dismissOnTap(),
            duration: const Duration(seconds: 30),
          ),
          child: const Text('Spotlight with no rings'),
        ),
        OutlinedButton(
          onPressed: () => _showPointer(
            'The built-in hand — a CustomPainter, no assets.',
            Alignment.bottomCenter,
            const PointerStyle(),
          ),
          child: const Text('Built-in hand'),
        ),
        OutlinedButton(
          onPressed: () => _showPointer(
            'An emoji — any Text widget works.',
            Alignment.bottomCenter,
            const PointerStyle(
              builder: _emojiPointer,
              size: 48.0,
              hotspot: Alignment.topCenter,
            ),
          ),
          child: const Text('Emoji pointer'),
        ),
        OutlinedButton(
          onPressed: () => _showPointer(
            'An SVG via flutter_svg — the example\'s dependency, not keyspot\'s.',
            Alignment.centerRight,
            const PointerStyle(
              builder: _svgPointer,
              size: 40.0,
              hotspot: Alignment.topLeft,
            ),
          ),
          child: const Text('SVG cursor'),
        ),
        OutlinedButton(
          onPressed: () => _showPointer(
            'A self-animating widget — it pulses on its own clock while '
            'keyspot moves it. GIFs, Lottie and Rive work the same way.',
            Alignment.topCenter,
            const PointerStyle(
              builder: _reticlePointer,
              size: 56.0,
              hotspot: Alignment.center,
            ),
          ),
          child: const Text('Animated reticle'),
        ),
        TextButton(
          onPressed: () {
            widget.keyspot.pointer.hide();
            setState(
                () => _pointerLabel = 'No pointer shown — pick a costume.');
          },
          child: const Text('Hide pointer'),
        ),
      ],
    );
  }
}

Widget _emojiPointer(BuildContext context) {
  return const FittedBox(child: Text('👆'));
}

// A classic arrow cursor, drawn as inline SVG so the demo needs no asset file.
const String _cursorSvg = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M5 2 L19 12.5 L12.3 13.4 L15.6 20.4 L12.6 21.8 L9.4 14.7 L5 18 Z"
        fill="#1E293B" stroke="#FFFFFF" stroke-width="1.4"
        stroke-linejoin="round"/>
</svg>
''';

Widget _svgPointer(BuildContext context) {
  return SvgPicture.string(_cursorSvg);
}

Widget _reticlePointer(BuildContext context) {
  return const _PulsingReticle();
}

/// A target reticle that pulses forever on its own AnimationController,
/// proving that self-animating pointer artwork keeps playing while keyspot
/// glides it around.
class _PulsingReticle extends StatefulWidget {
  const _PulsingReticle();

  @override
  State<_PulsingReticle> createState() => _PulsingReticleState();
}

class _PulsingReticleState extends State<_PulsingReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color color = Color(0xFF3949AB);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? _) {
        final double t = _pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // An expanding, fading ring.
            Transform.scale(
              scale: 0.5 + 0.5 * t,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 1.0 - t),
                    width: 3.0,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            // A steady core dot.
            const DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: SizedBox(width: 12.0, height: 12.0),
            ),
          ],
        );
      },
    );
  }
}
