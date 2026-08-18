import 'package:flutter/widgets.dart';

import '../core/keyspot_controller.dart';
import '../theme/keyspot_theme.dart';
import 'pointer_overlay.dart';
import 'spotlight_overlay.dart';

/// Mounts keyspot's overlays above [child] and publishes [controller] to the
/// subtree.
///
/// This is the whole integration. You never place overlay widgets yourself.
///
/// Two placements work; pick by how much you need covered:
///
/// ```dart
/// // 1. Above MaterialApp — covers every route, including dialogs pushed on
/// //    the root navigator.
/// KeyspotScope(
///   controller: keyspot,
///   child: MaterialApp(home: HomePage()),
/// )
///
/// // 2. In MaterialApp.builder — inherits Theme, Directionality and
/// //    localizations, which is usually what you want for content cards.
/// MaterialApp(
///   builder: (BuildContext context, Widget? child) => KeyspotScope(
///     controller: keyspot,
///     child: child ?? const SizedBox.shrink(),
///   ),
/// )
/// ```
///
/// The scope disposes nothing it did not create: [controller]'s lifetime is
/// yours.
class KeyspotScope extends StatefulWidget {
  /// Creates a scope.
  const KeyspotScope({
    super.key,
    required this.controller,
    required this.child,
    this.theme,
  });

  /// The controller whose spotlights and pointer this scope renders.
  final KeyspotController controller;

  /// The application subtree the overlays are drawn above.
  final Widget child;

  /// Visual defaults for this scope.
  ///
  /// Takes precedence over any [KeyspotTheme] installed as a `ThemeData`
  /// extension. Leave null to use the ambient one, or the built-in defaults.
  final KeyspotTheme? theme;

  /// The controller from the nearest enclosing [KeyspotScope].
  ///
  /// Throws in debug mode if there is no scope above [context]; use [maybeOf]
  /// when a scope is genuinely optional.
  static KeyspotController of(BuildContext context) {
    final KeyspotController? controller = maybeOf(context);
    assert(
      controller != null,
      'KeyspotScope.of() was called with a context that does not contain a '
      'KeyspotScope. Wrap your app (or your MaterialApp.builder) in one.',
    );
    return controller!;
  }

  /// The controller from the nearest enclosing [KeyspotScope], or null.
  static KeyspotController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<KeyspotScopeMarker>()
        ?.notifier;
  }

  @override
  State<KeyspotScope> createState() => _KeyspotScopeState();
}

/// The [InheritedNotifier] that publishes the controller to the subtree.
///
/// Exposed so tests and advanced integrations can look it up directly; prefer
/// [KeyspotScope.of].
class KeyspotScopeMarker extends InheritedNotifier<KeyspotController> {
  /// Creates the marker.
  const KeyspotScopeMarker({
    super.key,
    required KeyspotController super.notifier,
    required super.child,
  });
}

class _KeyspotScopeState extends State<KeyspotScope> {
  @override
  Widget build(BuildContext context) {
    return KeyspotScopeMarker(
      notifier: widget.controller,
      child: Stack(
        // A non-directional alignment keeps this usable above MaterialApp,
        // where no Directionality exists yet.
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          KeyspotSpotlightOverlay(
            controller: widget.controller,
            theme: widget.theme,
          ),
          KeyspotPointerOverlay(
            controller: widget.controller,
            theme: widget.theme,
          ),
        ],
      ),
    );
  }
}
