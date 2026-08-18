import 'package:flutter/widgets.dart';

/// Information handed to the resume handler when the app returns to the
/// foreground while a spotlight or tour step is still active.
///
/// Use it to replay narration, restart an animation, or re-assert whatever the
/// step was teaching.
@immutable
class KeyspotResumeContext {
  /// Creates a resume context.
  const KeyspotResumeContext({
    required this.targetKey,
    this.stepId,
    this.tourId,
  });

  /// The key of the widget currently spotlit.
  final GlobalKey targetKey;

  /// The id of the active tour step, if the spotlight belongs to a tour.
  final String? stepId;

  /// The id of the active tour, if any.
  final String? tourId;

  @override
  String toString() =>
      'KeyspotResumeContext(step: $stepId, tour: $tourId, target: $targetKey)';
}

/// Forwards [AppLifecycleState.resumed] to [onResumed].
///
/// Registered by [KeyspotController] only while a resume handler is set, so
/// apps that do not use the feature pay nothing.
class KeyspotLifecycleObserver with WidgetsBindingObserver {
  /// Creates an observer that calls [onResumed] when the app is resumed.
  KeyspotLifecycleObserver(this.onResumed);

  /// Called on every transition to [AppLifecycleState.resumed].
  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
