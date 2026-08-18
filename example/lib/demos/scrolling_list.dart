import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

import '../main.dart';

/// Use case 4: highlight something buried in a long settings list.
class ScrollingListDemo extends StatefulWidget {
  /// Creates the demo.
  const ScrollingListDemo({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  State<ScrollingListDemo> createState() => _ScrollingListDemoState();
}

class _ScrollingListDemoState extends State<ScrollingListDemo> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _buriedKey = GlobalKey();
  static const int _buriedIndex = 28;

  static const List<(IconData, String)> _settings = <(IconData, String)>[
    (Icons.wifi_rounded, 'Wi-Fi'),
    (Icons.bluetooth_rounded, 'Bluetooth'),
    (Icons.notifications_rounded, 'Notifications'),
    (Icons.volume_up_rounded, 'Sound & haptics'),
    (Icons.lock_rounded, 'Privacy & security'),
    (Icons.account_circle_rounded, 'Account'),
    (Icons.cloud_rounded, 'Backup & sync'),
    (Icons.language_rounded, 'Language & region'),
    (Icons.battery_full_rounded, 'Battery'),
    (Icons.storage_rounded, 'Storage'),
    (Icons.accessibility_rounded, 'Accessibility'),
    (Icons.keyboard_rounded, 'Keyboard'),
    (Icons.print_rounded, 'Printing'),
    (Icons.location_on_rounded, 'Location'),
    (Icons.update_rounded, 'Software update'),
  ];

  (IconData, String) _settingFor(int index) =>
      _settings[index % _settings.length];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Scrolling list',
      subtitle: 'Auto scroll-into-view, then drift-free tracking.',
      // A non-lazy scroll view, like a real settings screen: every row is
      // built even when off-screen. Auto scroll-into-view needs the target's
      // BuildContext to exist — a lazy ListView.builder never builds rows this
      // far below the fold, leaving the GlobalKey unresolvable.
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          children: <Widget>[
            for (int index = 0; index < 60; index++)
              if (index == _buriedIndex)
                ListTile(
                  key: _buriedKey,
                  leading: const Icon(Icons.dark_mode_rounded),
                  title: const Text('Dark mode'),
                  subtitle: const Text('The setting we want the user to find'),
                )
              else
                ListTile(
                  leading: Icon(_settingFor(index).$1),
                  title: Text(_settingFor(index).$2),
                ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () {
            _scroll.jumpTo(0.0);
            widget.keyspot.spotlight(
              _buriedKey,
              // One bold "found it" band, calmly pulsing.
              rings: const <RingStyle>[
                RingStyle(
                  color: Color(0xFF3949AB),
                  width: 7.0,
                  pulse: RingPulse(
                    minOpacity: 0.55,
                    maxOpacity: 1.0,
                    period: Duration(milliseconds: 900),
                  ),
                ),
              ],
              barrier: const SpotBarrier.dismissOnTap(),
              duration: const Duration(seconds: 30),
            );
          },
          child: const Text('Find "Dark mode" from the top'),
        ),
        OutlinedButton(
          onPressed: () => widget.keyspot.spotlight(
            _buriedKey,
            scrollIntoView: false,
            // Thin cyan-on-black tracer rings suit "watch it track".
            rings: const <RingStyle>[
              RingStyle(color: Color(0xFF00BCD4), width: 2.5),
              RingStyle(color: Color(0xFF006064), width: 2.5, gap: 4.0),
            ],
            barrier: const SpotBarrier.passthrough(),
            duration: const Duration(seconds: 30),
          ),
          child: const Text('Track it while you scroll'),
        ),
      ],
    );
  }
}
