import 'package:moliseis/utils/result.dart';

/// Observes server time before retrieval without creating a dataset snapshot.
abstract interface class SyncCursorSource {
  /// Returns the server high-water timestamp, normalized to UTC.
  Future<Result<DateTime>> getCurrentCursor();
}
