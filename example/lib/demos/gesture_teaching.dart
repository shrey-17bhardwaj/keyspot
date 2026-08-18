import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

import '../main.dart';

/// Use cases 2 and 3: teach a drag and a pinch, not just a location.
class GestureTeachingDemo extends StatefulWidget {
  /// Creates the demo.
  const GestureTeachingDemo({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  State<GestureTeachingDemo> createState() => _GestureTeachingDemoState();
}

class _GestureTeachingDemoState extends State<GestureTeachingDemo> {
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _archiveKey = GlobalKey();
  final GlobalKey _photoKey = GlobalKey();

  bool _archived = false;
  double _photoScale = 1.0;

  Future<void> _teachDrag() async {
    final KeyspotPointer pointer = widget.keyspot.pointer;
    await pointer.show(
      _cardKey.anchor(),
      rotation: const Rotation.degrees(-15),
    );
    await pointer.tapPulse();
    await pointer.moveTo(
      _archiveKey.anchor(),
      duration: const Duration(milliseconds: 1100),
      path: const MotionPath.arc(height: 0.28),
      rotation: const Rotation.degrees(10),
    );
    await pointer.tapPulse();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await pointer.hide();
  }

  Future<void> _teachPinch() async {
    await widget.keyspot.spotlight(
      _photoKey,
      shape: const SpotShape.rrect(radius: 20.0),
      // Echo the photo's cyan→purple gradient in the rings.
      rings: const <RingStyle>[
        RingStyle(color: Color(0xFF4DD0E1), width: 4.0),
        RingStyle(color: Color(0xFF7C4DFF), width: 4.0, gap: 5.0),
      ],
      barrier: const SpotBarrier.passthrough(),
      overlayBuilder: (BuildContext context, Rect rect) {
        return Stack(
          children: <Widget>[
            Positioned(
              left: rect.left,
              top: rect.bottom + 16.0,
              width: rect.width,
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Pinch to zoom. The overlay above is your widget, '
                    'positioned from the live cut-out rect.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      until: () async {
        // Two fingers sweeping apart, faked with two sequential glides.
        final KeyspotPointer pointer = widget.keyspot.pointer;
        await pointer.show(
          Anchor.key(_photoKey, alignment: Alignment.center),
          rotation: const Rotation.degrees(-30),
        );
        await pointer.moveTo(
          Anchor.key(_photoKey, alignment: Alignment.topLeft),
          duration: const Duration(milliseconds: 700),
        );
        await pointer.moveTo(
          Anchor.key(_photoKey, alignment: Alignment.center),
          duration: const Duration(milliseconds: 500),
        );
        await pointer.moveTo(
          Anchor.key(_photoKey, alignment: Alignment.bottomRight),
          duration: const Duration(milliseconds: 700),
          rotation: const Rotation.degrees(30),
        );
        await pointer.hide();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Gesture teaching',
      subtitle: 'Teach gestures, not just locations.',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 160.0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: Draggable<String>(
                      data: 'card',
                      feedback: const _DragCard(dragging: true),
                      childWhenDragging: const SizedBox.shrink(),
                      child: _DragCard(key: _cardKey, archived: _archived),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: DragTarget<String>(
                      key: _archiveKey,
                      onAcceptWithDetails: (_) =>
                          setState(() => _archived = true),
                      builder: (
                        BuildContext context,
                        List<String?> candidate,
                        List<dynamic> rejected,
                      ) {
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: candidate.isEmpty
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Colors.teal,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: const Center(child: Text('Archive')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            Expanded(
              child: GestureDetector(
                onScaleUpdate: (ScaleUpdateDetails details) => setState(
                  () => _photoScale = (details.scale).clamp(0.6, 2.5),
                ),
                child: Center(
                  child: Transform.scale(
                    scale: _photoScale,
                    child: Container(
                      key: _photoKey,
                      width: 200.0,
                      height: 140.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFF4DD0E1), Color(0xFF7C4DFF)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Pinch me',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: _teachDrag,
          child: const Text('Teach the drag'),
        ),
        FilledButton.tonal(
          onPressed: _teachPinch,
          child: const Text('Teach the pinch'),
        ),
        TextButton(
          onPressed: () => setState(() {
            _archived = false;
            _photoScale = 1.0;
          }),
          child: const Text('Reset demo'),
        ),
      ],
    );
  }
}

class _DragCard extends StatelessWidget {
  const _DragCard({super.key, this.dragging = false, this.archived = false});

  final bool dragging;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: archived ? Colors.green.shade700 : Colors.blueGrey.shade700,
      elevation: dragging ? 12.0 : 2.0,
      borderRadius: BorderRadius.circular(16.0),
      child: SizedBox(
        width: dragging ? 140.0 : null,
        height: dragging ? 100.0 : null,
        child: Center(
          child: Text(
            archived ? 'Archived' : 'Drag me',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
