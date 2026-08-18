import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

import 'demos/basic_spotlight.dart';
import 'demos/drift_torture_test.dart';
import 'demos/full_tour.dart';
import 'demos/gesture_teaching.dart';
import 'demos/pointer_playground.dart';
import 'demos/scrolling_list.dart';
import 'demos/shapes_gallery.dart';
import 'demos/theming.dart';

void main() => runApp(const KeyspotDemoApp());

/// The demo application.
class KeyspotDemoApp extends StatefulWidget {
  /// Creates the demo app.
  const KeyspotDemoApp({super.key});

  @override
  State<KeyspotDemoApp> createState() => _KeyspotDemoAppState();
}

class _KeyspotDemoAppState extends State<KeyspotDemoApp> {
  final KeyspotController _keyspot =
      KeyspotController(logger: KeyspotLoggers.debug);

  @override
  void dispose() {
    _keyspot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'keyspot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00838F),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      // Mounting the scope in `builder` keeps Theme, Directionality and
      // localisations available to step content cards.
      builder: (BuildContext context, Widget? child) {
        return KeyspotScope(
          controller: _keyspot,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomePage(keyspot: _keyspot),
    );
  }
}

/// A demo entry in the home grid.
class Demo {
  /// Creates a demo entry.
  const Demo({
    required this.title,
    required this.blurb,
    required this.icon,
    required this.builder,
  });

  /// Card title.
  final String title;

  /// One-line description.
  final String blurb;

  /// Card icon.
  final IconData icon;

  /// Builds the demo page.
  final Widget Function(KeyspotController keyspot) builder;
}

/// The grid of demos.
class HomePage extends StatelessWidget {
  /// Creates the home page.
  const HomePage({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  Widget build(BuildContext context) {
    final List<Demo> demos = <Demo>[
      Demo(
        title: 'Basic spotlight',
        blurb: 'Dim, cut out, dismiss. The 30-second version.',
        icon: Icons.highlight,
        builder: (KeyspotController k) => BasicSpotlightDemo(keyspot: k),
      ),
      Demo(
        title: 'Shapes gallery',
        blurb: 'auto, circle, rrect, stadium, custom path.',
        icon: Icons.category_outlined,
        builder: (KeyspotController k) => ShapesGalleryDemo(keyspot: k),
      ),
      Demo(
        title: 'Pointer playground',
        blurb: 'Drive show / moveTo / sweep / tapPulse by hand.',
        icon: Icons.pan_tool_alt_outlined,
        builder: (KeyspotController k) => PointerPlaygroundDemo(keyspot: k),
      ),
      Demo(
        title: 'Scrolling list',
        blurb: 'Auto scroll-into-view, then live tracking.',
        icon: Icons.list_alt,
        builder: (KeyspotController k) => ScrollingListDemo(keyspot: k),
      ),
      Demo(
        title: 'Drift torture test',
        blurb: 'A target that will not sit still. Watch it keep up.',
        icon: Icons.blur_on,
        builder: (KeyspotController k) => DriftTortureTestDemo(keyspot: k),
      ),
      Demo(
        title: 'Full tour',
        blurb: 'Seven steps, content cards, back and skip.',
        icon: Icons.route_outlined,
        builder: (KeyspotController k) => FullTourDemo(keyspot: k),
      ),
      Demo(
        title: 'Gesture teaching',
        blurb: 'Drag and pinch, taught with the hand pointer.',
        icon: Icons.gesture,
        builder: (KeyspotController k) => GestureTeachingDemo(keyspot: k),
      ),
      Demo(
        title: 'Theming',
        blurb: 'Rings, barrier, and a custom pointer widget.',
        icon: Icons.palette_outlined,
        builder: (KeyspotController k) => ThemingDemo(keyspot: k),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('keyspot'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28.0),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0, left: 16.0, right: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Spotlights and guided hand gestures, anchored to GlobalKeys.',
                style: TextStyle(fontSize: 12.0),
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns =
              (constraints.maxWidth / 260.0).floor().clamp(1, 4);
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12.0,
              crossAxisSpacing: 12.0,
              childAspectRatio: 1.5,
            ),
            itemCount: demos.length,
            itemBuilder: (BuildContext context, int index) {
              final Demo demo = demos[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => demo.builder(keyspot),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Icon(demo.icon, size: 28.0),
                        Text(
                          demo.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          demo.blurb,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Shared scaffold for the demo pages.
class DemoScaffold extends StatelessWidget {
  /// Creates a demo scaffold.
  const DemoScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
  });

  /// App bar title.
  final String title;

  /// Page body.
  final Widget body;

  /// Buttons rendered under the body.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: <Widget>[
          Expanded(child: body),
          if (actions.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
