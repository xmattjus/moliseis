import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/utils/result.dart';

/// Repository for persisting and querying search activity.
abstract class SearchRepository {
  /// Persists [text] as a past search query.
  ///
  /// Does nothing if [text] is empty or already present (case-insensitive).
  Future<Result<void>> addToPastSearches(String text);

  /// Returns visible place matches followed by annually visible event matches.
  ///
  /// Name, city and category matches retain first-match order within each type.
  /// Place discovery completes successfully before event discovery starts.
  Future<Result<List<ContentBase>>> getResultsByQuery(String text);

  /// Returns all persisted past search queries.
  Future<Result<List<String>>> getPastSearches();

  /// Removes [text] from the persisted search history.
  Future<Result<void>> removeFromPastSearches(String text);
}
