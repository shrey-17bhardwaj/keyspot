import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

import '../main.dart';

/// Use case 1 and 5: a first-run highlight and a feature announcement.
class BasicSpotlightDemo extends StatefulWidget {
  /// Creates the demo.
  const BasicSpotlightDemo({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  State<BasicSpotlightDemo> createState() => _BasicSpotlightDemoState();
}

class _BasicSpotlightDemoState extends State<BasicSpotlightDemo> {
  final GlobalKey _inboxKey = GlobalKey();
  final GlobalKey _composeKey = GlobalKey();
  String _log = 'Nothing yet.';

  Future<void> _fakeNarration() async {
    await Future<void>.delayed(const Duration(seconds: 3));
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Basic spotlight',
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              key: _inboxKey,
              child: const ListTile(
                leading: Icon(Icons.inbox),
                title: Text('Inbox'),
                subtitle: Text('12 unread'),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton.extended(
                key: _composeKey,
                onPressed: () => setState(() => _log = 'Compose tapped!'),
                icon: const Icon(Icons.edit),
                label: const Text('Compose'),
              ),
            ),
            const SizedBox(height: 24.0),
            Text(_log, textAlign: TextAlign.center),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          // No rings argument: this one shows the theme default on purpose.
          onPressed: () => widget.keyspot.spotlight(_inboxKey),
          child: const Text('Spotlight inbox (2s)'),
        ),
        FilledButton.tonal(
          onPressed: () => widget.keyspot.spotlight(
            _composeKey,
            // A feature announcement wants warmth: amber glow + thin white rim.
            rings: const <RingStyle>[
              RingStyle(color: Color(0xFFFFB300), width: 6.0),
              RingStyle(color: Color(0xFFFFFFFF), width: 1.5, gap: 5.0),
            ],
            barrier: const SpotBarrier.dismissOnTap(),
            duration: const Duration(seconds: 30),
            semanticLabel: 'Compose button',
          ),
          child: const Text('Tap anywhere to dismiss'),
        ),
        FilledButton.tonal(
          onPressed: () async {
            setState(() => _log = 'Narrating…');
            await widget.keyspot.spotlight(
              _composeKey,
              // A slow lavender breath while the narration plays.
              rings: const <RingStyle>[
                RingStyle(
                  color: Color(0xFFB39DDB),
                  width: 8.0,
                  pulse: RingPulse(
                    minOpacity: 0.25,
                    maxOpacity: 0.9,
                    period: Duration(milliseconds: 1200),
                  ),
                ),
              ],
              until: _fakeNarration,
            );
            if (mounted) {
              setState(() => _log = 'Narration finished, spotlight released.');
            }
          },
          child: const Text('Hold until an action finishes'),
        ),
        OutlinedButton(
          onPressed: () => widget.keyspot.spotlight(
            _composeKey,
            // "Do this" is an urgent fast green pulse.
            rings: const <RingStyle>[
              RingStyle(
                color: Color(0xFF00E676),
                width: 4.0,
                pulse: RingPulse(
                  minOpacity: 0.3,
                  maxOpacity: 1.0,
                  period: Duration(milliseconds: 350),
                ),
              ),
              RingStyle(color: Color(0xFF1B5E20), width: 2.0, gap: 4.0),
            ],
            barrier: SpotBarrier.targetOnly(
              onTargetTap: () => setState(() => _log = 'You did the thing.'),
            ),
            duration: const Duration(seconds: 60),
          ),
          child: const Text('You must tap the button'),
        ),
      ],
    );
  }
}
