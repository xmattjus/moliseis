import 'package:logging/logging.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/city_supabase_table.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/messages.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CityRepositoryImpl implements CityRepository {
  CityRepositoryImpl({
    required Supabase supabaseI,
    required CitySupabaseTable placeSupabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = placeSupabaseTable,
       _cityBox = objectBoxI.store.box<City>();

  final _log = Logger('CityRepositoryImpl');

  final Supabase _supabase;
  final CitySupabaseTable _supabaseTable;
  final Box<City> _cityBox;

  @override
  Future<Result<void>> synchronize() async {
    _log.info(Messages.repositoryUpdate);

    try {
      final cities = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      final remote = Set<City>.unmodifiable(
        cities.map<City>((element) => City.fromJson(element)),
      );

      final local = Set<City>.unmodifiable(_cityBox.getAll());

      final citiesToPut = remote.difference(local);

      for (final city in citiesToPut) {
        final existingCity = local.where(
          (test) => test.remoteId == city.remoteId,
        );

        if (existingCity.isEmpty) {
          _log.info(Messages.objectInsert('city', city.remoteId));

          _cityBox.put(city);
        } else if (existingCity.length == 1) {
          _log.info(Messages.objectUpdate('city', city.remoteId));

          final copy = existingCity.first.copyWith(
            name: city.name,
            createdAt: city.createdAt,
            modifiedAt: city.modifiedAt,
          );

          _cityBox.put(copy);
        }
      }

      removeLeftovers(_cityBox, remote);

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(Messages.repositoryUpdateException, error, stackTrace);

      return Result.error(error);
    }
  }
}
