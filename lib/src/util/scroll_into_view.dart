import 'package:flutter/widgets.dart';

/// Scrolls [key]'s nearest [Scrollable] ancestor so the target is visible.
///
/// Does nothing when the target is unmounted or has no scrollable ancestor.
/// Note that a target inside a lazily-built list (`ListView.builder`) that has
/// never scrolled into the build region is not merely off-screen — it was
/// never built, has no context, and therefore cannot be scrolled to.
/// Waits for the following frame before returning so callers measure a settled
/// layout — though keyspot's live tracking means a slightly different resting
/// position is harmless.
Future<void> ensureTargetVisible(
  GlobalKey key, {
  Duration duration = const Duration(milliseconds: 300),
  Curve curve = Curves.easeInOut,
  double alignment = 0.5,
}) async {
  final BuildContext? context = key.currentContext;
  if (context == null || !context.mounted) {
    return;
  }
  if (Scrollable.maybeOf(context) == null) {
    return;
  }
  await Scrollable.ensureVisible(
    context,
    alignment: alignment,
    duration: duration,
    curve: curve,
  );
  await WidgetsBinding.instance.endOfFrame;
}
