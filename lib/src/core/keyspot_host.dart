import 'package:flutter/widgets.dart';

import '../theme/pointer_style.dart';
import 'anchor.dart';
import 'pointer_state.dart';
import 'spotlight_state.dart';

/// The overlay side of the spotlight, implemented by `KeyspotScope`'s internal
/// overlay and registered with the controller when it mounts.
///
/// Split out as an interface so tests can drive a controller without building
/// a widget tree.
abstract interface class SpotlightHost {
  /// Whether a spotlight is currently on screen.
  bool get isPresenting;

  /// The theme's fallback spotlight duration, resolved in the overlay's
  /// context.
  Duration get defaultSpotlightDuration;

  /// Presents [request]; the future completes when the entry animation ends.
  ///
  /// Calling this while another spotlight is presenting replaces it.
  Future<void> present(SpotlightRequest request);

  /// Fades the current spotlight out; the future completes when it is gone.
  Future<void> dismiss();
}

/// The overlay side of the pointer, implemented by `KeyspotScope`'s internal
/// overlay and registered with the controller when it mounts.
abstract interface class PointerHost {
  /// Whether the pointer is currently mounted and visible.
  bool get isVisible;

  /// What the pointer is currently doing.
  PointerPhase get phase;

  /// Mounts the pointer at [at] with a fade and scale in.
  Future<void> show(Anchor at, {PointerStyle? style, Rotation? rotation});

  /// Glides the pointer to [to].
  Future<void> moveTo(
    Anchor to, {
    required Duration duration,
    required Curve curve,
    Rotation? rotation,
    required MotionPath path,
  });

  /// Plays [count] tap animations at the pointer's current position.
  Future<void> tapPulse({required int count});

  /// Fades the pointer out and detaches it.
  Future<void> hide();
}
