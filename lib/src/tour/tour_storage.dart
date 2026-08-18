/// Remembers which tours a user has already seen.
///
/// The package ships only [InMemoryTourStorage] so it can stay dependency-free.
/// For real persistence, implement this against `shared_preferences`, Hive, a
/// database, or your own settings service — it is two methods:
///
/// ```dart
/// class PrefsTourStorage implements KeyspotTourStorage {
///   PrefsTourStorage(this._prefs);
///   final SharedPreferences _prefs;
///
///   @override
///   Future<bool> wasSeen(String tourId) async =>
///       _prefs.getBool('tour.$tourId') ?? false;
///
///   @override
///   Future<void> markSeen(String tourId) async =>
///       _prefs.setBool('tour.$tourId', true);
/// }
/// ```
abstract interface class KeyspotTourStorage {
  /// Whether the tour with [tourId] has been completed before.
  Future<bool> wasSeen(String tourId);

  /// Records that the tour with [tourId] has been completed.
  Future<void> markSeen(String tourId);
}

/// A [KeyspotTourStorage] that forgets everything when the app restarts.
///
/// Useful for demos and tests; swap it for a persistent implementation in
/// production.
class InMemoryTourStorage implements KeyspotTourStorage {
  /// Creates an empty in-memory store.
  InMemoryTourStorage();

  final Set<String> _seen = <String>{};

  /// The ids recorded so far.
  Set<String> get seenTourIds => Set<String>.unmodifiable(_seen);

  @override
  Future<bool> wasSeen(String tourId) async => _seen.contains(tourId);

  @override
  Future<void> markSeen(String tourId) async {
    _seen.add(tourId);
  }
}
