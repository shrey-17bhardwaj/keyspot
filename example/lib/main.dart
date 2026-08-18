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
      title: 'Keyspot demos',
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
    required this.color,
    required this.builder,
  });

  /// Card title.
  final String title;

  /// One-line description.
  final String blurb;

  /// Card icon.
  final IconData icon;

  /// Accent colour for the card's icon chip.
  final Color color;

  /// Builds the demo page.
  final Widget Function(KeyspotController keyspot) builder;
}

/// The list of demos shown on the home screen.
List<Demo> buildDemos() => const <Demo>[
      Demo(
        title: 'Basic spotlight',
        blurb: 'Dim the screen, highlight a widget, choose how it dismisses.',
        icon: Icons.highlight_rounded,
        color: Color(0xFFF9A825),
        builder: _basicSpotlight,
      ),
      Demo(
        title: 'Shapes gallery',
        blurb: 'Auto-detected outlines, forced shapes, and custom paths.',
        icon: Icons.category_rounded,
        color: Color(0xFF7B1FA2),
        builder: _shapesGallery,
      ),
      Demo(
        title: 'Pointer playground',
        blurb: 'Drive the hand yourself — glide, rotate, arc and pulse.',
        icon: Icons.pan_tool_alt_rounded,
        color: Color(0xFF00838F),
        builder: _pointerPlayground,
      ),
      Demo(
        title: 'Scrolling list',
        blurb: 'Find a buried row, then watch the spotlight track your scroll.',
        icon: Icons.format_list_bulleted_rounded,
        color: Color(0xFF3949AB),
        builder: _scrollingList,
      ),
      Demo(
        title: 'Drift torture test',
        blurb: 'A target that never sits still. The spotlight keeps up.',
        icon: Icons.motion_photos_on_rounded,
        color: Color(0xFFD81B60),
        builder: _driftTorture,
      ),
      Demo(
        title: 'Full tour',
        blurb: 'Seven guided steps with cards, back, skip and memory.',
        icon: Icons.route_rounded,
        color: Color(0xFF43A047),
        builder: _fullTour,
      ),
      Demo(
        title: 'Gesture teaching',
        blurb: 'Show a drag and a pinch with the animated hand.',
        icon: Icons.gesture_rounded,
        color: Color(0xFFF4511E),
        builder: _gestureTeaching,
      ),
      Demo(
        title: 'Theming',
        blurb: 'Neon rings, bare spotlights, emoji and cursor pointers.',
        icon: Icons.palette_rounded,
        color: Color(0xFF5E35B1),
        builder: _theming,
      ),
    ];

// Top-level builder functions keep the Demo list const-constructible.
Widget _basicSpotlight(KeyspotController k) => BasicSpotlightDemo(keyspot: k);
Widget _shapesGallery(KeyspotController k) => ShapesGalleryDemo(keyspot: k);
Widget _pointerPlayground(KeyspotController k) =>
    PointerPlaygroundDemo(keyspot: k);
Widget _scrollingList(KeyspotController k) => ScrollingListDemo(keyspot: k);
Widget _driftTorture(KeyspotController k) => DriftTortureTestDemo(keyspot: k);
Widget _fullTour(KeyspotController k) => FullTourDemo(keyspot: k);
Widget _gestureTeaching(KeyspotController k) => GestureTeachingDemo(keyspot: k);
Widget _theming(KeyspotController k) => ThemingDemo(keyspot: k);

/// The home screen: a branded header plus the demo cards.
///
/// Lays out as a single-column list on phones and a grid on wider screens.
class HomePage extends StatelessWidget {
  /// Creates the home page.
  const HomePage({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  void _open(BuildContext context, Demo demo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => demo.builder(keyspot)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Demo> demos = buildDemos();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 640.0;
            final EdgeInsets pagePadding = EdgeInsets.symmetric(
              horizontal: compact ? 16.0 : 32.0,
            );

            return CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: pagePadding.copyWith(top: compact ? 24.0 : 48.0),
                  sliver: SliverToBoxAdapter(child: _Header(compact: compact)),
                ),
                SliverPadding(
                  padding: pagePadding.copyWith(top: 24.0, bottom: 32.0),
                  sliver: compact
                      ? SliverList.separated(
                          itemCount: demos.length,
                          separatorBuilder: (_, int __) =>
                              const SizedBox(height: 10.0),
                          itemBuilder: (BuildContext context, int index) =>
                              _DemoCard(
                            demo: demos[index],
                            compact: true,
                            onTap: () => _open(context, demos[index]),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320.0,
                            mainAxisExtent: 172.0,
                            mainAxisSpacing: 14.0,
                            crossAxisSpacing: 14.0,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) => _DemoCard(
                              demo: demos[index],
                              compact: false,
                              onTap: () => _open(context, demos[index]),
                            ),
                            childCount: demos.length,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 44.0,
              height: 44.0,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: Icon(Icons.center_focus_strong_rounded,
                  color: scheme.onPrimary, size: 26.0),
            ),
            const SizedBox(width: 14.0),
            Text(
              'Keyspot',
              style: (compact
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.displaySmall)
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Text(
          'Spotlights and guided hand gestures for Flutter — anchored to a '
          'GlobalKey, tracked live, never drifting.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: const <Widget>[
            _FeatureChip(
                icon: Icons.my_location_rounded, label: 'Drift-free tracking'),
            _FeatureChip(
                icon: Icons.swipe_rounded, label: 'Gesture choreography'),
            _FeatureChip(
                icon: Icons.inventory_2_outlined, label: 'Zero dependencies'),
          ],
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16.0, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.demo,
    required this.compact,
    required this.onTap,
  });

  final Demo demo;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final Widget iconChip = Container(
      width: 44.0,
      height: 44.0,
      decoration: BoxDecoration(
        color: demo.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Icon(demo.icon, color: demo.color, size: 24.0),
    );

    final Widget title = Text(
      demo.title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    final Widget blurb = Text(
      demo.blurb,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style:
          theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );

    return Card(
      elevation: 0.0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: compact
              ? Row(
                  children: <Widget>[
                    iconChip,
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          title,
                          const SizedBox(height: 2.0),
                          blurb,
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.outline, size: 22.0),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        iconChip,
                        const Spacer(),
                        Icon(Icons.arrow_outward_rounded,
                            color: scheme.outline, size: 18.0),
                      ],
                    ),
                    const Spacer(),
                    title,
                    const SizedBox(height: 4.0),
                    blurb,
                  ],
                ),
        ),
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
    this.subtitle,
    this.actions = const <Widget>[],
  });

  /// App bar title.
  final String title;

  /// Optional one-line explanation shown under the app bar.
  final String? subtitle;

  /// Page body.
  final Widget body;

  /// Buttons rendered under the body.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: subtitle == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28.0),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0, right: 16.0, bottom: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: body),
          if (actions.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: SafeArea(
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
            ),
        ],
      ),
    );
  }
}
