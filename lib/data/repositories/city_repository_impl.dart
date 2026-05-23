import 'package:collection/collection.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/city_supabase_table.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CityRepositoryImpl implements CityRepository {
  CityRepositoryImpl({
    required Logger logger,
    required Supabase supabaseI,
    required CitySupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _logger = logger,
       _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _cityBox = objectBoxI.store.box<CityEntity>();

  final Logger _logger;

  final Supabase _supabase;
  final CitySupabaseTable _supabaseTable;
  final Box<CityEntity> _cityBox;

  @override
  Future<Result<void>> synchronize() async {
    _logger.log(const RepositorySyncStarted('city'));

    try {
      final cities = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      final remote = Set<CityEntity>.unmodifiable(
        cities.map<CityEntity>(CityEntity.fromJson),
      );

      final local = Set<CityEntity>.unmodifiable(_cityBox.getAll());

      final citiesToPut = remote.difference(local);

      for (final city in citiesToPut) {
        final existingCity = local.firstWhereOrNull(
          (test) => test.remoteId == city.remoteId,
        );

        if (existingCity == null) {
          _cityBox.put(city);

          _logger.log(EntityInsertSuccess('city', city.remoteId));
        } else {
          if (existingCity != city) {
            final copy = existingCity.copyWith(
              name: city.name,
              createdAt: city.createdAt,
              modifiedAt: city.modifiedAt,
            );

            _cityBox.put(copy);

            _logger.log(EntityUpdateSuccess('city', city.remoteId));
          }
        }
      }

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const RepositorySyncFailed('city'),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }
}
