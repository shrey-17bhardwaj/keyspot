import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/spot_barrier.dart';

/// Implements [SpotBarrier] hit-testing over a live cut-out path.
///
/// Sits between the app and the painted dim layer. Which taps it absorbs, which
/// it lets through to the real widget underneath, and which dismiss the
/// spotlight are all decided by [barrier] and by whether the touch landed
/// inside [cutout].
class KeyspotBarrierLayer extends StatefulWidget {
  /// Creates a barrier layer.
  const KeyspotBarrierLayer({
    super.key,
    required this.barrier,
    required this.cutout,
    required this.onDismiss,
    required this.onTargetTap,
  });

  /// The barrier behaviour to enforce.
  final SpotBarrier barrier;

  /// The current cut-out outline in this layer's coordinate space, or null when
  /// the target cannot be measured.
  final Path? cutout;

  /// Called when the user dismisses the spotlight through the barrier.
  final VoidCallback onDismiss;

  /// Called when the user taps the cut-out under [SpotBarrier.targetOnly].
  final VoidCallback onTargetTap;

  @override
  State<KeyspotBarrierLayer> createState() => _KeyspotBarrierLayerState();
}

class _KeyspotBarrierLayerState extends State<KeyspotBarrierLayer> {
  static const double _tapSlop = kTouchSlop;

  bool _routeAttached = false;
  Offset? _downPosition;

  @override
  void initState() {
    super.initState();
    _syncGlobalRoute();
  }

  @override
  void didUpdateWidget(covariant KeyspotBarrierLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGlobalRoute();
  }

  @override
  void dispose() {
    _detachGlobalRoute();
    super.dispose();
  }

  bool get _needsGlobalRoute => widget.barrier is SpotBarrierTargetOnly;

  void _syncGlobalRoute() {
    if (_needsGlobalRoute && !_routeAttached) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalEvent);
      _routeAttached = true;
    } else if (!_needsGlobalRoute && _routeAttached) {
      _detachGlobalRoute();
    }
  }

  void _detachGlobalRoute() {
    if (!_routeAttached) {
      return;
    }
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalEvent);
    _routeAttached = false;
  }

  /// Observes taps that keyspot deliberately lets through to the real widget,
  /// so [SpotBarrier.targetOnly] can both forward the hit and resolve the
  /// spotlight.
  void _handleGlobalEvent(PointerEvent event) {
    if (!mounted || !_needsGlobalRoute) {
      return;
    }
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return;
    }
    final Path? cutout = widget.cutout;
    if (cutout == null) {
      return;
    }
    Offset local;
    try {
      local = object.globalToLocal(event.position);
    } catch (_) {
      return;
    }
    if (event is PointerDownEvent) {
      _downPosition = cutout.contains(local) ? local : null;
      return;
    }
    if (event is PointerUpEvent) {
      final Offset? down = _downPosition;
      _downPosition = null;
      if (down == null) {
        return;
      }
      if ((local - down).distance <= _tapSlop && cutout.contains(local)) {
        widget.onTargetTap();
      }
      return;
    }
    if (event is PointerCancelEvent) {
      _downPosition = null;
    }
  }

  bool get _absorbInside => switch (widget.barrier) {
        SpotBarrierPassthrough() => false,
        SpotBarrierBlock() => true,
        SpotBarrierDismissOnTap() => true,
        SpotBarrierTargetOnly() => false,
      };

  bool get _absorbOutside => switch (widget.barrier) {
        SpotBarrierPassthrough() => false,
        SpotBarrierBlock() => true,
        SpotBarrierDismissOnTap() => true,
        SpotBarrierTargetOnly() => true,
      };

  void _handleTapUp(TapUpDetails details) {
    final SpotBarrier barrier = widget.barrier;
    if (barrier is! SpotBarrierDismissOnTap) {
      return;
    }
    final Path? cutout = widget.cutout;
    final bool inside = cutout?.contains(details.localPosition) ?? false;
    if (barrier.outsideOnly && inside) {
      return;
    }
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return _BarrierHitRegion(
      cutout: widget.cutout,
      absorbInside: _absorbInside,
      absorbOutside: _absorbOutside,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _handleTapUp,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarrierHitRegion extends SingleChildRenderObjectWidget {
  const _BarrierHitRegion({
    required this.cutout,
    required this.absorbInside,
    required this.absorbOutside,
    required Widget super.child,
  });

  final Path? cutout;
  final bool absorbInside;
  final bool absorbOutside;

  @override
  _RenderBarrierHitRegion createRenderObject(BuildContext context) {
    return _RenderBarrierHitRegion(
      cutout: cutout,
      absorbInside: absorbInside,
      absorbOutside: absorbOutside,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBarrierHitRegion renderObject,
  ) {
    renderObject
      ..cutout = cutout
      ..absorbInside = absorbInside
      ..absorbOutside = absorbOutside;
  }
}

class _RenderBarrierHitRegion extends RenderProxyBox {
  _RenderBarrierHitRegion({
    required Path? cutout,
    required bool absorbInside,
    required bool absorbOutside,
  })  : _cutout = cutout,
        _absorbInside = absorbInside,
        _absorbOutside = absorbOutside;

  Path? _cutout;
  Path? get cutout => _cutout;
  set cutout(Path? value) {
    if (_cutout == value) {
      return;
    }
    _cutout = value;
  }

  bool _absorbInside;
  bool get absorbInside => _absorbInside;
  set absorbInside(bool value) {
    if (_absorbInside == value) {
      return;
    }
    _absorbInside = value;
  }

  bool _absorbOutside;
  bool get absorbOutside => _absorbOutside;
  set absorbOutside(bool value) {
    if (_absorbOutside == value) {
      return;
    }
    _absorbOutside = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      return false;
    }
    final bool inside = _cutout?.contains(position) ?? false;
    final bool absorb = inside ? _absorbInside : _absorbOutside;
    if (!absorb) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}
