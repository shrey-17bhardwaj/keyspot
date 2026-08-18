import 'package:flutter/widgets.dart';

/// How the dimmed area around a spotlight responds to touches.
///
/// The default is [SpotBarrier.block], which absorbs every tap outside the
/// cut-out so users cannot wander off mid-onboarding.
sealed class SpotBarrier {
  /// Const constructor for subclasses.
  const SpotBarrier();

  /// Taps pass straight through the overlay everywhere.
  const factory SpotBarrier.passthrough() = SpotBarrierPassthrough;

  /// Taps outside the cut-out are absorbed; the cut-out is not interactive.
  ///
  /// This is the default.
  const factory SpotBarrier.block() = SpotBarrierBlock;

  /// Tapping dismisses the spotlight.
  ///
  /// When [SpotBarrierDismissOnTap.outsideOnly] is true (the default) only taps
  /// outside the cut-out dismiss; taps on the cut-out are absorbed.
  const factory SpotBarrier.dismissOnTap({bool outsideOnly}) =
      SpotBarrierDismissOnTap;

  /// Only the cut-out is tappable.
  ///
  /// The real widget underneath receives the tap, and the spotlight resolves.
  /// Use this for "the user must actually perform this step" walkthroughs.
  const factory SpotBarrier.targetOnly({VoidCallback? onTargetTap}) =
      SpotBarrierTargetOnly;
}

/// See [SpotBarrier.passthrough].
final class SpotBarrierPassthrough extends SpotBarrier {
  /// Creates a pass-through barrier.
  const SpotBarrierPassthrough();

  @override
  bool operator ==(Object other) => other is SpotBarrierPassthrough;

  @override
  int get hashCode => (SpotBarrierPassthrough).hashCode;
}

/// See [SpotBarrier.block].
final class SpotBarrierBlock extends SpotBarrier {
  /// Creates a blocking barrier.
  const SpotBarrierBlock();

  @override
  bool operator ==(Object other) => other is SpotBarrierBlock;

  @override
  int get hashCode => (SpotBarrierBlock).hashCode;
}

/// See [SpotBarrier.dismissOnTap].
final class SpotBarrierDismissOnTap extends SpotBarrier {
  /// Creates a dismiss-on-tap barrier.
  const SpotBarrierDismissOnTap({this.outsideOnly = true});

  /// Whether only taps outside the cut-out dismiss the spotlight.
  final bool outsideOnly;

  @override
  bool operator ==(Object other) =>
      other is SpotBarrierDismissOnTap && other.outsideOnly == outsideOnly;

  @override
  int get hashCode => Object.hash(SpotBarrierDismissOnTap, outsideOnly);
}

/// See [SpotBarrier.targetOnly].
final class SpotBarrierTargetOnly extends SpotBarrier {
  /// Creates a target-only barrier.
  const SpotBarrierTargetOnly({this.onTargetTap});

  /// Invoked when the user taps inside the cut-out, just before the spotlight
  /// resolves.
  final VoidCallback? onTargetTap;

  @override
  bool operator ==(Object other) =>
      other is SpotBarrierTargetOnly && other.onTargetTap == onTargetTap;

  @override
  int get hashCode => Object.hash(SpotBarrierTargetOnly, onTargetTap);
}
