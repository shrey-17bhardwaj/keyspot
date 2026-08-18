/// Spotlights and guided hand gestures for Flutter — anchored to a
/// [GlobalKey], tracked live every frame, never drifting.
///
/// Two ideas carry the package:
///
/// 1. **Drift-free tracking.** The spotlight and the pointer re-resolve their
///    target's geometry continuously, so they follow the widget through
///    scrolling, keyboard insets, rotation, and window resizing instead of
///    painting a stale snapshot.
/// 2. **Gesture choreography.** An animated hand that appears, glides between
///    targets, rotates and pulses — teaching *gestures*, not just locations.
///
/// Getting started:
///
/// ```dart
/// final KeyspotController keyspot = KeyspotController();
/// final GlobalKey composeKey = GlobalKey();
///
/// KeyspotScope(
///   controller: keyspot,
///   child: MaterialApp(home: Inbox(composeKey: composeKey)),
/// );
///
/// // Highlight a button for two seconds:
/// await keyspot.spotlight(composeKey);
///
/// // Or hold it for exactly as long as an action runs:
/// await keyspot.spotlight(composeKey, until: () => playNarration());
///
/// // Teach a drag:
/// await keyspot.pointer.sweep(cardKey.anchor(), archiveKey.anchor());
/// ```
library;

export 'src/core/anchor.dart';
export 'src/core/anchor_tracker.dart';
export 'src/core/keyspot_controller.dart';
export 'src/core/keyspot_host.dart';
export 'src/core/lifecycle_observer.dart';
export 'src/core/pointer_state.dart';
export 'src/core/spot_barrier.dart';
export 'src/core/spot_shape.dart';
export 'src/core/spotlight_state.dart';
export 'src/theme/keyspot_theme.dart';
export 'src/theme/pointer_style.dart';
export 'src/theme/ring_style.dart';
export 'src/tour/tour.dart';
export 'src/tour/tour_session.dart';
export 'src/tour/tour_storage.dart';
export 'src/util/log.dart';
export 'src/util/scroll_into_view.dart';
export 'src/util/shape_resolver.dart';
export 'src/widgets/barrier_layer.dart';
export 'src/widgets/default_hand_painter.dart';
export 'src/widgets/keyspot_scope.dart';
export 'src/widgets/pointer_overlay.dart';
export 'src/widgets/spotlight_overlay.dart';
export 'src/widgets/spotlight_painter.dart';
