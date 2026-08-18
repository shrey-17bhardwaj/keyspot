## 0.3.0

Implements the full 0.1–0.3 surface described in `SPEC.md`. The package is
feature-complete and unpublished; the API may still move before 1.0.

### Spotlight

- `KeyspotController.spotlight()` with `SpotShape.auto/circle/rrect/stadium/path`,
  configurable ring stacks, and per-ring opacity pulses.
- Action-scoped spotlights via `until:`, timed via `duration:`, or held until
  `hideSpotlight()`.
- `SpotBarrier` with `passthrough`, `block` (default), `dismissOnTap` and
  `targetOnly` — the last forwards the tap to the real widget and resolves.
- Automatic scroll-into-view before the spotlight appears.
- Graceful fade-out and future resolution when the target unmounts mid-spotlight.

### Pointer

- `KeyspotPointer.show/moveTo/sweep/tapPulse/hide`, every future completing on
  real animation completion rather than a guessed delay.
- Rotation as an explicit `Rotation.degrees/radians` value type, animated from
  the current angle along the shortest path.
- `MotionPath.line` and `MotionPath.arc` trajectories.
- Built-in `CustomPainter` hand with no assets, replaceable by any widget
  through `PointerStyle.builder`.

### Tours

- `KeyspotTour`, `KeyspotStep`, `TourSession` with `next/previous/skip`.
- `StepAdvance.tapTarget/tapAnywhere/manual/after(duration)`, each mapping to a
  sensible default barrier.
- `KeyspotTourStorage` interface plus `InMemoryTourStorage`; plug your own
  persistence in.
- Step content cards positioned automatically above or below the cut-out.

### Tracking and accessibility

- `KeyspotAnchorTracker` exposed publicly with `TrackingMode.everyFrame`,
  `onScrollAndMetrics` and `once`.
- Reduced motion honoured through `MediaQuery.disableAnimations`.
- `semanticLabel` announcements, RTL-aware alignments, and `flipForRtl` artwork.

### Foundations

- `KeyspotTheme` as a `ThemeExtension`, resolved parameter → scope → theme →
  defaults.
- Injected logger, silent by default.
- Disposal-safe notifications: every pending future completes rather than
  erroring.

## 0.0.1

- Initial development preview. Claims the package name and publishes the planned
  API surface (see README). First functional release will be 0.1.0.
