import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/ring_style.dart';
import 'spot_barrier.dart';
import 'spot_shape.dart';

/// Signature for extra content drawn over an active spotlight.
///
/// [targetRect] is the live cut-out rect in overlay coordinates, so tooltips
/// and captions positioned from it follow the target exactly as the cut-out
/// does.
typedef SpotlightOverlayBuilder = Widget Function(
  BuildContext context,
  Rect targetRect,
);

/// An immutable description of one spotlight.
///
/// Instances are created by [KeyspotController.spotlight] and by the tour
/// engine; overlays read them and never mutate them.
@immutable
class SpotlightRequest {
  /// Creates a spotlight request.
  const SpotlightRequest({
    required this.targetKey,
    this.shape = const SpotShape.auto(),
    this.padding = const EdgeInsets.all(12.0),
    this.rings,
    this.barrier = const SpotBarrier.block(),
    this.overlayBuilder,
    this.semanticLabel,
    this.stepId,
  });

  /// The key of the widget to cut out.
  final GlobalKey targetKey;

  /// The outline of the cut-out.
  final SpotShape shape;

  /// How far the cut-out is inflated beyond the target's bounds.
  final EdgeInsets padding;

  /// The rings drawn around the cut-out.
  ///
  /// Null means "use the theme's rings"; an empty list means "no rings".
  final List<RingStyle>? rings;

  /// How the dimmed area responds to touches.
  final SpotBarrier barrier;

  /// Optional content drawn above the dim layer.
  final SpotlightOverlayBuilder? overlayBuilder;

  /// Announced to screen readers when the spotlight appears.
  final String? semanticLabel;

  /// The tour step this spotlight belongs to, if any.
  ///
  /// Surfaced again through [KeyspotResumeContext] when the app resumes.
  final String? stepId;

  /// Returns a copy of this request with the given fields replaced.
  SpotlightRequest copyWith({
    GlobalKey? targetKey,
    SpotShape? shape,
    EdgeInsets? padding,
    List<RingStyle>? rings,
    SpotBarrier? barrier,
    SpotlightOverlayBuilder? overlayBuilder,
    String? semanticLabel,
    String? stepId,
  }) {
    return SpotlightRequest(
      targetKey: targetKey ?? this.targetKey,
      shape: shape ?? this.shape,
      padding: padding ?? this.padding,
      rings: rings ?? this.rings,
      barrier: barrier ?? this.barrier,
      overlayBuilder: overlayBuilder ?? this.overlayBuilder,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      stepId: stepId ?? this.stepId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SpotlightRequest &&
        other.targetKey == targetKey &&
        other.shape == shape &&
        other.padding == padding &&
        listEquals(other.rings, rings) &&
        other.barrier == barrier &&
        other.overlayBuilder == overlayBuilder &&
        other.semanticLabel == semanticLabel &&
        other.stepId == stepId;
  }

  @override
  int get hashCode => Object.hash(
        targetKey,
        shape,
        padding,
        rings == null ? null : Object.hashAll(rings!),
        barrier,
        overlayBuilder,
        semanticLabel,
        stepId,
      );

  @override
  String toString() => 'SpotlightRequest($targetKey, $shape)';
}

/// Why a spotlight stopped.
enum SpotlightOutcome {
  /// Its `until` future completed, or its duration elapsed.
  finished,

  /// The user dismissed it through the barrier.
  dismissedByUser,

  /// The target was tapped under [SpotBarrier.targetOnly].
  targetTapped,

  /// It was replaced by another spotlight, hidden programmatically, or the
  /// controller was disposed.
  cancelled,
}
