part of 'keyspot_controller.dart';

/// Choreographs the animated hand pointer.
///
/// Reached through [KeyspotController.pointer]; never constructed directly.
/// Every method is safe to call when no `KeyspotScope` is mounted — the call is
/// logged and the future completes immediately rather than hanging.
///
/// ```dart
/// await keyspot.pointer.show(cardKey.anchor());
/// await keyspot.pointer.moveTo(
///   archiveKey.anchor(),
///   path: const MotionPath.arc(height: 0.3),
/// );
/// await keyspot.pointer.tapPulse();
/// await keyspot.pointer.hide();
/// ```
class KeyspotPointer {
  KeyspotPointer._(this._controller);

  final KeyspotController _controller;

  PointerHost? get _host => _controller._pointerHost;

  /// Whether the pointer is currently on screen.
  bool get isVisible => _host?.isVisible ?? false;

  /// What the pointer is currently doing.
  ///
  /// [PointerPhase.arrived] is set exactly when a glide animation completes,
  /// never optimistically before it.
  PointerPhase get phase => _host?.phase ?? PointerPhase.idle;

  /// Shows the pointer at [at] with a fade and scale in.
  ///
  /// The pointer is mounted directly at the anchor — it never glides in from
  /// the top-left corner. A no-op if it is already visible, except that [style]
  /// and [rotation] are still applied.
  Future<void> show(
    Anchor at, {
    PointerStyle? style,
    Rotation? rotation,
  }) async {
    final PointerHost? host = _host;
    if (host == null) {
      _controller._log('pointer.show ignored: no KeyspotScope is mounted');
      return;
    }
    await host.show(at, style: style, rotation: rotation);
  }

  /// Glides the pointer to [to].
  ///
  /// The returned future completes when the animation actually finishes — not
  /// after a guessed delay. A subsequent [moveTo] or [hide] cancels this glide;
  /// the cancelled future still completes (it never throws), it simply
  /// completes early.
  ///
  /// [rotation] animates from the pointer's current angle along the shortest
  /// path, so the hand never snaps back to zero first.
  Future<void> moveTo(
    Anchor to, {
    Duration duration = const Duration(milliseconds: 800),
    Curve curve = Curves.easeInOutCubic,
    Rotation? rotation,
    MotionPath path = MotionPath.line,
  }) async {
    final PointerHost? host = _host;
    if (host == null) {
      _controller._log('pointer.moveTo ignored: no KeyspotScope is mounted');
      return;
    }
    await host.moveTo(
      to,
      duration: duration,
      curve: curve,
      rotation: rotation,
      path: path,
    );
  }

  /// Shows the pointer at [from], glides it to [to], optionally taps and
  /// dwells, then hides it.
  ///
  /// This is the one-liner for teaching a drag: "pick this up, put it there".
  Future<void> sweep(
    Anchor from,
    Anchor to, {
    Duration duration = const Duration(milliseconds: 800),
    Duration dwell = const Duration(milliseconds: 400),
    Curve curve = Curves.easeInOutCubic,
    Rotation? rotation,
    MotionPath path = MotionPath.line,
    PointerStyle? style,
    bool tapOnArrival = false,
    bool hideAfter = true,
  }) async {
    await show(from, style: style, rotation: rotation);
    await moveTo(to, duration: duration, curve: curve, path: path);
    if (tapOnArrival) {
      await tapPulse();
    }
    if (dwell > Duration.zero) {
      await Future<void>.delayed(dwell);
    }
    if (hideAfter) {
      await hide();
    }
  }

  /// Plays [count] tap animations at the pointer's current position.
  ///
  /// Each tap scales the hand down and back up and expands a ripple ring.
  Future<void> tapPulse({int count = 1}) async {
    assert(count > 0, 'count must be at least 1');
    final PointerHost? host = _host;
    if (host == null) {
      _controller._log('pointer.tapPulse ignored: no KeyspotScope is mounted');
      return;
    }
    await host.tapPulse(count: count);
  }

  /// Fades the pointer out and detaches it.
  ///
  /// Cancels any glide in flight. A no-op if the pointer is not visible.
  Future<void> hide() async {
    final PointerHost? host = _host;
    if (host == null) {
      return;
    }
    await host.hide();
  }
}
