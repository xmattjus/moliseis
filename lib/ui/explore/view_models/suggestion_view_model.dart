import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class SuggestionViewModel extends ChangeNotifier {
  SuggestionViewModel({required PlaceRepository placeRepository})
    : _placeRepository = placeRepository {
    load = Command0(_load);

    unawaited(load.execute());
  }

  final PlaceRepository _placeRepository;

  /// Command for loading the suggested places.
  late Command0<void> load;

  var _suggestions = <Place>[];

  /// An unmodifiable list of suggested places.
  UnmodifiableListView<Place> get suggestions =>
      UnmodifiableListView(_suggestions);

  Future<Result<void>> _load() async {
    final result = await _placeRepository.getSuggestions();

    _suggestions = result.getOrNull() ?? [];

    notifyListeners();

    return result;
  }

  @override
  void dispose() {
    load.dispose();
    super.dispose();
  }
}
