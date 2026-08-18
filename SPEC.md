# Keyspot — Package Implementation Specification v1.0

> **Purpose of this document:** Complete, self-contained implementation spec for a new Flutter
> package. Hand this file to an engineer (or an AI coding agent) in an empty repository and it
> contains every decision needed to build, test, document, and publish the package without
> referring back to the original app code. The original reference implementation lived in a
> private app (`mira-app` student onboarding module); this is a **clean-room rewrite spec** —
> no code is to be copied from that repository.

---

## 1. Vision & Positioning

**Package name (primary):** `keyspot`
**Tagline:** *Spotlights and guided hand gestures for Flutter — anchored to a GlobalKey, tracked live, never drifting.*

**Elevator pitch:** Every Flutter onboarding package can dim the screen and punch a hole over a
widget. Keyspot does two things the others don't:

1. **Drift-free tracking.** The spotlight and pointer re-resolve the target's geometry every
   frame, so they follow the widget through scrolling, keyboard insets, orientation changes,
   window resizing (desktop/web), and any layout shift. Competitors paint a one-shot
   `localToGlobal` snapshot and visibly drift.
2. **Gesture choreography.** An animated hand pointer that appears, glides between targets,
   rotates, pulses, and signals arrival — teaching *gestures* ("drag this here", "pinch this"),
   not just *locations* ("look here").

Everything is driven by `GlobalKey`s — no coordinates, no manual measurement, no wrapper
widgets around every target.

**Name decision & fallbacks.** Before creating the repo, verify `keyspot` is unclaimed on
pub.dev (`https://pub.dev/packages/keyspot` → 404 means free). Fallbacks in order of
preference: `spotguide`, `anchor_spotlight`, `hand_guide`, `spotlight_tour`. Reserve the
matching GitHub repo name at the same time. Everything below uses `keyspot`; rename
mechanically if needed.

**License:** MIT. **Minimum SDK:** Dart ≥ 3.4, Flutter ≥ 3.22. **Runtime dependencies:**
`flutter` only — zero third-party packages (no `provider`, no `flutter_svg`; the default hand
is a `CustomPainter`). Dev dependencies: `flutter_test`, `flutter_lints`.

**Platforms:** all six (Android, iOS, web, macOS, Windows, Linux). The rendering strategy
(`Canvas.saveLayer` + `BlendMode.clear` cut-outs) is supported on all of them; the example app
must be smoke-run on web + at least one desktop platform before every release.

---

## 2. Use Cases (drive the API and the example app)

| # | Use case | Features exercised |
|---|----------|--------------------|
| 1 | First-run app tour ("this is your inbox, this is compose") | Tour sequencing, spotlight, tap-to-advance |
| 2 | Teach a gesture: "drag the card to the archive column" | Pointer show → glide between two keys → hide |
| 3 | Teach pinch/rotate on an image or map | Spotlight + custom overlay widget over the cut-out, pointer rotation |
| 4 | Highlight a button inside a scrollable settings list | Auto scroll-into-view, live tracking while scrolling |
| 5 | Feature announcement after an update ("new: dark mode toggle") | One-off spotlight with dismiss-on-tap barrier |
| 6 | Kids/education apps: narrated step with audio, resume after app switch | Action-scoped spotlight (`until:`), lifecycle resume callback |
| 7 | Form walkthrough where the user must actually perform each step | Barrier passthrough on target only; advance on real target tap |
| 8 | Desktop/web product tour with mouse users | Pointer widget swap (cursor instead of hand), window-resize tracking |

---

## 3. Public API Design

Everything public lives under `lib/keyspot.dart` (single export file). Naming rule: every
public type is prefixed `Keyspot` or is an obviously scoped noun (`SpotShape`, `RingStyle`,
`Rotation`, `Anchor`).

### 3.1 The scope (one-line integration)

```dart
KeyspotScope(
  controller: keyspot,          // required, a KeyspotController
  theme: KeyspotTheme(...),     // optional
  child: MaterialApp(...),      // or any subtree; overlays render above this child
)
```

`KeyspotScope` is a `StatefulWidget` that wraps `child` in a `Stack` and mounts the spotlight
and pointer overlay layers itself, listening to the controller via `ListenableBuilder`.
It also exposes `KeyspotScope.of(context)` / `maybeOf(context)` (via `InheritedNotifier`) so
descendants can grab the controller without any state-management package. **The user never
manually places overlay widgets.** Typical placement is `builder:` of `MaterialApp` (so it
covers routes) — document both patterns (above `MaterialApp` vs in `builder`).

### 3.2 Anchors — how targets are addressed

```dart
// A point on (or relative to) a target widget.
class Anchor {
  const Anchor.key(GlobalKey key, {Alignment alignment = Alignment.center});
  const Anchor.offset(Offset globalOffset);          // escape hatch / fallback
}

// Sugar so call sites read naturally:
extension KeyspotAnchorX on GlobalKey {
  Anchor anchor([Alignment alignment = Alignment.center]);
}
```

Decision: use `Alignment` (Flutter-idiomatic, −1..1, `Alignment.bottomCenter` reads well)
instead of the 0..1 fraction pairs of the reference implementation. Internally alignment maps
to the same math: `pos + size * ((align + 1) / 2)`.

### 3.3 Rotation — no unit guessing

The reference implementation inferred degrees vs radians from magnitude (`abs() > 2π ⇒
degrees`), which makes 7 rad unexpressible. Replace with an explicit value type:

```dart
class Rotation {
  const Rotation.degrees(double value);
  const Rotation.radians(double value);
  const Rotation.none();                 // 0
  double get radians;
}
```

### 3.4 KeyspotController — the single entry point

```dart
class KeyspotController extends ChangeNotifier {
  KeyspotController({KeyspotLog? logger});

  // ---- Spotlight ----------------------------------------------------------
  /// Dims the screen and cuts a spotlight around [key]. Resolves when the
  /// spotlight is dismissed (by [until], [duration], barrier tap, or hide()).
  Future<void> spotlight(
    GlobalKey key, {
    SpotShape shape = const SpotShape.auto(),
    EdgeInsets padding = const EdgeInsets.all(12),
    List<RingStyle>? rings,                  // null → theme default; const [] → no rings
    SpotBarrier barrier = const SpotBarrier.block(),
    Widget Function(BuildContext, Rect targetRect)? overlayBuilder,
    Future<void> Function()? until,          // action-scoped: hold while this runs
    Duration? duration,                      // used only when until == null; default 2s
    bool scrollIntoView = true,
    Duration scrollDuration = const Duration(milliseconds: 300),
  });

  Future<void> hideSpotlight();              // programmatic dismiss

  // ---- Pointer ------------------------------------------------------------
  KeyspotPointer get pointer;

  // ---- Tours (sequencing) -------------------------------------------------
  Future<TourResult> startTour(KeyspotTour tour);
  TourSession? get activeTour;               // null when no tour running

  // ---- Lifecycle ----------------------------------------------------------
  /// Called when the app resumes while a spotlight/tour step is active, so the
  /// host can replay audio/animation for the current step.
  void setResumeHandler(void Function(KeyspotResumeContext ctx)? handler);
}
```

`spotlight()` re-entrancy rule: calling it while another spotlight is active first completes
the old one's future (as cancelled) and cleanly replaces it — never two active at once.

### 3.5 KeyspotPointer — hand choreography

```dart
class KeyspotPointer {
  bool get isVisible;

  /// Shows the pointer at [at] (fade+scale in). No-op if already visible.
  Future<void> show(Anchor at, {PointerStyle? style, Rotation rotation});

  /// Glides to [to] with a real AnimationController; the future completes when
  /// the glide actually finishes. Cancellable by a subsequent moveTo/hide.
  Future<void> moveTo(
    Anchor to, {
    Duration duration = const Duration(milliseconds: 800),
    Curve curve = Curves.easeInOutCubic,
    Rotation? rotation,                 // animates from current angle (no snap-to-zero)
    MotionPath path = MotionPath.line,  // line | arc(height) — arc sells "drag" gestures
  });

  /// Convenience: show at [from], glide to [to], optional dwell, then hide.
  Future<void> sweep(Anchor from, Anchor to, {Duration duration, Duration dwell, ...});

  /// Plays a tap animation at the current position (scale-down/up + ripple ring).
  Future<void> tapPulse({int count = 1});

  Future<void> hide();                  // fade out, then detach
}
```

State signalling for styling: pointer exposes `PointerPhase phase` (idle → moving → arrived)
and the arrival dot color animates per theme (replaces the reference app's hard-coded
teal/purple logic — which had a dead branch always returning teal).

### 3.6 Shapes

```dart
sealed class SpotShape {
  const SpotShape.circle();                       // circumscribes the target
  const SpotShape.rrect({double radius});
  const SpotShape.stadium();
  const SpotShape.auto();                         // DEFAULT — see resolution rules
  const SpotShape.path(Path Function(Rect targetRect) builder);  // full custom
}
```

`SpotShape.auto()` resolution: if the target's render object (or a descendant within one
level) is a `RenderClipRRect` / has a resolvable `ShapeBorder` via `Material`/`DecoratedBox`,
mirror its rounding; else if `width ≈ height` (within 20%) use circle; else `rrect(radius:
12)`. This replaces the reference implementation's hack of type-checking a proprietary
`PressableContainer` widget. Keep `auto` best-effort and documented as such.

### 3.7 Rings & theme

```dart
class RingStyle {
  const RingStyle({
    required Color color,
    double width = 8,
    double gap = 0,               // distance from the previous ring / cut-out edge
    RingPulse pulse = const RingPulse(opacity: (0.4, 1.0), period: Duration(ms: 600)),
  });
}

class KeyspotTheme extends ThemeExtension<KeyspotTheme> {
  final Color barrierColor;                     // default Colors.black
  final double barrierOpacity;                  // default 0.7
  final List<RingStyle> rings;                  // default: white outer + accent inner
  final Duration entryDuration;                 // default 1000ms (dim 0–300ms, scale 300–1000ms easeOutBack)
  final PointerStyle pointerStyle;
  final Duration defaultSpotlightDuration;      // default 2s
}

class PointerStyle {
  final WidgetBuilder? builder;                 // null → built-in painted hand
  final double size;                            // logical px, default 56
  final Color dotColor;                         // glow dot at fingertip
  final Color arrivedDotColor;
  final bool showGlowDot;
}
```

Theme resolution order: explicit parameter → `KeyspotScope.theme` →
`Theme.of(context).extension<KeyspotTheme>()` → built-in defaults. Sizing: fixed logical px
scaled by `MediaQuery.textScaler` opt-in flag, NOT screen-fraction sizing (the reference
implementation sized the hand as a % of screen width/height, which breaks on desktop windows).

### 3.8 Barrier behavior (new capability — reference app had none)

```dart
sealed class SpotBarrier {
  const SpotBarrier.passthrough();      // taps go through everywhere (reference behavior)
  const SpotBarrier.block();            // absorb all taps outside the cut-out (DEFAULT)
  const SpotBarrier.dismissOnTap({bool outsideOnly = true});   // tap dismisses spotlight
  const SpotBarrier.targetOnly({VoidCallback? onTargetTap});   // only the cut-out is tappable;
                                        // tapping it forwards the hit AND resolves the spotlight
}
```

Implementation: the barrier layer is a `Listener`/`GestureDetector` whose hit-testing consults
the current cut-out path (`path.contains(localPoint)`); `targetOnly` uses `IgnorePointer` with
a custom `HitTestBehavior` region so the real widget receives the tap.

### 3.9 Tours (sequencing engine — generic, replaces the app's hard-coded enum)

```dart
class KeyspotStep {
  final String id;
  final GlobalKey targetKey;
  final SpotShape shape; final EdgeInsets padding; final List<RingStyle>? rings;
  final SpotBarrier barrier;
  final Widget Function(BuildContext, Rect targetRect, TourSession session)? contentBuilder;
      // tooltip/card with your own Next/Skip buttons; positioned via KeyspotContentPosition
  final Future<void> Function(TourSession session)? onEnter;   // e.g. play audio, run pointer moves
  final StepAdvance advance;      // .tapTarget | .tapAnywhere | .manual (session.next()) | .after(duration)
}

class KeyspotTour {
  final String id;                                  // for persistence
  final List<KeyspotStep> steps;
  final bool barrierSkippable;
  final KeyspotTourStorage? storage;                // interface: markSeen(id)/wasSeen(id);
                                                    // package ships in-memory impl only —
                                                    // users plug shared_preferences themselves
}

class TourSession {                                  // handed to builders/callbacks
  int get index;  KeyspotStep get step;
  Future<void> next(); Future<void> previous(); Future<void> skip();
  ValueListenable<int> get indexListenable;
}

enum TourResult { completed, skipped, cancelled }
```

### 3.10 Logging

`typedef KeyspotLog = void Function(String message);` — default is silent. `KeyspotLog.debug`
provided as a `debugPrint` forwarder. **No unconditional `debugPrint` anywhere** (the
reference implementation logged every call).

---

## 4. Architecture & File Layout

```
keyspot/
├── lib/
│   ├── keyspot.dart                    # sole public export
│   └── src/
│       ├── core/
│       │   ├── keyspot_controller.dart
│       │   ├── anchor.dart             # Anchor, Rotation, geometry math
│       │   ├── anchor_tracker.dart     # live per-frame rect resolver (see §5.1)
│       │   ├── spotlight_state.dart    # immutable request/state objects
│       │   ├── pointer_state.dart
│       │   └── lifecycle_observer.dart # app-resume re-trigger
│       ├── tour/
│       │   ├── tour.dart  tour_session.dart  tour_storage.dart
│       ├── widgets/
│       │   ├── keyspot_scope.dart
│       │   ├── spotlight_overlay.dart  # TrackedAnchor consumer + FocusPainter
│       │   ├── pointer_overlay.dart    # AnimationController-driven glide/rotate
│       │   ├── barrier_layer.dart
│       │   └── default_hand_painter.dart
│       ├── theme/
│       │   ├── keyspot_theme.dart  ring_style.dart  pointer_style.dart
│       └── util/
│           ├── shape_resolver.dart     # SpotShape.auto logic
│           ├── scroll_into_view.dart
│           └── log.dart
├── test/               (mirrors src/, see §7)
├── example/            (see §8)
├── .github/workflows/ci.yml
├── README.md  CHANGELOG.md  LICENSE  analysis_options.yaml  pubspec.yaml
```

Layer rule: `core/` imports nothing from `widgets/`; `widgets/` read state only through the
controller. All state objects immutable (`copyWith`), controller swaps them and notifies.

---

## 5. Implementation Notes (the hard-won details)

### 5.1 AnchorTracker (the differentiator — generalize the reference `TrackedAnchor`)

- Resolves target `RenderBox` → `localToGlobal(Offset.zero)` → overlay-local via own
  `globalToLocal`, guarded by `hasSize`/`attached` + try/catch (transforms can throw during
  teardown). Returns `Rect?`; `null` renders nothing (`SizedBox.shrink`).
- Re-measures via a `Ticker` **plus** `WidgetsBindingObserver.didChangeMetrics`, and only
  calls `setState` when the rect actually changed.
- New: `TrackingMode { everyFrame, onScrollAndMetrics, once }` — `everyFrame` is default;
  `onScrollAndMetrics` registers a `ScrollNotification` listener + metrics callback for
  battery-sensitive use; `once` reproduces snapshot behavior for static screens.
- New: expose the tracker as **public API** (`KeyspotAnchorTracker` builder widget) — it is
  independently useful (badges, connectors, coach-marks) and a documented selling point.

### 5.2 Spotlight overlay & painter

- Painter: `saveLayer` → dim rect at `barrierColor.withOpacity(alpha)` → rings (stroke, each
  ring's opacity multiplied by its own pulse animation value) → cut-out with
  `BlendMode.clear` using the resolved `SpotShape` path → `restore`. `shouldRepaint` compares
  every field.
- Entry choreography (match reference feel): dim fades in over first 30% of `entryDuration`
  (easeIn); cut-out+rings scale 0→1 over remaining 70% (easeOutBack). Ring pulse repeats
  (reverse: true) for the spotlight's lifetime.
- When target rect becomes `null` mid-spotlight (widget unmounted): fade the whole overlay
  out over 150 ms and resolve the future — never freeze or throw.
- Re-show reset: use `await WidgetsBinding.instance.endOfFrame` — not the reference's
  `Future.delayed(16ms)` guess.

### 5.3 Pointer overlay — real animations, not delays

The reference implementation moved the hand with `AnimatedPositioned` + `Future.delayed`
sandwiches; completion timing was guessed and `reachedDestination` fired early. Replace with:

- One `AnimationController` per glide, owned by the overlay state; position =
  `Tween<Offset>` (or arc path via `PathMetric` for `MotionPath.arc`) driven by it.
  `moveTo`'s future completes on `controller.forward()` completion; a new `moveTo`/`hide`
  cancels the current one (old future completes with a `cancelled` flag internally; public
  future just completes).
- Rotation animates **from the current angle to the new angle** (keep a persistent rotation
  controller; never key a `TweenAnimationBuilder` by the target value — that snaps to 0 first,
  the reference bug).
- First `show()` never glides from `Offset.zero`: pointer is mounted at its initial anchor
  with a fade/scale-in, position animation only starts on `moveTo`.
- Glow dot: pulsing white halo + colored core dot at the fingertip anchor point; core color
  lerps `dotColor → arrivedDotColor` when phase == arrived. Pointer hotspot (which point of
  the hand widget sits on the anchor) is configurable: `PointerStyle.hotspot: Alignment`,
  default `Alignment.topLeft` region of the fingertip in the built-in hand.
- Built-in hand: a `CustomPainter` (simple filled pointing-hand silhouette with rounded
  strokes, ~2 colors from theme) — **no asset files, no flutter_svg**. Users swap any widget
  via `PointerStyle.builder` (Lottie/Rive/emoji/Image — all their choice, their dependency).

### 5.4 Waiting for targets to exist

Port the reference's two hardening behaviors, unified: a single
`Future<RenderBox?> resolveBox(GlobalKey key, {int retryFrames = 3})` that retries across
`endOfFrame` ticks (targets inside freshly-pushed routes aren't laid out on frame one), used
by both spotlight and pointer. `Anchor.offset` remains the explicit fallback when a key may
legitimately never resolve.

### 5.5 Scroll-into-view

Before spotlighting, if `scrollIntoView` and the target has a `Scrollable` ancestor and its
rect is (partially) outside the viewport: `Scrollable.ensureVisible(context, alignment: 0.5,
duration: scrollDuration, curve: Curves.easeInOut)`, then wait `endOfFrame` before measuring.
Live tracking makes this safe even if the scroll settles slightly differently.

### 5.6 Lifecycle resume

Controller owns a `WidgetsBindingObserver`; on `AppLifecycleState.resumed` while a spotlight
or tour step is active, invoke the registered resume handler with
`KeyspotResumeContext(activeStepId, targetKey)`. (Reference feature, generalized from its
app-specific enum.)

### 5.7 Disposal safety

Every notification goes through a `_safeNotify()` that no-ops after `dispose()` (async
continuations outlive controllers — this was a real production bug the reference fixed).
All pending futures complete (not error) on dispose. `KeyspotScope` disposes nothing it
didn't create; controller lifetime belongs to the user.

### 5.8 Accessibility & i18n (required for 1.0, stub in 0.1)

- Respect `MediaQuery.disableAnimations`: skip glides (jump-cut pointer), stop ring pulsing,
  keep dim/cut-out.
- `Semantics` announcement on spotlight show (`SemanticsService.announce`) with an optional
  `semanticLabel` per spotlight/step; barrier is `Semantics(excludeSemantics: …)` per mode.
- RTL: `Anchor` alignments resolve via `AlignmentDirectional` when the user passes one;
  built-in hand offers `flipForRtl: true`.

---

## 6. Explicit Fix List (bugs in the reference that must NOT be ported)

1. Degrees/radians magnitude guessing (`abs() > 2π`, `6.28`, literal `3.14159`) → `Rotation` type.
2. Rotation snap-to-zero via keyed `TweenAnimationBuilder` → persistent controller.
3. `reachedDestination` set before glide completes → phase transitions tied to controller status.
4. Dead color branch (both arms returned teal) → theme-driven `dotColor/arrivedDotColor`.
5. First-show glide from `Offset.zero` → mount-at-anchor.
6. `Future.delayed(16ms)` frame hacks → `endOfFrame`.
7. Screen-fraction pointer sizing → fixed logical px via `PointerStyle.size`.
8. Unconditional `debugPrint` → injected logger, silent default.
9. Hard-coded app types/colors/assets/config (`PressableContainer`, `AppColors`, SVGs,
   `AppConfig.isPersonalMode`) → `SpotShape.auto`, `KeyspotTheme`, painted hand, `retryFrames` param.
10. `IgnorePointer`-everything (taps leak through the dim layer) → `SpotBarrier`, default `block`.

---

## 7. Testing Plan (target ≥ 85% line coverage on `src/core` + `src/widgets`)

**Widget tests** (the bulk — use `tester.pump` with explicit durations):
- Geometry: spotlight rect matches target for center/offset targets; alignment math for all 9
  `Alignment` constants; padding inflation.
- **Drift:** target inside a `ListView`; scroll 200px; assert cut-out follows within one frame
  (this is the headline feature — test it hard, including target scrolled out then back).
- Shape resolution: `auto` on circular / rounded / rectangular targets; custom path builder.
- Barrier: each `SpotBarrier` mode's hit-testing (taps inside vs outside the cut-out;
  `targetOnly` forwards to the real button — assert its `onPressed` fires).
- Pointer: `moveTo` future completes exactly at duration end; second `moveTo` mid-flight
  cancels and retargets smoothly; rotation animates from current angle; `show` doesn't glide;
  `tapPulse` count; hide detaches.
- Tours: next/previous/skip; `advance` modes; `TourResult`s; storage `markSeen` called once.
- Hardening: target key never resolves (retry exhaustion → future resolves, nothing painted);
  target unmounted mid-spotlight (graceful fade); controller disposed mid-glide (no throw —
  regression test for `_safeNotify`); `spotlight()` called while active (replacement rule).
- Accessibility: `disableAnimations` short-circuits glides; semantics announced.
- Theme: resolution order (param > scope > ThemeExtension > default).

**Golden tests** (macOS CI runner, `flutter test --update-goldens` workflow documented):
spotlight circle/rrect/custom + rings at pulse extremes; built-in hand at 0°/−95°; barrier
opacity.

**Unit tests:** `Rotation` conversions; `Anchor` math; `SpotShape.auto` resolver on synthetic
render trees.

---

## 8. Example App & Demo Site

`example/` is one Flutter app with a home grid of demo pages — each maps to a §2 use case:
`basic_spotlight`, `shapes_gallery`, `pointer_playground` (sliders for duration/curve/rotation,
buttons to trigger show/move/sweep/tapPulse), `scrolling_list`, `drift_torture_test`
(spotlight active while an animated layout constantly reflows — the money demo),
`full_tour` (7-step tour with content cards, skip/back), `gesture_teaching` (drag + pinch
with overlay widget), `theming` (dark/light, custom hand via emoji + Lottie-style widget).

**Demo site:** build `example` for web → deploy to GitHub Pages via CI on tag. Link it at the
top of the README. Record 4 GIFs from it for the README: drift test, pointer sweep, tour,
custom shapes. GIFs are the marketing — budget real time for them.

---

## 9. Repository, CI, Quality Gates

- `analysis_options.yaml`: `package:flutter_lints/flutter.yaml` + `public_member_api_docs: true`
  (every public member documented — enforced).
- CI (GitHub Actions, on PR + main): `dart format --set-exit-if-changed` → `flutter analyze`
  → `flutter test --coverage` → `dart pub publish --dry-run` → `pana` (fail under 140/160
  initially; ratchet to max). Second job: build example for web (artifact = demo deploy).
- Conventional commits; CHANGELOG kept by hand per release (pub.dev renders it).
- Issue templates (bug/feature), PR template, `CONTRIBUTING.md` with golden-test instructions.

## 10. pubspec Presentation

`description` (60–180 chars): "Drift-free spotlight highlights and animated hand-pointer
gestures for onboarding and feature tours. Anchored to GlobalKeys, tracked live every frame."
`topics`: [onboarding, showcase, tutorial, spotlight, walkthrough]. `screenshots`: 3 entries
(spotlight, pointer, tour). `funding`/`repository`/`issue_tracker`/`homepage` (demo site) set.
Set up a **verified publisher** if you own a domain; otherwise publish under your account and
migrate later.

## 11. Roadmap

| Version | Scope |
|---------|-------|
| 0.1.0 | Controller, scope, spotlight (shapes, rings, barrier, until/duration), pointer (show/moveTo/sweep/tapPulse/hide, rotation), AnchorTracker public, theming, logger. Tests §7 core. |
| 0.2.0 | Tours + storage interface, scroll-into-view, step content builders. |
| 0.3.0 | Accessibility complete (reduced motion, semantics, RTL), `MotionPath.arc`, TrackingMode options. |
| 0.9.0 | API freeze; docs site pass; golden suite complete; pana 160/160. |
| 1.0.0 | After ≥ 4 weeks of 0.9 issue triage, breaking feedback folded in. |

**Definition of done for 0.1.0:** all §7 core tests green on CI; example app runs on Android,
iOS, web, macOS; README with GIFs + 30-second quick-start; every public member documented;
`dart pub publish --dry-run` clean; pana ≥ 140.

## 12. Prerequisites (before the first commit)

1. **Written employer approval** to publish a clean-room package in this problem space (the
   reference implementation was authored in an employer codebase — do not copy code from it).
2. pub.dev name availability confirmed; GitHub repo `keyspot` created (MIT, personal account).
3. This spec committed as `SPEC.md` in the new repo — implementation PRs reference its sections.

---

*End of spec. To build: create the empty Flutter package repo, add this file as SPEC.md, and
implement in roadmap order — §3 API first as compile-only stubs, then §5 internals, then §7
tests per feature, then §8 example.*
