import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How often a tracker re-measures its target.
enum TrackingMode {
  /// Re-measure on every frame. Follows anything, including implicit
  /// animations and continuous layout changes. This is the default.
  everyFrame,

  /// Re-measure when the target's nearest scrollable moves, when the view
  /// metrics change (rotation, keyboard, window resize), and once per layout
  /// pass. Cheaper than [everyFrame] and enough for most screens.
  onScrollAndMetrics,

  /// Measure once, after the first frame, and never again. Reproduces the
  /// snapshot behaviour of simpler packages; only safe on static screens.
  once,
}

/// Signature for building a widget from a live-tracked target rect.
///
/// [rect] is null whenever the target cannot currently be measured — it is not
/// mounted, has no size, or is detached. Builders should render nothing in that
/// case rather than throwing.
typedef KeyspotRectBuilder = Widget Function(BuildContext context, Rect? rect);

/// Resolves [targetKey]'s bounds into the tracker's own coordinate space and
/// rebuilds whenever they change.
///
/// This is the piece that keeps keyspot's spotlight and pointer from drifting,
/// and it is public because it is independently useful: hang a badge, a
/// connector line or a coach-mark off any widget without wrapping it.
///
/// ```dart
/// KeyspotAnchorTracker(
///   targetKey: cartKey,
///   builder: (BuildContext context, Rect? rect) {
///     if (rect == null) {
///       return const SizedBox.shrink();
///     }
///     return Positioned(
///       left: rect.right - 8,
///       top: rect.top - 8,
///       child: const Badge(),
///     );
///   },
/// )
/// ```
///
/// Place it inside a [Stack] so the rect it reports lines up with the
/// positioned children you build from it.
class KeyspotAnchorTracker extends StatefulWidget {
  /// Creates a tracker for [targetKey].
  const KeyspotAnchorTracker({
    super.key,
    required this.targetKey,
    required this.builder,
    this.mode = TrackingMode.everyFrame,
    this.padding = EdgeInsets.zero,
  });

  /// The key of the widget to follow.
  final GlobalKey targetKey;

  /// Builds this widget's subtree from the current target rect.
  final KeyspotRectBuilder builder;

  /// How often the target is re-measured.
  final TrackingMode mode;

  /// Inflation applied to the measured rect before it reaches [builder].
  final EdgeInsets padding;

  @override
  State<KeyspotAnchorTracker> createState() => _KeyspotAnchorTrackerState();
}

class _KeyspotAnchorTrackerState extends State<KeyspotAnchorTracker>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Ticker? _ticker;
  ScrollPosition? _watchedPosition;
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) => _remeasure());
  }

  @override
  void didUpdateWidget(covariant KeyspotAnchorTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _stopTracking();
      _startTracking();
    }
    if (oldWidget.targetKey != widget.targetKey ||
        oldWidget.padding != widget.padding) {
      _remeasure();
    }
  }

  @override
  void dispose() {
    _stopTracking();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (widget.mode == TrackingMode.once) {
      return;
    }
    _remeasure();
  }

  void _startTracking() {
    switch (widget.mode) {
      case TrackingMode.everyFrame:
        _ticker = createTicker((_) => _remeasure())..start();
      case TrackingMode.onScrollAndMetrics:
        WidgetsBinding.instance.addPostFrameCallback((_) => _attachScroll());
      case TrackingMode.once:
        break;
    }
  }

  void _stopTracking() {
    _ticker?.dispose();
    _ticker = null;
    _watchedPosition?.removeListener(_remeasure);
    _watchedPosition = null;
  }

  void _attachScroll() {
    if (!mounted) {
      return;
    }
    final BuildContext? targetContext = widget.targetKey.currentContext;
    if (targetContext == null) {
      return;
    }
    final ScrollPosition? position =
        Scrollable.maybeOf(targetContext)?.position;
    if (identical(position, _watchedPosition)) {
      return;
    }
    _watchedPosition?.removeListener(_remeasure);
    _watchedPosition = position;
    _watchedPosition?.addListener(_remeasure);
  }

  void _remeasure() {
    if (!mounted) {
      return;
    }
    if (widget.mode == TrackingMode.onScrollAndMetrics &&
        _watchedPosition == null) {
      _attachScroll();
    }
    final Rect? measured = measureTargetRect(
      targetKey: widget.targetKey,
      container: context.findRenderObject(),
      padding: widget.padding,
    );
    if (measured == _rect) {
      return;
    }
    setState(() => _rect = measured);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _rect);
}

/// Measures [targetKey]'s bounds in [container]'s local coordinate space.
///
/// Returns null when the target or the container is unmounted, unsized or
/// detached, or when the coordinate transform is not currently invertible —
/// all of which happen routinely during route transitions and teardown.
///
/// [padding] inflates the resulting rect.
Rect? measureTargetRect({
  required GlobalKey targetKey,
  required RenderObject? container,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  if (container is! RenderBox || !container.attached || !container.hasSize) {
    return null;
  }
  final BuildContext? targetContext = targetKey.currentContext;
  if (targetContext == null) {
    return null;
  }
  final RenderObject? targetObject = targetContext.findRenderObject();
  if (targetObject is! RenderBox ||
      !targetObject.attached ||
      !targetObject.hasSize) {
    return null;
  }
  try {
    final Offset globalTopLeft = targetObject.localToGlobal(Offset.zero);
    final Offset localTopLeft = container.globalToLocal(globalTopLeft);
    final Rect rect = localTopLeft & targetObject.size;
    if (!rect.isFinite) {
      return null;
    }
    return padding == EdgeInsets.zero ? rect : padding.inflateRect(rect);
  } catch (_) {
    // localToGlobal/globalToLocal throw on non-invertible transforms, which
    // occurs mid-teardown and during some route animations. Treat it as
    // "not measurable right now".
    return null;
  }
}

/// Waits for [key]'s [RenderBox] to exist and be laid out.
///
/// Targets inside a freshly pushed route are not laid out on the frame the
/// spotlight is requested, so this retries across up to [retryFrames]
/// end-of-frame ticks before giving up and returning null.
Future<RenderBox?> resolveTargetBox(
  GlobalKey key, {
  int retryFrames = 3,
}) async {
  assert(retryFrames >= 0, 'retryFrames must not be negative');
  for (int attempt = 0; attempt <= retryFrames; attempt++) {
    final RenderObject? object = key.currentContext?.findRenderObject();
    if (object is RenderBox && object.attached && object.hasSize) {
      return object;
    }
    if (attempt == retryFrames) {
      break;
    }
    await WidgetsBinding.instance.endOfFrame;
  }
  return null;
}
