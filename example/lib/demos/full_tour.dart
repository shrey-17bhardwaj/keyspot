import 'package:flutter/material.dart';
import 'package:keyspot/keyspot.dart';

/// Use case 1 and 7: a multi-step tour with content cards and navigation.
class FullTourDemo extends StatefulWidget {
  /// Creates the demo.
  const FullTourDemo({super.key, required this.keyspot});

  /// The shared controller.
  final KeyspotController keyspot;

  @override
  State<FullTourDemo> createState() => _FullTourDemoState();
}

class _FullTourDemoState extends State<FullTourDemo> {
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _starKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _navKey = GlobalKey();

  final InMemoryTourStorage _storage = InMemoryTourStorage();
  String _result = 'Tour not run yet.';

  Widget _card(
    BuildContext context,
    TourSession session,
    String title,
    String body,
  ) {
    return Card(
      elevation: 8.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8.0),
            Text(body),
            const SizedBox(height: 12.0),
            Row(
              children: <Widget>[
                Text('${session.index + 1} / ${session.stepCount}'),
                const Spacer(),
                TextButton(
                  onPressed: session.skip,
                  child: const Text('Skip'),
                ),
                if (!session.isFirst)
                  TextButton(
                    onPressed: session.previous,
                    child: const Text('Back'),
                  ),
                FilledButton(
                  onPressed: session.next,
                  child: Text(session.isLast ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // One accent per step: the changing ring colour doubles as a progress cue
  // and shows that rings are configurable per step, not just per tour.
  static const List<Color> _stepAccents = <Color>[
    Color(0xFF00ACC1), // search — cyan
    Color(0xFF7CB342), // filter — green
    Color(0xFFFFB300), // list — amber
    Color(0xFFF4511E), // star — deep orange
    Color(0xFFE91E63), // fab — pink
    Color(0xFF8E24AA), // profile — purple
    Color(0xFF3949AB), // nav — indigo
  ];

  KeyspotTour _buildTour() {
    int stepIndex = 0;
    KeyspotStep step(
      String id,
      GlobalKey key,
      String title,
      String body, {
      KeyspotContentPosition position = KeyspotContentPosition.auto,
      SpotShape shape = const SpotShape.auto(),
    }) {
      final Color accent = _stepAccents[stepIndex++ % _stepAccents.length];
      return KeyspotStep(
        id: id,
        targetKey: key,
        shape: shape,
        rings: <RingStyle>[
          RingStyle(color: accent, width: 5.0),
          RingStyle(
              color: accent.withValues(alpha: 0.35), width: 2.0, gap: 4.0),
        ],
        advance: StepAdvance.manual,
        contentPosition: position,
        semanticLabel: title,
        contentBuilder:
            (BuildContext context, Rect rect, TourSession session) =>
                _card(context, session, title, body),
      );
    }

    return KeyspotTour(
      id: 'demo-tour',
      storage: _storage,
      steps: <KeyspotStep>[
        step('search', _searchKey, 'Search',
            'Find anything by name, tag or date.'),
        step('filter', _filterKey, 'Filters',
            'Narrow the list down without losing your search.'),
        step('list', _listKey, 'Your items',
            'Everything lives here. Scroll for more.'),
        step('star', _starKey, 'Favourites',
            'Star an item to pin it to the top.'),
        step('fab', _fabKey, 'Create',
            'Add a new item. This is the one people miss.'),
        step('profile', _profileKey, 'Your profile',
            'Settings, theme and sign-out live behind here.'),
        step('nav', _navKey, 'Navigation',
            'Switch sections. That is the whole tour.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Full tour'),
        actions: <Widget>[
          IconButton(
            key: _profileKey,
            onPressed: () {},
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: _fabKey,
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        key: _navKey,
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder), label: 'Files'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: SearchBar(
                    key: _searchKey,
                    hintText: 'Search',
                    leading: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(width: 12.0),
                IconButton.filledTonal(
                  key: _filterKey,
                  onPressed: () {},
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: Card(
                key: _listKey,
                child: ListView(
                  children: <Widget>[
                    ListTile(
                      leading: IconButton(
                        key: _starKey,
                        onPressed: () {},
                        icon: const Icon(Icons.star_border),
                      ),
                      title: const Text('Quarterly report'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.description),
                      title: Text('Design notes'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.description),
                      title: Text('Roadmap'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Text(_result, textAlign: TextAlign.center),
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton(
                  onPressed: () async {
                    final TourResult result =
                        await widget.keyspot.startTour(_buildTour());
                    if (mounted) {
                      setState(() => _result = 'Tour ended: ${result.name}');
                    }
                  },
                  child: const Text('Start tour'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    // Storage remembers a completed tour; this forgets it.
                    setState(() =>
                        _result = 'Seen: ${_storage.seenTourIds.join(', ')} — '
                            'start again to see it skip.');
                  },
                  child: const Text('What has been seen?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
