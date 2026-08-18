# keyspot

**Spotlights and guided hand gestures for Flutter — anchored to a GlobalKey, tracked live, never drifting.**

[![CI](https://github.com/shrey-17bhardwaj/keyspot/actions/workflows/ci.yml/badge.svg)](https://github.com/shrey-17bhardwaj/keyspot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> ⚠️ **Not yet published to pub.dev.** The 0.1–0.3 surface described below is
> implemented and tested; the API may still move before 1.0. See `SPEC.md` for
> the full design rationale.

**[▶ Try the live demo](https://shrey-17bhardwaj.github.io/keyspot/)** — all
eight showcase pages, built from `example/` on every push to `main`.

---

- [Why keyspot?](#why-keyspot)
- [Use cases](#use-cases)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Spotlights](#spotlights)
  - [Shapes](#shapes)
  - [Rings](#rings)
  - [Barriers](#barriers)
  - [Outcomes](#outcomes)
  - [Holding a spotlight open](#holding-a-spotlight-open)
  - [Scroll-into-view](#scroll-into-view)
- [The pointer](#the-pointer)
  - [Anchors](#anchors)
  - [Rotation and motion paths](#rotation-and-motion-paths)
  - [Custom pointer artwork](#custom-pointer-artwork)
- [Tours](#tours)
- [The tracker, on its own](#the-tracker-on-its-own)
- [Theming](#theming)
- [Lifecycle: resuming after an app switch](#lifecycle-resuming-after-an-app-switch)
- [Accessibility](#accessibility)
- [Hardening guarantees](#hardening-guarantees)
- [Logging](#logging)
- [Testing apps that use keyspot](#testing-apps-that-use-keyspot)
- [Running the demos](#running-the-demos)
- [Platforms](#platforms)
- [Roadmap](#roadmap)

## Why keyspot?

Every onboarding package can dim the screen and punch a hole over a widget.
Keyspot does two things the others don't:

1. **Drift-free tracking.** The spotlight and pointer re-resolve the target's
   geometry every frame, so they follow the widget through scrolling, keyboard
   insets, orientation changes, and window resizing — instead of painting a
   stale one-shot snapshot.
2. **Gesture choreography.** An animated hand pointer that appears, glides
   between targets, rotates, and pulses — teaching *gestures* ("drag this
   here"), not just *locations* ("look here").

Everything is driven by `GlobalKey`s. No coordinates, no manual measurement, no
wrapper widgets around every target. Zero runtime dependencies beyond Flutter
itself — the hand is a `CustomPainter`, not an asset.

## Use cases

Each row maps to a page in the [example app](example/lib/demos).

| Use case | What you reach for | Demo |
|---|---|---|
| First-run tour ("this is your inbox, this is compose") | `KeyspotTour` + step content cards | `full_tour` |
| Teach a gesture: "drag the card to the archive column" | `pointer.show` → `moveTo` with an arc path | `gesture_teaching` |
| Teach pinch/rotate on an image or map | spotlight + `overlayBuilder` + pointer choreography | `gesture_teaching` |
| Highlight a button inside a scrollable settings list | `scrollIntoView` + live tracking | `scrolling_list` |
| Feature announcement after an update | one-off spotlight with `SpotBarrier.dismissOnTap()` | `basic_spotlight` |
| Narrated step that holds while audio plays | `spotlight(until: playNarration)` | `basic_spotlight` |
| Walkthrough where the user must actually perform each step | `SpotBarrier.targetOnly()` / `StepAdvance.tapTarget` | `basic_spotlight`, `full_tour` |
| Desktop/web product tour with mouse users | `PointerStyle.builder` cursor swap, window-resize tracking | `theming`, `drift_torture_test` |

## Installation

Until the package is on pub.dev, depend on it straight from git:

```yaml
dependencies:
  keyspot:
    git:
      url: https://github.com/shrey-17bhardwaj/keyspot.git
```

Requires Dart ≥ 3.4 and Flutter ≥ 3.22.

## Quick start

```dart
final KeyspotController keyspot = KeyspotController();
final GlobalKey composeKey = GlobalKey();

// One wrapper, anywhere above your content.
KeyspotScope(
  controller: keyspot,
  child: MaterialApp(home: Inbox(composeKey: composeKey)),
);

// Highlight a widget for two seconds.
await keyspot.spotlight(composeKey);
```

That is the whole integration. `KeyspotScope` mounts the overlay layers itself —
you never place them by hand. Two placements work:

```dart
// 1. Above MaterialApp — covers every route, including root-navigator dialogs.
KeyspotScope(controller: keyspot, child: MaterialApp(home: HomePage()));

// 2. In MaterialApp.builder — inherits Theme, Directionality and localizations,
//    which is usually what you want for tour content cards.
MaterialApp(
  builder: (BuildContext context, Widget? child) => KeyspotScope(
    controller: keyspot,
    child: child ?? const SizedBox.shrink(),
  ),
);
```

Descendants can grab the controller without any state-management package:

```dart
final KeyspotController keyspot = KeyspotScope.of(context);
```

The controller's lifetime is yours — call `keyspot.dispose()` when you're done.

## Spotlights

```dart
await keyspot.spotlight(
  composeKey,
  shape: const SpotShape.auto(),      // mirrors the widget's own rounding
  padding: const EdgeInsets.all(12),
  barrier: const SpotBarrier.block(), // absorb stray taps (default)
  duration: const Duration(seconds: 4),
  semanticLabel: 'Compose button',    // announced to screen readers
);
```

Calling `spotlight()` while another spotlight is active cancels the old one
first — there are never two at once, and the old future completes (as
`cancelled`) rather than hanging.

### Shapes

`SpotShape.auto()` (the default) inspects the target's render tree for a clip,
physical shape or box decoration and mirrors its rounding; failing that it uses
a circle for square-ish targets and a 12px rounded rect for everything else.
When you want control:

```dart
const SpotShape.circle();             // circumscribes the target
const SpotShape.rrect(radius: 28);
const SpotShape.stadium();
SpotShape.path((Rect rect) => Path()  // any outline you can draw
  ..moveTo(rect.center.dx, rect.top)
  ..lineTo(rect.right, rect.center.dy)
  ..lineTo(rect.center.dx, rect.bottom)
  ..lineTo(rect.left, rect.center.dy)
  ..close());
```

### Rings

Rings are stacked outlines drawn around the cut-out, each with its own colour,
width, gap from the previous ring, and opacity pulse. Pass them per spotlight
call, per tour step, or set them once in the theme. Use them to give different
moments different voices:

```dart
// A feature announcement: warm amber glow with a thin white rim.
rings: const <RingStyle>[
  RingStyle(color: Color(0xFFFFB300), width: 6),
  RingStyle(color: Colors.white, width: 1.5, gap: 5),
],

// "Do this now": a fast, urgent pulse.
rings: const <RingStyle>[
  RingStyle(
    color: Color(0xFF00E676),
    width: 4,
    pulse: RingPulse(
      minOpacity: 0.3,
      maxOpacity: 1.0,
      period: Duration(milliseconds: 350),
    ),
  ),
],

// A calm breath while narration plays.
rings: const <RingStyle>[
  RingStyle(
    color: Color(0xFFB39DDB),
    width: 8,
    pulse: RingPulse(
      minOpacity: 0.25,
      maxOpacity: 0.9,
      period: Duration(milliseconds: 1200),
    ),
  ),
],

rings: const <RingStyle>[]   // no rings at all
// rings: null (default)     // use the theme's rings
```

`RingPulse.none()` freezes a ring at full opacity. The example app's
`shapes_gallery`, `basic_spotlight` and `full_tour` pages show a dozen
combinations.

### Barriers

This is the capability most packages skip:

| Barrier | Outside the cut-out | Inside the cut-out |
|---|---|---|
| `passthrough()` | taps pass through | taps pass through |
| `block()` *(default)* | absorbed | absorbed |
| `dismissOnTap()` | dismisses | absorbed |
| `dismissOnTap(outsideOnly: false)` | dismisses | dismisses |
| `targetOnly()` | absorbed | **reaches the real widget**, then resolves |

`targetOnly` is how you build "you must actually tap this" walkthroughs — the
underlying button's own `onPressed` still fires:

```dart
await keyspot.spotlight(
  composeKey,
  barrier: SpotBarrier.targetOnly(
    onTargetTap: () => analytics.log('onboarding_compose_tapped'),
  ),
);
```

### Outcomes

The future completes when the spotlight is dismissed and tells you why:

```dart
final SpotlightOutcome outcome =
    await keyspot.spotlight(key, barrier: const SpotBarrier.dismissOnTap());

switch (outcome) {
  case SpotlightOutcome.finished:        // duration elapsed or until() returned
  case SpotlightOutcome.dismissedByUser: // they tapped the barrier
  case SpotlightOutcome.targetTapped:    // they tapped the target (targetOnly)
  case SpotlightOutcome.cancelled:       // replaced, hidden, unresolvable, or disposed
}
```

### Holding a spotlight open

Three ways to control how long a spotlight lives:

```dart
// 1. A timer (default: the theme's defaultSpotlightDuration, 2s).
await keyspot.spotlight(key, duration: const Duration(seconds: 5));

// 2. Action-scoped: held for exactly as long as the future runs.
await keyspot.spotlight(key, until: () => audioPlayer.play(clip));

// 3. Programmatic dismissal from anywhere.
keyspot.hideSpotlight();
```

If `until` throws, the spotlight still resolves — an error in your callback
can't strand the user under a dimmed screen.

### Scroll-into-view

When the target sits inside a scrollable and is (partly) off-screen, the
spotlight scrolls it to center first (`scrollIntoView: true`, the default),
waits a frame, then measures. Live tracking makes this safe even if the scroll
settles slightly differently.

> **Lazy lists:** `scrollIntoView` needs the target widget to be *built*.
> `ListView.builder` does not build rows far below the fold, so their keys have
> no context to scroll to, and the spotlight completes with `cancelled`. Scroll
> near the target yourself first, or use a non-lazy scroll view
> (`SingleChildScrollView` + `Column`) for tour targets — see the
> `scrolling_list` demo.

## The pointer

```dart
await keyspot.pointer.show(cardKey.anchor());
await keyspot.pointer.moveTo(
  archiveKey.anchor(),
  duration: const Duration(milliseconds: 900),
  path: const MotionPath.arc(height: 0.3),   // bows, so it reads as a drag
  rotation: const Rotation.degrees(-15),
);
await keyspot.pointer.tapPulse(count: 2);
await keyspot.pointer.hide();

// Or the one-liner: show at A, glide to B, dwell, hide.
await keyspot.pointer.sweep(cardKey.anchor(), archiveKey.anchor());
```

Every future completes when its `AnimationController` completes — not after a
guessed delay. `show()` resolves as soon as the pointer is mounted at its
anchor (the entrance fade plays on its own), so you can chain a `moveTo`
immediately. A second `moveTo` mid-flight cancels the first smoothly; the
cancelled future still completes.

The pointer exposes its phase for styling and sequencing:

```dart
keyspot.pointer.phase;      // idle → moving → arrived
keyspot.pointer.isVisible;
```

The pointer is just the hand — no extra markers around it. `tapPulse` expands
a ripple ring from the hotspot; `PointerStyle.dotColor` sets its colour.

### Anchors

An `Anchor` is a point on (or relative to) a target widget:

```dart
cardKey.anchor()                          // center of the widget
cardKey.anchor(Alignment.bottomCenter)    // any Alignment, -1..1 convention
cardKey.anchor(AlignmentDirectional.centerStart)  // RTL-aware
const Anchor.offset(Offset(120, 480))     // escape hatch: fixed screen point
```

Keyed anchors re-resolve every frame, so a pointer parked on a widget follows
it through scrolls and layout changes.

### Rotation and motion paths

Rotation is an explicit value type — no degrees-vs-radians guessing:

```dart
const Rotation.degrees(-95);
const Rotation.radians(math.pi / 4);
const Rotation.none();
```

Rotations animate from the current angle along the shortest path, so the hand
never snaps back through zero. `MotionPath.line` is the default trajectory;
`MotionPath.arc(height: 0.3)` bows the glide sideways — arcs sell "drag"
gestures far better than straight lines.

### Custom pointer artwork

The built-in hand is only the default. `PointerStyle.builder` is a plain
`WidgetBuilder`, so **any widget can be the pointer** — an emoji, a PNG, an
animated GIF, an SVG, a Lottie or Rive animation, or a widget you animate
yourself:

```dart
// An emoji hand.
PointerStyle(
  builder: (BuildContext context) => const FittedBox(child: Text('👆')),
  size: 48,
  hotspot: Alignment.topCenter,   // which point of the artwork sits on the anchor
)

// A desktop cursor for web/desktop tours.
PointerStyle(
  builder: (BuildContext context) =>
      const Icon(Icons.north_west, size: 32, color: Colors.black87),
  size: 32,
  hotspot: Alignment.topLeft,
)

// A PNG or an animated GIF — Image plays GIFs natively, no extra package.
PointerStyle(
  builder: (BuildContext context) => Image.asset('assets/pointing_hand.gif'),
  size: 64,
)

// An SVG via flutter_svg, or an animation via lottie / rive —
// your widget, your dependency; keyspot itself depends on nothing.
PointerStyle(
  builder: (BuildContext context) => SvgPicture.asset('assets/hand.svg'),
  size: 56,
)
```

What to know when you swap the artwork:

- Your widget is laid out in a `size` × `size` box (fixed logical pixels — not
  a screen fraction — so it stays sane on desktop windows). Use a `FittedBox`
  if the artwork isn't square. Opt into text-scale sizing with
  `scaleWithTextScaler: true`.
- **`hotspot` is the important one**: it declares which point of *your*
  artwork sits exactly on the anchor (a cursor's arrow tip is `topLeft`, an
  upward finger is `topCenter`). Rotation, the entry scale and the tap-pulse
  squash all pivot around this point, so the tip stays planted through every
  animation.
- Glides, arcs, rotation, `tapPulse`, show/hide fades and live tracking are
  inherited unchanged — the choreography layer doesn't care what it's moving.
- Animated artwork (GIF/Lottie/Rive) plays on its own clock while keyspot
  moves it around; the two don't interfere.
- `flipForRtl: true` mirrors the artwork in right-to-left locales.

## Tours

```dart
final KeyspotTour tour = KeyspotTour(
  id: 'first-run',
  storage: myPrefsStorage,          // implement wasSeen / markSeen
  steps: <KeyspotStep>[
    KeyspotStep(
      id: 'search',
      targetKey: searchKey,
      advance: StepAdvance.manual,
      rings: const <RingStyle>[      // per-step rings: use colour as a progress cue
        RingStyle(color: Color(0xFF00ACC1), width: 5),
      ],
      contentBuilder: (BuildContext context, Rect rect, TourSession session) => Card(
        child: Row(children: <Widget>[
          Text('Step ${session.index + 1} of ${session.stepCount}'),
          TextButton(onPressed: session.previous, child: const Text('Back')),
          TextButton(onPressed: session.skip, child: const Text('Skip')),
          FilledButton(onPressed: session.next, child: const Text('Next')),
        ]),
      ),
    ),
    KeyspotStep(
      id: 'compose',
      targetKey: composeKey,
      advance: StepAdvance.tapTarget,   // they must actually press it
      onEnter: (TourSession session) => narrator.play('compose'),
    ),
  ],
);

final TourResult result = await keyspot.startTour(tour);
// TourResult.completed | TourResult.skipped | TourResult.cancelled
```

`StepAdvance` picks a matching barrier for you:

| Advance mode | Steps forward when | Default barrier |
|---|---|---|
| `tapTarget` | the user taps the real target | `targetOnly()` |
| `tapAnywhere` | the user taps anywhere | `dismissOnTap(outsideOnly: false)` |
| `manual` | you call `session.next()` | `block()` (or `dismissOnTap` if `barrierSkippable`) |
| `after(duration)` | a timer fires | `block()` |

Content cards are positioned automatically above or below the cut-out
(`KeyspotContentPosition.auto`), always from the *live* rect. A throwing
`onEnter` logs and moves on rather than stranding the tour. If the tour's
storage says it has already been seen, `startTour` returns
`TourResult.skipped` without showing anything — the package ships
`InMemoryTourStorage`; plug `shared_preferences` in yourself via the two-method
`KeyspotTourStorage` interface.

## The tracker, on its own

The piece that stops the drift is public, because it is useful by itself:

```dart
Stack(children: <Widget>[
  content,
  KeyspotAnchorTracker(
    targetKey: cartKey,
    mode: TrackingMode.everyFrame,   // or onScrollAndMetrics, or once
    builder: (BuildContext context, Rect? rect) => rect == null
        ? const SizedBox.shrink()
        : Positioned(left: rect.right - 8, top: rect.top - 8, child: const Badge()),
  ),
]);
```

Hang badges, connector lines or your own coach-marks off any widget without
wrapping it. `rect` is null whenever the target can't currently be measured —
render nothing and it will come back on its own. `TrackingMode.onScrollAndMetrics`
is the battery-friendly variant (re-measures on scroll and metrics changes
only); `once` reproduces the snapshot behaviour of simpler packages for static
screens.

## Theming

Set defaults once, override per call:

```dart
MaterialApp(
  theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[
    KeyspotTheme(
      barrierColor: Colors.black,
      barrierOpacity: 0.8,
      rings: <RingStyle>[
        RingStyle(color: Colors.white, width: 6),
        RingStyle(color: Colors.cyanAccent, width: 4, gap: 4),
      ],
      entryDuration: Duration(milliseconds: 1000),
      defaultSpotlightDuration: Duration(seconds: 2),
      pointerStyle: PointerStyle(size: 56),
    ),
  ]),
)

// Or scope-level, which wins over the ThemeExtension:
KeyspotScope(controller: keyspot, theme: const KeyspotTheme(...), child: app)
```

Resolution order: the argument you passed → `KeyspotScope.theme` →
`Theme.of(context).extension<KeyspotTheme>()` → built-in defaults.

## Lifecycle: resuming after an app switch

For narrated or animated steps, re-trigger whatever the user missed when they
come back:

```dart
keyspot.setResumeHandler((KeyspotResumeContext ctx) {
  narrator.replay(ctx.stepId);   // also carries targetKey and tourId
});
```

The handler fires on `AppLifecycleState.resumed` while a spotlight or tour step
is active. Pass `null` to unregister.

## Accessibility

- `MediaQuery.disableAnimations` is honoured: glides become jump-cuts, ring
  pulses stop, the dim and cut-out remain.
- `semanticLabel` on a spotlight or step is announced via `SemanticsService`.
- Anchors accept `AlignmentDirectional`, and `PointerStyle.flipForRtl` mirrors
  the hand in right-to-left locales.

## Hardening guarantees

These are tested behaviours, not aspirations:

- A target key that never resolves → the future completes (`cancelled`),
  nothing is painted, nothing throws.
- A target unmounted mid-spotlight → the overlay tears down and the future
  resolves; it never freezes on a stale rect.
- `spotlight()` while another is active → the old future completes as
  `cancelled`, the new spotlight takes over; never two at once.
- Disposing the controller mid-animation → every pending future completes
  rather than erroring, and nothing notifies after disposal.
- Calling any pointer or spotlight method with no `KeyspotScope` mounted → an
  inert no-op that logs (if you gave it a logger) and returns.
- A throwing `until()` or `onEnter` → logged, resolved, the user is never
  stranded under a dim layer.

## Logging

Silent by default. Hand it a logger to watch what it's doing:

```dart
KeyspotController(logger: KeyspotLoggers.debug);   // forwards to debugPrint
KeyspotController(logger: (String m) => log.fine(m));
```

## Testing apps that use keyspot

Widget tests drive keyspot fine — two things to know:

- Ring pulses repeat forever by design, so `pumpAndSettle` will time out while
  a spotlight with pulsing rings is up. Pump explicit durations instead, or use
  rings with `RingPulse.none()` in your test theme.
- Futures from `spotlight()`/`moveTo()` complete on animation completion, so
  don't `await` them before pumping — start them, pump the duration, then
  assert. See [`test/harness.dart`](test/harness.dart) for the pattern this
  package uses on itself.

## Running the demos

```sh
cd example
flutter run          # any device; -d chrome and -d macos are good first picks
```

Eight pages, one per use case:

| Page | Shows |
|---|---|
| `basic_spotlight` | every barrier mode, `until:`, four different ring voices |
| `shapes_gallery` | `auto` resolution against real Material shapes, forced shapes, a custom path |
| `pointer_playground` | show/moveTo/sweep/tapPulse with sliders for duration, rotation, arc |
| `scrolling_list` | auto scroll-into-view, then drift-free tracking while you scroll |
| `drift_torture_test` | a target that orbits, rotates and resizes while the spotlight stays glued |
| `full_tour` | 7 steps, content cards, back/skip, per-step ring colours, storage |
| `gesture_teaching` | drag taught with an arc glide, pinch taught with a two-finger sweep |
| `theming` | neon ring stacks, ringless spotlights, emoji / SVG / animated / cursor pointers |

## Platforms

Android, iOS, web, macOS, Windows and Linux. The rendering strategy
(`Canvas.saveLayer` plus `BlendMode.clear` cut-outs) is supported everywhere.

## Roadmap

- `0.1.0` — spotlight, hand pointer, live anchor tracking, theming ✅
- `0.2.0` — multi-step tours, scroll-into-view ✅
- `0.3.0` — reduced-motion and semantics support, arc motion paths ✅
- `0.9.0` — API freeze, golden suite, docs pass, pana 160/160
- `1.0.0` — after four weeks of 0.9 issue triage

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Two rules that will not bend: no runtime
dependencies, and no guessed timing.

## License

MIT © Shreyash Bhardwaj
