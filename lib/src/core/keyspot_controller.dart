import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/pointer_style.dart';
import '../theme/ring_style.dart';
import '../tour/tour.dart';
import '../tour/tour_session.dart';
import '../tour/tour_storage.dart';
import '../util/log.dart';
import '../util/scroll_into_view.dart';
import 'anchor.dart';
import 'anchor_tracker.dart';
import 'keyspot_host.dart';
import 'lifecycle_observer.dart';
import 'pointer_state.dart';
import 'spot_barrier.dart';
import 'spot_shape.dart';
import 'spotlight_state.dart';

part 'keyspot_pointer.dart';

/// The single entry point for driving keyspot.
///
/// Create one, hand it to a `KeyspotScope`, and call [spotlight], [pointer] and
/// [startTour] from anywhere that can reach it. The controller owns no widgets;
/// the scope's overlays register themselves with it when they mount.
///
/// ```dart
/// final KeyspotController keyspot = KeyspotController();
///
/// KeyspotScope(
///   controller: keyspot,
///   child: MaterialApp(home: HomePage()),
/// );
///
/// await keyspot.spotlight(composeButtonKey);
/// ```
///
/// The controller's lifetime belongs to you: call [dispose] when you are done
/// with it. Disposing mid-animation is safe — every pending future completes
/// rather than erroring, and no notification fires after disposal.
class KeyspotController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// Pass [logger] to observe what keyspot is doing; by default the package is
  /// completely silent. [KeyspotLoggers.debug] forwards to [debugPrint].
  KeyspotController({KeyspotLog? logger})
      : _log = logger ?? KeyspotLoggers.silent {
    _pointer = KeyspotPointer._(this);
  }

  final KeyspotLog _log;
  late final KeyspotPointer _pointer;

  SpotlightHost? _spotlightHost;
  PointerHost? _pointerHost;

  bool _disposed = false;

  SpotlightRequest? _activeRequest;
  Completer<SpotlightOutcome>? _activeCompleter;
  Completer<void>? _dismissalCompleter;
  int _generation = 0;

  void Function(KeyspotResumeContext context)? _resumeHandler;
  KeyspotLifecycleObserver? _lifecycleObserver;

  TourSession? _activeTour;

  /// The pointer facade — show, glide, pulse and hide the animated hand.
  KeyspotPointer get pointer => _pointer;

  /// The spotlight currently on screen, or null when none is active.
  SpotlightRequest? get activeSpotlight => _activeRequest;

  /// Whether a spotlight is currently active.
  bool get isSpotlightActive => _activeRequest != null;

  /// The running tour, or null when no tour is running.
  TourSession? get activeTour => _activeTour;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  // ---------------------------------------------------------------- spotlight

  /// Dims the screen and cuts a spotlight around [key].
  ///
  /// The returned future completes when the spotlight is dismissed — by
  /// [until] finishing, by [duration] elapsing, by a barrier interaction, by
  /// [hideSpotlight], by a replacing spotlight, or by [dispose]. It never
  /// throws and never hangs: if the target cannot be resolved within
  /// [retryFrames] frames, or no `KeyspotScope` is mounted, it completes with
  /// [SpotlightOutcome.cancelled] and nothing is painted.
  ///
  /// Calling this while another spotlight is active cancels the old one first —
  /// there are never two at once.
  ///
  /// * [shape] defaults to [SpotShape.auto], which mirrors the target's own
  ///   rounding where it can be detected.
  /// * [rings] of null means "use the theme's rings"; pass `const <RingStyle>[]`
  ///   for none.
  /// * [until] makes the spotlight action-scoped: it is held for exactly as
  ///   long as the supplied future runs. When [until] is given, [duration] is
  ///   ignored.
  /// * [duration] falls back to `KeyspotTheme.defaultSpotlightDuration`.
  /// * [scrollIntoView] only works when the target widget is already built:
  ///   lazily-built lists (`ListView.builder`) do not build far-off-screen
  ///   rows, so their keys have no context to scroll to and the spotlight
  ///   completes with [SpotlightOutcome.cancelled]. Scroll near the target
  ///   yourself first, or use a non-lazy scroll view for tour targets.
  Future<SpotlightOutcome> spotlight(
    GlobalKey key, {
    SpotShape shape = const SpotShape.auto(),
    EdgeInsets padding = const EdgeInsets.all(12.0),
    List<RingStyle>? rings,
    SpotBarrier barrier = const SpotBarrier.block(),
    SpotlightOverlayBuilder? overlayBuilder,
    Future<void> Function()? until,
    Duration? duration,
    bool scrollIntoView = true,
    Duration scrollDuration = const Duration(milliseconds: 300),
    String? semanticLabel,
    String? stepId,
    int retryFrames = 3,
  }) async {
    if (_disposed) {
      return SpotlightOutcome.cancelled;
    }

    final int generation = ++_generation;
    _completeActive(SpotlightOutcome.cancelled);

    if (scrollIntoView) {
      await ensureTargetVisible(key, duration: scrollDuration);
      if (_isStale(generation)) {
        return SpotlightOutcome.cancelled;
      }
    }

    final RenderBox? box =
        await resolveTargetBox(key, retryFrames: retryFrames);
    if (_isStale(generation)) {
      return SpotlightOutcome.cancelled;
    }
    if (box == null) {
      _log('spotlight: target for $key never resolved; nothing painted');
      return SpotlightOutcome.cancelled;
    }

    final SpotlightHost? host = _spotlightHost;
    if (host == null) {
      _log('spotlight: no KeyspotScope is mounted; nothing painted');
      return SpotlightOutcome.cancelled;
    }

    final SpotlightRequest request = SpotlightRequest(
      targetKey: key,
      shape: shape,
      padding: padding,
      rings: rings,
      barrier: barrier,
      overlayBuilder: overlayBuilder,
      semanticLabel: semanticLabel,
      stepId: stepId,
    );

    final Completer<SpotlightOutcome> completer = Completer<SpotlightOutcome>();
    final Completer<void> dismissal = Completer<void>();
    _activeRequest = request;
    _activeCompleter = completer;
    _dismissalCompleter = dismissal;
    _safeNotify();
    _log('spotlight: presenting ${stepId ?? key.toString()}');

    // The dismissal triggers are armed while the entry animation is still
    // playing: an `until` that resolves (or a user interaction) mid-entry must
    // dismiss promptly rather than wait the animation out. Only the duration
    // timer waits for the entry, so the advertised hold time is fully visible.
    Timer? timer;
    if (until != null) {
      unawaited(
        Future<void>.sync(until).then<void>(
          (_) {
            if (!_isStale(generation)) {
              _completeActive(SpotlightOutcome.finished);
            }
          },
          onError: (Object error, StackTrace stack) {
            _log('spotlight: until() failed: $error');
            if (!_isStale(generation)) {
              _completeActive(SpotlightOutcome.finished);
            }
          },
        ),
      );
    }
    unawaited(
      host.present(request).then<void>((_) {
        if (until == null && !_isStale(generation) && !completer.isCompleted) {
          timer = Timer(
            duration ?? host.defaultSpotlightDuration,
            () => _completeActive(SpotlightOutcome.finished),
          );
        }
      }),
    );

    final SpotlightOutcome outcome = await completer.future;
    timer?.cancel();

    if (_generation == generation) {
      _activeRequest = null;
      _activeCompleter = null;
      if (!_disposed) {
        _safeNotify();
        await host.dismiss();
      }
    }
    if (!dismissal.isCompleted) {
      dismissal.complete();
    }
    _log('spotlight: resolved as ${outcome.name}');
    return outcome;
  }

  /// Dismisses the active spotlight, if any.
  ///
  /// The returned future completes once the exit animation has finished.
  Future<void> hideSpotlight() async {
    final Completer<void>? dismissal = _dismissalCompleter;
    if (_activeCompleter == null) {
      return;
    }
    _completeActive(SpotlightOutcome.cancelled);
    await dismissal?.future;
  }

  /// Called by the barrier layer when the user dismisses through the dim area.
  ///
  /// Not intended for application code.
  void notifyBarrierDismissed() {
    _completeActive(SpotlightOutcome.dismissedByUser);
  }

  /// Called by the barrier layer when the user taps the cut-out under
  /// [SpotBarrier.targetOnly].
  ///
  /// Not intended for application code.
  void notifyTargetTapped() {
    final SpotBarrier? barrier = _activeRequest?.barrier;
    if (barrier is SpotBarrierTargetOnly) {
      barrier.onTargetTap?.call();
    }
    _completeActive(SpotlightOutcome.targetTapped);
  }

  // -------------------------------------------------------------------- tours

  /// Runs [tour] from its first unseen step to completion.
  ///
  /// Returns how the tour ended. If the tour's storage reports it has already
  /// been seen, returns [TourResult.skipped] without showing anything.
  Future<TourResult> startTour(KeyspotTour tour) async {
    if (_disposed) {
      return TourResult.cancelled;
    }
    if (_activeTour != null) {
      _log('startTour: cancelling the tour already in progress');
      await _activeTour!.skip();
    }
    final KeyspotTourStorage? storage = tour.storage;
    if (storage != null && await storage.wasSeen(tour.id)) {
      _log('startTour: ${tour.id} already seen; skipping');
      return TourResult.skipped;
    }
    final TourSession session = TourSession(controller: this, tour: tour);
    _activeTour = session;
    _safeNotify();
    try {
      final TourResult result = await session.run();
      if (result == TourResult.completed) {
        await storage?.markSeen(tour.id);
      }
      return result;
    } finally {
      if (identical(_activeTour, session)) {
        _activeTour = null;
        _safeNotify();
      }
      session.dispose();
    }
  }

  // ---------------------------------------------------------------- lifecycle

  /// Registers a handler invoked when the app resumes while a spotlight or tour
  /// step is active.
  ///
  /// Pass null to unregister. Use it to replay narration or restart an
  /// animation for the step the user came back to.
  void setResumeHandler(void Function(KeyspotResumeContext context)? handler) {
    _resumeHandler = handler;
    if (handler == null) {
      if (_lifecycleObserver != null) {
        WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
        _lifecycleObserver = null;
      }
      return;
    }
    if (_lifecycleObserver == null) {
      _lifecycleObserver = KeyspotLifecycleObserver(_handleResumed);
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }
  }

  void _handleResumed() {
    final SpotlightRequest? request = _activeRequest;
    final void Function(KeyspotResumeContext)? handler = _resumeHandler;
    if (request == null || handler == null || _disposed) {
      return;
    }
    handler(
      KeyspotResumeContext(
        targetKey: request.targetKey,
        stepId: request.stepId,
        tourId: _activeTour?.tour.id,
      ),
    );
  }

  // ----------------------------------------------------------------- internal

  /// Registers the spotlight overlay. Called by `KeyspotScope`.
  void attachSpotlightHost(SpotlightHost host) => _spotlightHost = host;

  /// Unregisters [host] if it is still the active one. Called by
  /// `KeyspotScope`.
  void detachSpotlightHost(SpotlightHost host) {
    if (identical(_spotlightHost, host)) {
      _spotlightHost = null;
      _completeActive(SpotlightOutcome.cancelled);
    }
  }

  /// Registers the pointer overlay. Called by `KeyspotScope`.
  void attachPointerHost(PointerHost host) => _pointerHost = host;

  /// Unregisters [host] if it is still the active one. Called by
  /// `KeyspotScope`.
  void detachPointerHost(PointerHost host) {
    if (identical(_pointerHost, host)) {
      _pointerHost = null;
    }
  }

  bool _isStale(int generation) => _disposed || _generation != generation;

  void _completeActive(SpotlightOutcome outcome) {
    final Completer<SpotlightOutcome>? completer = _activeCompleter;
    _activeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
  }

  void _safeNotify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    final Completer<SpotlightOutcome>? completer = _activeCompleter;
    _activeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(SpotlightOutcome.cancelled);
    }
    final Completer<void>? dismissal = _dismissalCompleter;
    _dismissalCompleter = null;
    if (dismissal != null && !dismissal.isCompleted) {
      dismissal.complete();
    }
    _activeRequest = null;
    _activeTour = null;
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
    _spotlightHost = null;
    _pointerHost = null;
    super.dispose();
  }
}
