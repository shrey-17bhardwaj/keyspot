import 'package:flutter/widgets.dart';

import '../core/spot_barrier.dart';
import '../core/spot_shape.dart';
import '../theme/ring_style.dart';
import 'tour_session.dart';
import 'tour_storage.dart';

/// How a tour ended.
enum TourResult {
  /// Every step was shown and the last one advanced.
  completed,

  /// The user skipped out, or storage said the tour had already been seen.
  skipped,

  /// The tour was interrupted — the controller was disposed, the scope was
  /// unmounted, or another tour replaced it.
  cancelled,
}

/// What moves a tour from one step to the next.
sealed class StepAdvance {
  /// Const constructor for subclasses.
  const StepAdvance();

  /// Advance when the user taps the spotlit widget itself.
  ///
  /// The tap reaches the real widget, so its own `onPressed` fires too. Use
  /// this for walkthroughs where the user must actually perform each step.
  static const StepAdvance tapTarget = StepAdvanceTapTarget();

  /// Advance when the user taps anywhere. This is the default.
  static const StepAdvance tapAnywhere = StepAdvanceTapAnywhere();

  /// Advance only when [TourSession.next] is called — typically from a "Next"
  /// button in the step's own content card.
  static const StepAdvance manual = StepAdvanceManual();

  /// Advance automatically after [StepAdvanceAfter.duration].
  const factory StepAdvance.after(Duration duration) = StepAdvanceAfter;
}

/// See [StepAdvance.tapTarget].
final class StepAdvanceTapTarget extends StepAdvance {
  /// Creates a tap-the-target advance rule.
  const StepAdvanceTapTarget();
}

/// See [StepAdvance.tapAnywhere].
final class StepAdvanceTapAnywhere extends StepAdvance {
  /// Creates a tap-anywhere advance rule.
  const StepAdvanceTapAnywhere();
}

/// See [StepAdvance.manual].
final class StepAdvanceManual extends StepAdvance {
  /// Creates a manual advance rule.
  const StepAdvanceManual();
}

/// See [StepAdvance.after].
final class StepAdvanceAfter extends StepAdvance {
  /// Creates a timed advance rule.
  const StepAdvanceAfter(this.duration);

  /// How long the step stays up before advancing.
  final Duration duration;
}

/// Where a step's content card is placed relative to the cut-out.
enum KeyspotContentPosition {
  /// Directly above the cut-out.
  above,

  /// Directly below the cut-out.
  below,

  /// Below the cut-out when the target sits in the top half of the screen,
  /// above it otherwise. This is the default.
  auto,
}

/// Signature for a step's content card.
///
/// [targetRect] is the live cut-out rect, and [session] lets the card drive the
/// tour with its own Next / Back / Skip buttons.
typedef KeyspotStepContentBuilder = Widget Function(
  BuildContext context,
  Rect targetRect,
  TourSession session,
);

/// One step of a [KeyspotTour].
@immutable
class KeyspotStep {
  /// Creates a tour step.
  const KeyspotStep({
    required this.id,
    required this.targetKey,
    this.shape = const SpotShape.auto(),
    this.padding = const EdgeInsets.all(12.0),
    this.rings,
    this.barrier,
    this.contentBuilder,
    this.contentPosition = KeyspotContentPosition.auto,
    this.onEnter,
    this.advance = StepAdvance.tapAnywhere,
    this.semanticLabel,
    this.scrollIntoView = true,
  });

  /// A stable identifier, surfaced in [KeyspotResumeContext] and logs.
  final String id;

  /// The widget this step points at.
  final GlobalKey targetKey;

  /// The cut-out outline.
  final SpotShape shape;

  /// How far the cut-out is inflated beyond the target.
  final EdgeInsets padding;

  /// Rings for this step; null uses the theme's.
  final List<RingStyle>? rings;

  /// Overrides the barrier this step would otherwise get from [advance].
  ///
  /// Leave null and keyspot picks a barrier that matches the advance rule:
  /// [StepAdvance.tapTarget] makes only the cut-out tappable,
  /// [StepAdvance.tapAnywhere] dismisses on any tap, and the rest block.
  final SpotBarrier? barrier;

  /// Builds the tooltip or card shown alongside the cut-out.
  final KeyspotStepContentBuilder? contentBuilder;

  /// Where [contentBuilder]'s widget is placed relative to the cut-out.
  final KeyspotContentPosition contentPosition;

  /// Runs when the step becomes active, before the spotlight is shown.
  ///
  /// Use it to play narration or run a pointer choreography. The tour waits for
  /// it. Errors thrown here are caught and logged, not rethrown.
  final Future<void> Function(TourSession session)? onEnter;

  /// What moves the tour past this step.
  final StepAdvance advance;

  /// Announced to screen readers when the step appears.
  final String? semanticLabel;

  /// Whether to scroll the target into view first.
  final bool scrollIntoView;
}

/// An ordered sequence of [KeyspotStep]s.
@immutable
class KeyspotTour {
  /// Creates a tour.
  const KeyspotTour({
    required this.id,
    required this.steps,
    this.barrierSkippable = true,
    this.storage,
  });

  /// A stable identifier, used as the persistence key.
  final String id;

  /// The steps, in order.
  final List<KeyspotStep> steps;

  /// Whether tapping the dim area skips out of a [StepAdvance.manual] step.
  ///
  /// Has no effect on steps whose advance rule already consumes taps.
  final bool barrierSkippable;

  /// Where "has this tour been seen" is recorded.
  ///
  /// Null means the tour runs every time it is started.
  final KeyspotTourStorage? storage;
}
