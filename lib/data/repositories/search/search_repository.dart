import 'package:moliseis/utils/result.dart';

abstract class SearchRepository {
  Future<Result> addToHistory(String text);

  Future<Result<List<int>>> getAttractionIdsByQuery(String text);

  Future<Result<List<int>>> getRelatedResults(String text);

  Future<Result<List<String>>> get pastSearches;

  Future<Result> removeFromHistory(String text);
}
