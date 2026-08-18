# keyspot

**Spotlights and guided hand gestures for Flutter — anchored to a GlobalKey, tracked live, never drifting.**

[![pub package](https://img.shields.io/pub/v/keyspot.svg)](https://pub.dev/packages/keyspot)
[![CI](https://github.com/shrey-17bhardwaj/keyspot/actions/workflows/ci.yml/badge.svg)](https://github.com/shrey-17bhardwaj/keyspot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**[▶ Try the live demo](https://shrey-17bhardwaj.github.io/keyspot/)**

<p>
  <img src="https://raw.githubusercontent.com/shrey-17bhardwaj/keyspot/main/doc/gifs/shapes.gif" width="32%" alt="Spotlight shapes: circle, rounded rect, stadium and a custom path" />
  <img src="https://raw.githubusercontent.com/shrey-17bhardwaj/keyspot/main/doc/gifs/pointer.gif" width="32%" alt="The animated hand pointer gliding and rotating between targets" />
  <img src="https://raw.githubusercontent.com/shrey-17bhardwaj/keyspot/main/doc/gifs/gesture.gif" width="32%" alt="Teaching a drag and a pinch gesture with the animated hand" />
</p>
<p>
  <img src="https://raw.githubusercontent.com/shrey-17bhardwaj/keyspot/main/doc/gifs/tour.gif" width="32%" alt="A multi-step guided tour with content cards" />
  <img src="https://raw.githubusercontent.com/shrey-17bhardwaj/keyspot/main/doc/gifs/theming.gif" width="32%" alt="A ring stack settling, then swapping the pointer through several costumes" />
</p>

---

- [Why keyspot?](#why-keyspot)
- [Use cases](#use-cases)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Spotlights](#spotlights)
- [The pointer](#the-pointer)
- [Tours](#tours)
- [The tracker, on its own](#the-tracker-on-its-own)
- [Theming](#theming)
- [Accessibility](#accessibility)
- [Hardening guarantees](#hardening-guarantees)
- [Testing apps that use keyspot](#testing-apps-that-use-keyspot)
- [Running the demos](#running-the-demos)
- [Platforms](#platforms)

## Why keyspot?

Every onboarding package can dim the screen and punch a hole over a widget.
Keyspot does two things the others don't:

1. **Drift-free tracking.** The spotlight and pointer re-resolve the target's
   geometry every frame, so they follow it through scrolling, keyboard insets,
   rotation and window resizing — instead of painting a stale snapshot.
2. **Gesture choreography.** An animated hand that glides between targets,
   rotates, and pulses — teaching *gestures*, not just *locations*.

Everything is addressed by `GlobalKey` — no coordinates, no wrapper widgets.
Zero runtime dependencies; the hand is a `CustomPainter`, not an asset.

## Use cases

| Use case | What you reach for | Demo |
|---|---|---|
| First-run tour | `KeyspotTour` + step content cards | `full_tour` |
| Teach a gesture ("drag this here") | `pointer.moveTo` with an arc path | `gesture_teaching` |
| Teach pinch/rotate on an image | spotlight + `overlayBuilder` + pointer | `gesture_teaching` |
| Highlight a row in a scrollable list | `scrollIntoView` + live tracking | `scrolling_list` |
| Feature announcement | one-off spotlight, `dismissOnTap()` | `basic_spotlight` |
| Narrated step that holds while audio plays | `spotlight(until: playNarration)` | `basic_spotlight` |
| "You must actually tap this" | `SpotBarrier.targetOnly()` | `basic_spotlight`, `full_tour` |
| Desktop/web tour with a mouse | custom cursor via `PointerStyle.builder` | `theming` |

## Installation

```yaml
dependencies:
  keyspot: ^0.3.0
```

Or:

```sh
flutter pub add keyspot
```

Requires Dart ≥ 3.4 and Flutter ≥ 3.22.

## Quick start

```dart
final keyspot = KeyspotController();
final composeKey = GlobalKey();

// One wrapper, anywhere above your content.
KeyspotScope(
  controller: keyspot,
  child: MaterialApp(home: Inbox(composeKey: composeKey)),
);

// Highlight a widget for two seconds.
await keyspot.spotlight(composeKey);
```

`KeyspotScope` mounts the overlays itself — you never place them by hand. Put
it above `MaterialApp` to cover every route, or inside `MaterialApp.builder` to
inherit `Theme`/`Directionality` for tour content cards. Descendants can fetch
the controller with `KeyspotScope.of(context)`. Its lifetime is yours — call
`keyspot.dispose()` when done.

## Spotlights

```dart
await keyspot.spotlight(
  composeKey,
  shape: const SpotShape.auto(),      // mirrors the widget's own rounding
  padding: const EdgeInsets.all(12),
  barrier: const SpotBarrier.block(), // absorb stray taps (default)
  duration: const Duration(seconds: 4),
  semanticLabel: 'Compose button',
);
```

Calling `spotlight()` while one is active cancels the old one first — never
two at once, and the old future completes as `cancelled` rather than hanging.

**Shapes** — `auto()` (default) mirrors the target's own clip/decoration where
it can, else a circle for square-ish widgets and a 12px rrect otherwise:

```dart
const SpotShape.circle();
const SpotShape.rrect(radius: 28);
const SpotShape.stadium();
SpotShape.path((Rect rect) => Path()..addOval(rect));  // any outline
```

**Rings** — stacked outlines, each with its own colour, width, gap and
opacity pulse, set per call, per tour step, or once in the theme:

```dart
rings: const <RingStyle>[
  RingStyle(color: Color(0xFFFFB300), width: 6),                 // warm rim
  RingStyle(
    color: Color(0xFF00E676),
    width: 4,
    pulse: RingPulse(minOpacity: 0.3, period: Duration(milliseconds: 350)),
  ),
],
rings: const <RingStyle>[]   // no rings
// rings: null (default)     // use the theme's rings
```

**Barriers** — the capability most packages skip:

| Barrier | Outside the cut-out | Inside the cut-out |
|---|---|---|
| `passthrough()` | passes through | passes through |
| `block()` *(default)* | absorbed | absorbed |
| `dismissOnTap()` | dismisses | absorbed |
| `targetOnly()` | absorbed | **reaches the real widget**, then resolves |

`targetOnly` builds "you must actually tap this" walkthroughs — the button's
own `onPressed` still fires.

**Outcomes** — the future tells you why it ended:

```dart
final outcome = await keyspot.spotlight(key, barrier: const SpotBarrier.dismissOnTap());
// SpotlightOutcome.finished | dismissedByUser | targetTapped | cancelled
```

**Duration** — a timer (`duration:`), action-scoped (`until: () => task()`,
resolves even if the callback throws), or programmatic (`hideSpotlight()`).

**Scroll-into-view** — on by default (`scrollIntoView: true`); scrolls the
target to center before measuring. Needs the target to already be *built*, so
a `ListView.builder` far below the fold won't resolve — scroll near it first,
or use a non-lazy list for tour targets.

## The pointer

```dart
await keyspot.pointer.show(cardKey.anchor());
await keyspot.pointer.moveTo(
  archiveKey.anchor(),
  duration: const Duration(milliseconds: 900),
  path: const MotionPath.arc(height: 0.3),   // bows, reads as a drag
  rotation: const Rotation.degrees(-15),
);
await keyspot.pointer.tapPulse(count: 2);
await keyspot.pointer.hide();

// One-liner: show at A, glide to B, dwell, hide.
await keyspot.pointer.sweep(cardKey.anchor(), archiveKey.anchor());
```

Every future completes on real `AnimationController` completion, never a
guessed delay. `show()` resolves as soon as it's mounted, so a `moveTo` can
chain right away. `keyspot.pointer.phase` reports `idle → moving → arrived`.

**Anchors** — a point on, or relative to, a widget:

```dart
cardKey.anchor()                          // center
cardKey.anchor(Alignment.bottomCenter)    // any Alignment
const Anchor.offset(Offset(120, 480))     // fixed screen point, escape hatch
```

**Rotation** is explicit — no degrees/radians guessing — and always animates
from the current angle along the shortest path:

```dart
const Rotation.degrees(-95);
const Rotation.radians(math.pi / 4);
```

**Custom artwork** — `PointerStyle.builder` is a plain `WidgetBuilder`, so
*any* widget can be the pointer: emoji, PNG, GIF, SVG, Lottie, Rive.

```dart
PointerStyle(
  builder: (context) => const FittedBox(child: Text('👆')),
  size: 48,
  hotspot: Alignment.topCenter,   // which point of your artwork sits on the anchor
)
```

`hotspot` is the one that matters — rotation, entry scale and the tap-pulse
all pivot around it, so the tip stays planted through every animation.
Animated artwork plays on its own clock while keyspot moves it; the two don't
interfere. `flipForRtl: true` mirrors it in RTL locales.

## Tours

```dart
final tour = KeyspotTour(
  id: 'first-run',
  storage: myPrefsStorage,   // implement wasSeen / markSeen
  steps: <KeyspotStep>[
    KeyspotStep(
      id: 'search',
      targetKey: searchKey,
      advance: StepAdvance.manual,
      contentBuilder: (context, rect, session) => Card(
        child: TextButton(onPressed: session.next, child: const Text('Next')),
      ),
    ),
    KeyspotStep(
      id: 'compose',
      targetKey: composeKey,
      advance: StepAdvance.tapTarget,   // must actually press it
    ),
  ],
);

final result = await keyspot.startTour(tour);
// TourResult.completed | skipped | cancelled
```

`StepAdvance` picks a matching barrier: `tapTarget` → `targetOnly()`,
`tapAnywhere` → dismiss anywhere, `manual` → waits for `session.next()`,
`after(duration)` → timer. Content cards position themselves above or below
the cut-out from the live rect. If the tour's storage reports it seen,
`startTour` returns `skipped` without showing anything — ships
`InMemoryTourStorage`; plug in `shared_preferences` via the two-method
`KeyspotTourStorage` interface.

## The tracker, on its own

The piece that stops the drift is public — useful on its own for badges,
connector lines or coach-marks on any widget:

```dart
KeyspotAnchorTracker(
  targetKey: cartKey,
  mode: TrackingMode.everyFrame,   // or onScrollAndMetrics, or once
  builder: (context, rect) => rect == null
      ? const SizedBox.shrink()
      : Positioned(left: rect.right - 8, top: rect.top - 8, child: const Badge()),
)
```

## Theming

```dart
MaterialApp(
  theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[
    KeyspotTheme(
      barrierOpacity: 0.8,
      rings: <RingStyle>[RingStyle(color: Colors.white, width: 6)],
      pointerStyle: PointerStyle(size: 56),
    ),
  ]),
)
```

Resolution order: argument passed → `KeyspotScope.theme` →
`Theme.of(context).extension<KeyspotTheme>()` → built-in defaults.

For app-resume narration, `keyspot.setResumeHandler((ctx) => ...)` fires
whenever the app resumes mid-spotlight or mid-tour.

## Accessibility

- `MediaQuery.disableAnimations` skips glides and ring pulses; the dim and
  cut-out remain.
- `semanticLabel` is announced via `SemanticsService`.
- `AlignmentDirectional` anchors and `PointerStyle.flipForRtl` support RTL.

## Hardening guarantees

Tested behaviours, not aspirations: an unresolvable target key resolves the
future (`cancelled`) and paints nothing; a target unmounted mid-spotlight
tears down cleanly; disposing mid-animation completes every pending future
without erroring; any call with no `KeyspotScope` mounted is an inert no-op; a
throwing `until()`/`onEnter` is logged and resolved, never stranding the user.

## Testing apps that use keyspot

- Ring pulses repeat forever, so `pumpAndSettle` will time out with a pulsing
  spotlight up — pump explicit durations, or use `RingPulse.none()` in tests.
- Futures resolve on animation completion — start them, pump the duration,
  then assert; don't `await` before pumping. See
  [`test/harness.dart`](test/harness.dart) for the pattern this package uses.

## Running the demos

```sh
cd example
flutter run          # -d chrome and -d macos are good first picks
```

| Page | Shows |
|---|---|
| `basic_spotlight` | every barrier mode, `until:`, four ring voices |
| `shapes_gallery` | `auto` resolution, forced shapes, a custom path |
| `pointer_playground` | show/moveTo/sweep/tapPulse, live sliders |
| `scrolling_list` | scroll-into-view, then drift-free tracking |
| `full_tour` | 7 steps, content cards, back/skip, storage |
| `gesture_teaching` | a drag taught with an arc, a pinch with a sweep |
| `theming` | ring stacks, and the pointer as hand / emoji / SVG / animated |

## Platforms

Android, iOS, web, macOS, Windows and Linux.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Two rules that will not bend: no
runtime dependencies, and no guessed timing.

## License

MIT © Shreyash Bhardwaj
