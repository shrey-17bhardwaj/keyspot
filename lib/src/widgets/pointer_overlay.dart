import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/scheduler.dart' show Ticker, TickerCanceled;
import 'package:flutter/widgets.dart';

import '../core/anchor.dart';
import '../core/anchor_tracker.dart';
import '../core/keyspot_controller.dart';
import '../core/keyspot_host.dart';
import '../core/pointer_state.dart';
import '../theme/keyspot_theme.dart';
import '../theme/pointer_style.dart';
import 'default_hand_painter.dart';

/// The pointer layer mounted by `KeyspotScope`.
///
/// Registers itself with [KeyspotController] as its [PointerHost]. Every glide
/// is driven by a real [AnimationController], so the futures returned from
/// [KeyspotPointer.moveTo] complete exactly when the motion stops.
class KeyspotPointerOverlay extends StatefulWidget {
  /// Creates the pointer overlay.
  const KeyspotPointerOverlay({
    super.key,
    required this.controller,
    this.theme,
  });

  /// The controller to serve.
  final KeyspotController controller;

  /// An explicit theme, taking precedence over any ambient [KeyspotTheme].
  final KeyspotTheme? theme;

  @override
  State<KeyspotPointerOverlay> createState() => _KeyspotPointerOverlayState();
}

class _KeyspotPointerOverlayState extends State<KeyspotPointerOverlay>
    with TickerProviderStateMixin
    implements PointerHost {
  late final AnimationController _visibility;
  late final AnimationController _glide;
  late final AnimationController _rotation;
  late final AnimationController _glow;
  late final AnimationController _tap;
  Ticker? _ticker;

  Anchor? _anchor;
  Offset? _position;
  Offset? _glideStart;
  MotionPath _path = MotionPath.line;
  Curve _curve = Curves.easeInOutCubic;
  Rotation _rotationFrom = const Rotation.none();
  Rotation _rotationTo = const Rotation.none();
  PointerStyle? _styleOverride;
  PointerPhase _phase = PointerPhase.idle;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _visibility = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _glide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0,
    );
    // Started in show() and stopped in hide(): an always-repeating controller
    // would keep the app rendering at 60fps for the entire session.
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 1.0,
    );
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    widget.controller.attachPointerHost(this);
  }

  @override
  void didUpdateWidget(covariant KeyspotPointerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.detachPointerHost(this);
      widget.controller.attachPointerHost(this);
    }
  }

  @override
  void dispose() {
    widget.controller.detachPointerHost(this);
    _ticker?.dispose();
    _visibility.dispose();
    _glide.dispose();
    _rotation.dispose();
    _glow.dispose();
    _tap.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- PointerHost

  @override
  bool get isVisible => _visible;

  @override
  PointerPhase get phase => _phase;

  @override
  Future<void> show(
    Anchor at, {
    PointerStyle? style,
    Rotation? rotation,
  }) async {
    if (!mounted) {
      return;
    }
    if (style != null) {
      _styleOverride = style;
    }
    if (at.isKeyed) {
      await resolveTargetBox(at.key!);
      if (!mounted) {
        return;
      }
    }
    _anchor = at;
    final Offset? resolved = _resolveAnchor(at);
    if (rotation != null) {
      _setRotation(rotation, animate: _visible);
    }
    final bool wasVisible = _visible;
    setState(() {
      _position = resolved ?? _position;
      _visible = true;
      _phase = PointerPhase.idle;
    });
    _startTicker();
    if (!_glow.isAnimating && !_reduceMotion) {
      unawaited(_glow.repeat(reverse: true));
    }
    if (wasVisible) {
      return;
    }
    if (_reduceMotion) {
      _visibility.value = 1.0;
      return;
    }
    // The entrance fade runs on its own; show() resolves once the pointer is
    // mounted at its anchor, so callers can chain a moveTo without waiting.
    unawaited(
      _visibility.forward(from: 0.0).orCancel.catchError((Object _) {
        // Hidden again before the entrance finished.
      }),
    );
  }

  @override
  Future<void> moveTo(
    Anchor to, {
    required Duration duration,
    required Curve curve,
    Rotation? rotation,
    required MotionPath path,
  }) async {
    if (!mounted) {
      return;
    }
    if (!_visible) {
      // Never glide in from the origin: mount at the destination instead.
      await show(to, rotation: rotation);
      return;
    }
    _glide.stop(canceled: true);
    if (to.isKeyed) {
      await resolveTargetBox(to.key!);
      if (!mounted) {
        return;
      }
    }
    final Offset start = _position ?? _resolveAnchor(to) ?? Offset.zero;
    _glideStart = start;
    _anchor = to;
    _path = path;
    _curve = curve;
    if (rotation != null) {
      _setRotation(rotation, animate: true);
    }
    setState(() => _phase = PointerPhase.moving);

    if (_reduceMotion) {
      setState(() {
        _position = _resolveAnchor(to) ?? start;
        _phase = PointerPhase.arrived;
      });
      return;
    }

    _glide.duration = duration;
    try {
      await _glide.forward(from: 0.0).orCancel;
    } on TickerCanceled {
      // Superseded by another moveTo, or hidden. Leave the pointer where it is.
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _position = _resolveAnchor(to) ?? _position;
      _phase = PointerPhase.arrived;
    });
  }

  @override
  Future<void> tapPulse({required int count}) async {
    for (int i = 0; i < count; i++) {
      if (!mounted || !_visible) {
        return;
      }
      if (_reduceMotion) {
        continue;
      }
      try {
        await _tap.forward(from: 0.0).orCancel;
      } on TickerCanceled {
        return;
      }
      _tap.value = 0.0;
    }
  }

  @override
  Future<void> hide() async {
    if (!mounted || !_visible) {
      return;
    }
    _glide.stop(canceled: true);
    if (_reduceMotion) {
      _visibility.value = 0.0;
    } else {
      try {
        await _visibility.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    _stopTicker();
    _glow.stop();
    setState(() {
      _visible = false;
      _position = null;
      _anchor = null;
      _glideStart = null;
      _phase = PointerPhase.idle;
    });
  }

  // ----------------------------------------------------------------- internal

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  KeyspotTheme get _theme =>
      widget.theme ??
      Theme.of(context).extension<KeyspotTheme>() ??
      const KeyspotTheme();

  void _startTicker() {
    _ticker ??= createTicker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration _) {
    if (!mounted || !_visible) {
      return;
    }
    final Offset? endpoint = _resolveAnchor(_anchor);
    final Offset? start = _glideStart;
    final Offset? next =
        (_glide.isAnimating && start != null && endpoint != null)
            ? resolveMotionPoint(
                _path,
                start,
                endpoint,
                _curve.transform(_glide.value.clamp(0.0, 1.0)),
              )
            : (endpoint ?? _position);
    if (next != null && next != _position) {
      setState(() => _position = next);
    }
  }

  Offset? _resolveAnchor(Anchor? anchor) {
    if (anchor == null) {
      return null;
    }
    final RenderObject? self = context.findRenderObject();
    if (self is! RenderBox || !self.attached || !self.hasSize) {
      return null;
    }
    final Offset? fixed = anchor.offset;
    if (fixed != null) {
      try {
        return self.globalToLocal(fixed);
      } catch (_) {
        return null;
      }
    }
    final Rect? rect = measureTargetRect(
      targetKey: anchor.key!,
      container: self,
    );
    if (rect == null) {
      return null;
    }
    return anchor.resolveWithin(
      rect,
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  void _setRotation(Rotation target, {required bool animate}) {
    _rotationFrom = _currentRotation();
    _rotationTo = target;
    if (!animate || _reduceMotion) {
      _rotation.value = 1.0;
      return;
    }
    _rotation.forward(from: 0.0);
  }

  Rotation _currentRotation() =>
      Rotation.lerp(_rotationFrom, _rotationTo, _rotation.value);

  @override
  Widget build(BuildContext context) {
    // The overlay always renders a full-size Stack of its own, so that
    // context.findRenderObject() in _resolveAnchor is a stable, screen-filling
    // box. Without it the first render descendant would be the positioned hand
    // itself, and measuring anchors against a box that moves with the hand
    // feeds the resolved position back into itself.
    return Stack(
      alignment: Alignment.topLeft,
      clipBehavior: Clip.none,
      children: <Widget>[_buildPointer(context)],
    );
  }

  Widget _buildPointer(BuildContext context) {
    final Offset? position = _position;
    if (!_visible || position == null) {
      return const SizedBox.shrink();
    }
    final PointerStyle style = _styleOverride ?? _theme.pointerStyle;
    final double size = style.scaleWithTextScaler
        ? MediaQuery.textScalerOf(context).scale(style.size)
        : style.size;
    final bool rtl = Directionality.maybeOf(context) == TextDirection.rtl;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _visibility,
        _rotation,
        _glow,
        _tap,
      ]),
      builder: (BuildContext context, Widget? _) {
        final double appear = _visibility.value.clamp(0.0, 1.0);
        final double entryScale =
            0.6 + 0.4 * Curves.easeOutBack.transform(appear).clamp(0.0, 1.4);
        final double tapScale =
            1.0 - 0.18 * math.sin(_tap.value.clamp(0.0, 1.0) * math.pi);
        final double left = position.dx - (style.hotspot.x + 1.0) / 2.0 * size;
        final double top = position.dy - (style.hotspot.y + 1.0) / 2.0 * size;

        Widget hand = SizedBox(
          width: size,
          height: size,
          child: style.builder?.call(context) ??
              CustomPaint(
                painter: DefaultHandPainter(
                  fillColor: style.handColor,
                  outlineColor: style.handOutlineColor,
                ),
              ),
        );

        if (rtl && style.flipForRtl) {
          hand = Transform.scale(
            scaleX: -1.0,
            alignment: style.hotspot,
            child: hand,
          );
        }

        return Positioned(
          left: left,
          top: top,
          child: IgnorePointer(
            child: Opacity(
              opacity: appear,
              child: Transform.scale(
                scale: entryScale * tapScale,
                alignment: style.hotspot,
                child: Transform.rotate(
                  angle: _currentRotation().radians,
                  alignment: style.hotspot,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned.fill(child: hand),
                        if (_tap.isAnimating || _tap.value > 0.0)
                          Align(
                            alignment: style.hotspot,
                            child: _TapRipple(
                              progress: _tap.value,
                              color: style.dotColor,
                              diameter: size * 0.9,
                            ),
                          ),
                        if (style.showGlowDot)
                          Align(
                            alignment: style.hotspot,
                            child: _GlowDot(
                              pulse: _glow.value,
                              color: Color.lerp(
                                    style.dotColor,
                                    style.arrivedDotColor,
                                    _phase == PointerPhase.arrived ? 1.0 : 0.0,
                                  ) ??
                                  style.dotColor,
                              diameter: size * 0.22,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowDot extends StatelessWidget {
  const _GlowDot({
    required this.pulse,
    required this.color,
    required this.diameter,
  });

  final double pulse;
  final Color color;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final double halo = diameter * (1.6 + 0.6 * pulse);
    return SizedBox(
      width: halo,
      height: halo,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha((70.0 * (1.0 - pulse * 0.6)).round()),
            ),
            child: SizedBox(width: halo, height: halo),
          ),
          DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: SizedBox(width: diameter, height: diameter),
          ),
        ],
      ),
    );
  }
}

class _TapRipple extends StatelessWidget {
  const _TapRipple({
    required this.progress,
    required this.color,
    required this.diameter,
  });

  final double progress;
  final Color color;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0);
    final double extent = diameter * (0.4 + 0.9 * t);
    return SizedBox(
      width: extent,
      height: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withAlpha((200.0 * (1.0 - t)).round()),
            width: 2.0,
          ),
        ),
      ),
    );
  }
}
