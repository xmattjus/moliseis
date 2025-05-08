abstract class SearchRepository {
  Future<void> addToHistory(String text);

  Future<List<int>> getAttractionIdsByQuery(String text);

  Future<void> removeFromHistory(String text);

  Future<List<String>> get searchHistory;
}
