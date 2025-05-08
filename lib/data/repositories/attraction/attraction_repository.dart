import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/utils/result.dart';

abstract class AttractionRepository {
  Future<List<Attraction>> getAll(AttractionSort sortBy);

  Future<Result<Attraction>> getById(int id);

  Future<List<int>> getAttractionIdsByType(
    AttractionType type,
    AttractionSort sortBy,
  );

  Future<List<int>> getNearAttractionIds(List<double> coordinates);

  int getTypeIndexFromAttractionId(int id);

  Future<Result<void>> synchronize();

  Future<List<int>> get latestAttractionsIds;

  List<int> get savedAttractionIds;

  Future<List<int>> get suggestedAttractionsIds;

  void setSavedAttraction(int id, bool save);
}
