# keyspot

**Spotlights and guided hand gestures for Flutter — anchored to a GlobalKey, tracked live, never drifting.**

> ⚠️ **Early development preview (0.0.x).** The API described below is being implemented now;
> the first usable release is `0.1.0`, expected within days. Follow the repository for progress.

## Why keyspot?

Every onboarding package can dim the screen and punch a hole over a widget. Keyspot does two
things the others don't:

1. **Drift-free tracking.** The spotlight and pointer re-resolve the target's geometry every
   frame, so they follow the widget through scrolling, keyboard insets, orientation changes,
   and window resizing — instead of painting a stale one-shot snapshot.
2. **Gesture choreography.** An animated hand pointer that appears, glides between targets,
   rotates, and pulses — teaching *gestures* ("drag this here"), not just *locations*
   ("look here").

Everything is driven by `GlobalKey`s. No coordinates, no manual measurement, no wrapper
widgets around every target.

## Planned API (0.1.0)

```dart
final keyspot = KeyspotController();

KeyspotScope(
  controller: keyspot,
  child: MaterialApp(...),
);

// Spotlight a widget, hold it while an action runs:
await keyspot.spotlight(
  buttonKey,
  shape: const SpotShape.auto(),
  until: () => playNarration(),
);

// Teach a drag gesture:
await keyspot.pointer.sweep(
  cardKey.anchor(),
  archiveColumnKey.anchor(),
  duration: const Duration(milliseconds: 800),
);
```

## Roadmap

- `0.1.0` — spotlight (shapes, rings, barriers), hand pointer, live anchor tracking, theming
- `0.2.0` — multi-step tours, scroll-into-view
- `0.3.0` — reduced-motion & semantics support, arc motion paths

## License

MIT © Shreyash Bhardwaj
