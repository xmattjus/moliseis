import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';

class ExploreViewModel extends ChangeNotifier {
  ExploreViewModel({required PlaceRepository placeRepository})
    : _placeRepository = placeRepository {
    loadLatest = Command0(_loadLatest);
    unawaited(loadLatest.execute());
  }

  final PlaceRepository _placeRepository;

  late Command0<void> loadLatest;
  var _latest = <Place>[];

  UnmodifiableListView<Place> get latest => UnmodifiableListView(_latest);

  UnmodifiableListView<ContentCategory> get types =>
      UnmodifiableListView(ContentCategory.values.minusUnknown);

  Future<Result<void>> _loadLatest() async {
    final result = await _placeRepository.getLatest();

    return result.map((places) {
      _latest = places;
      notifyListeners();
    });
  }
}
