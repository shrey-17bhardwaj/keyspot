import 'package:flutter/foundation.dart';

/// Signature for keyspot's diagnostic logging hook.
///
/// Pass one to [KeyspotController] to observe what the package is doing. The
/// package never logs unless a logger is supplied.
typedef KeyspotLog = void Function(String message);

/// Ready-made [KeyspotLog] implementations.
abstract final class KeyspotLoggers {
  /// Forwards every message to [debugPrint], prefixed with `[keyspot]`.
  static void debug(String message) => debugPrint('[keyspot] $message');

  /// Discards every message. This is the package default.
  static void silent(String message) {}
}
