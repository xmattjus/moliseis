import 'package:moliseis/utils/result.dart';

abstract class SearchRepository {
  Future<Result> addToHistory(String text);

  Future<Result<List<int>>> getEventIdsByQuery(String text);

  Future<Result<List<int>>> getPlaceIdsByQuery(String text);

  Future<Result<List<int>>> getRelatedResults(String text);

  Future<Result<List<String>>> pastSearches();

  Future<Result> removeFromHistory(String text);
}
