import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

import '../main.dart';

/// Drive every pointer call by hand and watch the timings.
class PointerPlaygroundDemo extends StatefulWidget {
  /// Creates the demo.
  const PointerPlaygroundDemo({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  State<PointerPlaygroundDemo> createState() => _PointerPlaygroundDemoState();
}

class _PointerPlaygroundDemoState extends State<PointerPlaygroundDemo> {
  final GlobalKey _a = GlobalKey();
  final GlobalKey _b = GlobalKey();
  final GlobalKey _c = GlobalKey();

  double _durationMs = 800.0;
  double _degrees = 0.0;
  double _arcHeight = 0.0;
  bool _useArc = false;
  String _status = 'Idle — press "Show at A" to begin.';

  KeyspotPointer get _pointer => widget.keyspot.pointer;

  MotionPath get _path =>
      _useArc ? MotionPath.arc(height: _arcHeight) : MotionPath.line;

  Duration get _duration => Duration(milliseconds: _durationMs.round());

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _status = '$label…');
    final Stopwatch watch = Stopwatch()..start();
    await action();
    watch.stop();
    if (mounted) {
      setState(() => _status = '$label · ${watch.elapsedMilliseconds} ms · '
          'phase: ${_pointer.phase.name}');
    }
  }

  Widget _dot(GlobalKey key, String label, Color color) {
    return Container(
      key: key,
      width: 64.0,
      height: 64.0,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Pointer playground',
      subtitle: 'Every pointer call, driven by hand.',
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned(
                    left: 32.0, top: 32.0, child: _dot(_a, 'A', Colors.teal)),
                Positioned(
                    right: 32.0,
                    top: 120.0,
                    child: _dot(_b, 'B', Colors.indigo)),
                Positioned(
                  left: 0.0,
                  right: 0.0,
                  bottom: 24.0,
                  child: Center(child: _dot(_c, 'C', Colors.deepOrange)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: <Widget>[
                Text(_status, style: Theme.of(context).textTheme.bodySmall),
                _slider('Duration (ms)', _durationMs, 100.0, 3000.0,
                    (double v) => setState(() => _durationMs = v)),
                _slider('Rotation (°)', _degrees, -180.0, 180.0,
                    (double v) => setState(() => _degrees = v)),
                Row(
                  children: <Widget>[
                    Switch(
                      value: _useArc,
                      onChanged: (bool v) => setState(() => _useArc = v),
                    ),
                    const Text('Arc'),
                    Expanded(
                      child: Slider(
                        value: _arcHeight,
                        min: -0.6,
                        max: 0.6,
                        onChanged: _useArc
                            ? (double v) => setState(() => _arcHeight = v)
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => _run(
            'Show at A',
            () => _pointer.show(_a.anchor(),
                rotation: Rotation.degrees(_degrees)),
          ),
          child: const Text('Show at A'),
        ),
        FilledButton.tonal(
          onPressed: () => _run(
            'Glide to B',
            () => _pointer.moveTo(
              _b.anchor(),
              duration: _duration,
              path: _path,
              rotation: Rotation.degrees(_degrees),
            ),
          ),
          child: const Text('Glide to B'),
        ),
        FilledButton.tonal(
          onPressed: () => _run(
            'Glide to C',
            () => _pointer.moveTo(
              _c.anchor(),
              duration: _duration,
              path: _path,
              rotation: Rotation.degrees(_degrees),
            ),
          ),
          child: const Text('Glide to C'),
        ),
        OutlinedButton(
          onPressed: () =>
              _run('Tap pulse ×2', () => _pointer.tapPulse(count: 2)),
          child: const Text('Tap pulse ×2'),
        ),
        OutlinedButton(
          onPressed: () => _run(
            'Sweep A → C',
            () => _pointer.sweep(
              _a.anchor(),
              _c.anchor(),
              duration: _duration,
              path: _path,
              tapOnArrival: true,
            ),
          ),
          child: const Text('Sweep A → C'),
        ),
        TextButton(
          onPressed: () => _run('Hide pointer', _pointer.hide),
          child: const Text('Hide pointer'),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(width: 118.0, child: Text('$label · ${value.round()}')),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
