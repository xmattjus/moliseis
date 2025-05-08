import 'dart:collection' show UnmodifiableListView;

import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/data/repositories/search/search_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:moliseis/utils/result.dart';

class SearchViewModel {
  final SearchRepository _searchRepository;
  final AttractionRepository _attractionRepository;

  SearchViewModel({
    required SearchRepository searchRepository,
    required AttractionRepository attractionService,
  }) : _searchRepository = searchRepository,
       _attractionRepository = attractionService {
    _typeSuggestions =
        AttractionType.values.sublist(1).map((e) {
          return e.readableName;
        }).toList();
  }

  List<String> _typeSuggestions = [];

  UnmodifiableListView<String> get typeSuggestions =>
      UnmodifiableListView(_typeSuggestions);

  void addToHistory(String text) {
    final lowerCaseTypeSuggest = _typeSuggestions.map((e) => e.toLowerCase());
    if (!lowerCaseTypeSuggest.contains(text.toLowerCase())) {
      _searchRepository.addToHistory(text);
    }
  }

  Future<Result<void>> addToHistoryByAttractionId(int id) async {
    final result = await _attractionRepository.getById(id);

    switch (result) {
      case Success<Attraction>():
        await _searchRepository.addToHistory(result.value.name);
      case Error<Attraction>():
        // TODO: Handle this case.
        throw UnimplementedError();
    }

    return result;
  }

  Future<List<int>> getAttractionIdsByQuery(String query) =>
      _searchRepository.getAttractionIdsByQuery(query);

  void removeFromHistory(String query) =>
      _searchRepository.removeFromHistory(query);

  Future<List<String>> get searchHistory => _searchRepository.searchHistory;
}
