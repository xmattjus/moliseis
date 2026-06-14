import 'package:moliseis/data/core/base_sync_repository.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/mappers/mappers.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CityRepositoryImpl extends BaseSyncRepository<CityDto, CityEntity>
    implements CityRepository {
  CityRepositoryImpl({
    required Logger logger,
    required Supabase supabaseI,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _box = objectBoxI.store.box<CityEntity>(),
       super(logger);

  final Supabase _supabase;
  final Box<CityEntity> _box;

  @override
  String get tableName => 'cities';

  @override
  String get entityName => 'city';

  @override
  Future<List<CityDto>> fetchRemote() async {
    final response = await _supabase.client.from(tableName).select();

    return response.map<CityDto>(CityDtoMapper.fromMap).toList();
  }

  @override
  CityEntity? getLocalById(int id) => _box.get(id);

  @override
  void put(CityEntity entity) => _box.put(entity);

  @override
  void putMany(List<CityEntity> entities) => _box.putMany(entities);

  @override
  CityEntity createEntity(CityDto dto) => dto.toEntity();

  @override
  CityEntity mergeEntity(CityDto dto, CityEntity existing) =>
      dto.mergeInto(existing);

  @override
  CityEntity markEntityDeleted(CityEntity existing) {
    return existing.copyWith(
      isDeleted: true,
    );
  }
}
