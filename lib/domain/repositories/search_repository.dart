import 'package:moliseis/utils/result.dart';

/// Repository for persisting and querying search activity.
abstract class SearchRepository {
  /// Persists [text] as a past search query.
  ///
  /// Does nothing if [text] is empty or already present (case-insensitive).
  Future<Result<void>> addToPastSearches(String text);

  /// Returns event IDs whose names match [text].
  Future<Result<List<int>>> getEventIdsByQuery(String text);

  /// Returns place IDs whose names match [text].
  Future<Result<List<int>>> getPlaceIdsByQuery(String text);

  /// Returns place IDs that are contextually related to [text].
  Future<Result<List<int>>> getRelatedResults(String text);

  /// Returns all persisted past search queries.
  Future<Result<List<String>>> getPastSearches();

  /// Removes [text] from the persisted search history.
  Future<Result<void>> removeFromPastSearches(String text);
}
