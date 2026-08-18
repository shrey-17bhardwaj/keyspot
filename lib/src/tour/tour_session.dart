import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/keyspot_controller.dart';
import '../core/spot_barrier.dart';
import '../core/spotlight_state.dart';
import 'tour.dart';

enum _StepIntent { next, previous, skip }

/// A tour in progress.
///
/// Handed to [KeyspotStep.onEnter] and to every step's content builder so they
/// can drive navigation:
///
/// ```dart
/// contentBuilder: (BuildContext context, Rect rect, TourSession session) {
///   return Row(
///     children: <Widget>[
///       TextButton(onPressed: session.previous, child: const Text('Back')),
///       TextButton(onPressed: session.next, child: const Text('Next')),
///       TextButton(onPressed: session.skip, child: const Text('Skip')),
///     ],
///   );
/// }
/// ```
class TourSession {
  /// Creates a session. Created for you by [KeyspotController.startTour].
  TourSession({required this.controller, required this.tour});

  /// The controller running this tour.
  final KeyspotController controller;

  /// The tour being run.
  final KeyspotTour tour;

  final ValueNotifier<int> _index = ValueNotifier<int>(0);
  Completer<void>? _manualGate;
  _StepIntent? _intent;
  bool _running = false;

  /// The index of the active step.
  int get index => _index.value;

  /// The active step.
  KeyspotStep get step => tour.steps[_index.value];

  /// How many steps this tour has.
  int get stepCount => tour.steps.length;

  /// Whether the active step is the last one.
  bool get isLast => _index.value >= tour.steps.length - 1;

  /// Whether the active step is the first one.
  bool get isFirst => _index.value == 0;

  /// Notifies whenever the active step changes, for rebuilding progress dots.
  ValueListenable<int> get indexListenable => _index;

  /// Advances to the next step, ending the tour if this was the last one.
  Future<void> next() => _signal(_StepIntent.next);

  /// Returns to the previous step. A no-op on the first step.
  Future<void> previous() => _signal(_StepIntent.previous);

  /// Ends the tour early with [TourResult.skipped].
  Future<void> skip() => _signal(_StepIntent.skip);

  Future<void> _signal(_StepIntent intent) async {
    if (!_running) {
      return;
    }
    _intent = intent;
    final Completer<void>? gate = _manualGate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
      return;
    }
    await controller.hideSpotlight();
  }

  /// Runs the tour to completion. Called by [KeyspotController.startTour].
  Future<TourResult> run() async {
    if (tour.steps.isEmpty) {
      return TourResult.completed;
    }
    _running = true;
    _index.value = 0;
    try {
      while (true) {
        final KeyspotStep current = tour.steps[_index.value];
        _intent = null;
        final bool isManual = current.advance is StepAdvanceManual;
        _manualGate = isManual ? Completer<void>() : null;

        if (current.onEnter != null) {
          try {
            await current.onEnter!(this);
          } catch (error) {
            // A failing onEnter must not strand the user inside a tour.
            debugPrint('keyspot: step ${current.id} onEnter failed: $error');
          }
          if (controller.isDisposed) {
            return TourResult.cancelled;
          }
        }

        final StepAdvance advance = current.advance;
        final SpotlightOutcome outcome = await controller.spotlight(
          current.targetKey,
          shape: current.shape,
          padding: current.padding,
          rings: current.rings,
          barrier: current.barrier ?? _barrierFor(advance),
          overlayBuilder: _overlayBuilderFor(current),
          until: isManual ? () => _manualGate!.future : null,
          duration: advance is StepAdvanceAfter ? advance.duration : null,
          scrollIntoView: current.scrollIntoView,
          semanticLabel: current.semanticLabel,
          stepId: current.id,
        );

        if (controller.isDisposed) {
          return TourResult.cancelled;
        }

        _StepIntent? intent = _intent;
        if (intent == null) {
          if (isManual && outcome == SpotlightOutcome.dismissedByUser) {
            return TourResult.skipped;
          }
          // Barrier tap, timer, or an unresolvable target: move on.
          intent = _StepIntent.next;
        }

        switch (intent) {
          case _StepIntent.skip:
            return TourResult.skipped;
          case _StepIntent.previous:
            if (_index.value > 0) {
              _index.value -= 1;
            }
          case _StepIntent.next:
            if (_index.value >= tour.steps.length - 1) {
              return TourResult.completed;
            }
            _index.value += 1;
        }
      }
    } finally {
      _running = false;
      _manualGate = null;
    }
  }

  SpotBarrier _barrierFor(StepAdvance advance) {
    switch (advance) {
      case StepAdvanceTapTarget():
        return const SpotBarrier.targetOnly();
      case StepAdvanceTapAnywhere():
        return const SpotBarrier.dismissOnTap(outsideOnly: false);
      case StepAdvanceManual():
        return tour.barrierSkippable
            ? const SpotBarrier.dismissOnTap()
            : const SpotBarrier.block();
      case StepAdvanceAfter():
        return const SpotBarrier.block();
    }
  }

  SpotlightOverlayBuilder? _overlayBuilderFor(KeyspotStep step) {
    final KeyspotStepContentBuilder? builder = step.contentBuilder;
    if (builder == null) {
      return null;
    }
    return (BuildContext context, Rect rect) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool below = switch (step.contentPosition) {
            KeyspotContentPosition.above => false,
            KeyspotContentPosition.below => true,
            KeyspotContentPosition.auto =>
              rect.center.dy < constraints.maxHeight / 2.0,
          };
          return Stack(
            children: <Widget>[
              Positioned(
                left: 16.0,
                right: 16.0,
                top: below ? rect.bottom + 16.0 : null,
                bottom:
                    below ? null : (constraints.maxHeight - rect.top) + 16.0,
                child: builder(context, rect, this),
              ),
            ],
          );
        },
      );
    };
  }

  /// Releases the session's listenable. Called by the controller.
  void dispose() {
    _index.dispose();
  }
}
