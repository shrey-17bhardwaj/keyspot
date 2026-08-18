import 'package:flutter/material.dart' show Theme;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../core/anchor_tracker.dart';
import '../core/keyspot_controller.dart';
import '../core/keyspot_host.dart';
import '../core/spotlight_state.dart';
import '../theme/keyspot_theme.dart';
import '../theme/ring_style.dart';
import '../util/shape_resolver.dart';
import 'barrier_layer.dart';
import 'spotlight_painter.dart';

/// The spotlight layer mounted by `KeyspotScope`.
///
/// Registers itself with [KeyspotController] as its [SpotlightHost], so
/// application code never places this widget by hand.
class KeyspotSpotlightOverlay extends StatefulWidget {
  /// Creates the spotlight overlay.
  const KeyspotSpotlightOverlay({
    super.key,
    required this.controller,
    this.theme,
  });

  /// The controller to serve.
  final KeyspotController controller;

  /// An explicit theme, taking precedence over any ambient [KeyspotTheme].
  final KeyspotTheme? theme;

  @override
  State<KeyspotSpotlightOverlay> createState() =>
      _KeyspotSpotlightOverlayState();
}

class _KeyspotSpotlightOverlayState extends State<KeyspotSpotlightOverlay>
    with TickerProviderStateMixin
    implements SpotlightHost {
  late final AnimationController _entry;
  late final AnimationController _exit;
  final List<AnimationController> _ringPulses = <AnimationController>[];

  SpotlightRequest? _request;
  KeyspotTheme _theme = const KeyspotTheme();
  bool _sawRect = false;
  bool _lostScheduled = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    widget.controller.attachSpotlightHost(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = _resolveTheme();
    if (_request != null) {
      _syncRingPulses(_request!.rings ?? _theme.rings);
    }
  }

  @override
  void didUpdateWidget(covariant KeyspotSpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.detachSpotlightHost(this);
      widget.controller.attachSpotlightHost(this);
    }
    if (oldWidget.theme != widget.theme) {
      _theme = _resolveTheme();
      if (_request != null) {
        _syncRingPulses(_request!.rings ?? _theme.rings);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.detachSpotlightHost(this);
    for (final AnimationController pulse in _ringPulses) {
      pulse.dispose();
    }
    _ringPulses.clear();
    _entry.dispose();
    _exit.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ SpotlightHost

  @override
  bool get isPresenting => _request != null;

  @override
  Duration get defaultSpotlightDuration =>
      (mounted ? _resolveTheme() : const KeyspotTheme())
          .defaultSpotlightDuration;

  @override
  Future<void> present(SpotlightRequest request) async {
    if (!mounted) {
      return;
    }
    _theme = _resolveTheme();
    setState(() {
      _request = request;
      _sawRect = false;
      _lostScheduled = false;
    });
    _syncRingPulses(request.rings ?? _theme.rings);
    _exit.value = 0.0;
    _entry.duration = _theme.entryDuration;

    final String? label = request.semanticLabel;
    if (label != null && label.isNotEmpty) {
      // SemanticsService.sendAnnouncement requires Flutter >= 3.36; announce
      // stays until the package's minimum SDK (3.22, per SPEC.md) is raised.
      // ignore: deprecated_member_use
      await SemanticsService.announce(
        label,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    }

    if (_reduceMotion) {
      _entry.value = 1.0;
      return;
    }
    try {
      await _entry.forward(from: 0.0).orCancel;
    } on TickerCanceled {
      // Replaced or disposed mid-entry; the replacing spotlight owns the screen.
    }
  }

  @override
  Future<void> dismiss() async {
    if (!mounted || _request == null) {
      return;
    }
    // When the target rect was lost the tracker already paints nothing, so an
    // exit animation would be invisible — and, started from a post-frame
    // callback, it could outlive the caller's pumps. Tear down instantly.
    if (!_reduceMotion && !_lostScheduled) {
      _exit.duration = _theme.exitDuration;
      try {
        await _exit.forward(from: 0.0).orCancel;
      } on TickerCanceled {
        // Interrupted; fall through and tear down anyway.
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _request = null);
    _entry.value = 0.0;
    _exit.value = 0.0;
    for (final AnimationController pulse in _ringPulses) {
      pulse.stop();
    }
  }

  // ----------------------------------------------------------------- internal

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  KeyspotTheme _resolveTheme() {
    final KeyspotTheme? explicit = widget.theme;
    if (explicit != null) {
      return explicit;
    }
    return Theme.of(context).extension<KeyspotTheme>() ?? const KeyspotTheme();
  }

  void _syncRingPulses(List<RingStyle> rings) {
    while (_ringPulses.length > rings.length) {
      _ringPulses.removeLast().dispose();
    }
    while (_ringPulses.length < rings.length) {
      _ringPulses.add(
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
          value: 1.0,
        ),
      );
    }
    for (int i = 0; i < rings.length; i++) {
      final AnimationController pulse = _ringPulses[i];
      pulse.duration = rings[i].pulse.period;
      if (rings[i].pulse.isAnimated && !_reduceMotion) {
        if (!pulse.isAnimating) {
          pulse.repeat(reverse: true);
        }
      } else {
        pulse.stop();
        pulse.value = 1.0;
      }
    }
  }

  void _handleRectLost() {
    if (_lostScheduled || !_sawRect) {
      return;
    }
    _lostScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.controller.hideSpotlight();
    });
  }

  static Rect _scaleRect(Rect rect, double t) {
    return Rect.fromCenter(
      center: rect.center,
      width: rect.width * t,
      height: rect.height * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SpotlightRequest? request = _request;
    if (request == null) {
      return const SizedBox.shrink();
    }
    final KeyspotTheme theme = _theme;
    final List<RingStyle> rings = request.rings ?? theme.rings;

    return KeyspotAnchorTracker(
      targetKey: request.targetKey,
      padding: request.padding,
      builder: (BuildContext context, Rect? rect) {
        if (rect == null) {
          _handleRectLost();
          return const SizedBox.shrink();
        }
        _sawRect = true;
        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            _entry,
            _exit,
            ..._ringPulses,
          ]),
          builder: (BuildContext context, Widget? _) {
            final double entry = _entry.value;
            final double dimT = theme.dimFraction <= 0.0
                ? 1.0
                : (entry / theme.dimFraction).clamp(0.0, 1.0);
            final double rawScale = entry <= theme.dimFraction
                ? 0.0
                : ((entry - theme.dimFraction) / (1.0 - theme.dimFraction))
                    .clamp(0.0, 1.0);
            final double scaleT =
                rawScale <= 0.0 ? 0.0 : Curves.easeOutBack.transform(rawScale);
            final double globalOpacity = 1.0 - _exit.value;

            final Path hitPath = buildSpotPath(
              request.shape,
              rect,
              targetKey: request.targetKey,
            );
            final Path? paintPath = scaleT <= 0.0
                ? null
                : buildSpotPath(
                    request.shape,
                    _scaleRect(rect, scaleT),
                    targetKey: request.targetKey,
                  );

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: SpotlightPainter(
                      cutout: paintPath,
                      barrierColor: theme.barrierColor,
                      barrierOpacity: theme.barrierOpacity * dimT,
                      rings: rings,
                      ringOpacities: <double>[
                        for (int i = 0; i < rings.length; i++)
                          rings[i].pulse.opacityAt(
                                i < _ringPulses.length
                                    ? _ringPulses[i].value
                                    : 1.0,
                              ),
                      ],
                      globalOpacity: globalOpacity,
                    ),
                  ),
                ),
                KeyspotBarrierLayer(
                  barrier: request.barrier,
                  cutout: hitPath,
                  onDismiss: widget.controller.notifyBarrierDismissed,
                  onTargetTap: widget.controller.notifyTargetTapped,
                ),
                if (request.overlayBuilder != null)
                  Opacity(
                    opacity: globalOpacity.clamp(0.0, 1.0),
                    child: request.overlayBuilder!(context, rect),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
