import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/domain/models/place/place_supabase_table.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/log_events.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaceRepositoryLocal implements PlaceRepository {
  PlaceRepositoryLocal({
    required Supabase supabaseI,
    required PlaceSupabaseTable placeSupabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = placeSupabaseTable,
       _placeBox = objectBoxI.store.box<Place>(),
       _attractionBox = objectBoxI.store.box<Attraction>();

  final Supabase _supabase;
  final PlaceSupabaseTable _supabaseTable;
  final Box<Place> _placeBox;
  final Box<Attraction> _attractionBox;
  final _logger = Logger('PlaceRepositoryLocal');

  @override
  Future<Result<void>> synchronize() async {
    _logger.info(LogEvents.repositoryUpdate);

    try {
      final places =
          await _supabase.client.from(_supabaseTable.tableName).select();

      /// The set of [Place]s in the remote repository.
      final remote = Set<Place>.unmodifiable(
        places.map<Place>((element) => Place.fromJson(element)),
      );

      /// The set of [Place]s in the local repository copy.
      var local = Set<Place>.unmodifiable(_placeBox.getAll());

      /// Creates a set containing only new / different [Place]s that need to be
      /// inserted / updated in the local repository copy.
      final placesToPut = remote.difference(local);

      if (placesToPut.isNotEmpty) {
        for (final place in remote) {
          final old = _placeBox.get(place.id);

          final attractions =
              _attractionBox
                  .getAll()
                  .where((e) => e.backlinkId == place.id)
                  .toList();

          if (attractions.isNotEmpty) {
            /// Prepares the other Box this object relates to, to be updated
            /// once his object has been put in its own Box.
            place.attractions.addAll(attractions);

            if (old == null) {
              _logger.info('Inserting new place with id: ${place.id}');

              _placeBox.put(place);
            } else {
              if (old != place) {
                _logger.info('Updating place with id: ${place.id}');

                _placeBox.put(place);
              }
            }
          } else {
            if (_placeBox.contains(place.id)) {
              _logger.warning(
                'Place with id: ${place.id} does not have a valid backlink and '
                'will be removed',
              );

              _placeBox.remove(place.id);
            } else {
              _logger.warning(
                'Place with id: ${place.id} does not have a valid backlink and '
                'will not be put',
              );
            }
          }
        }
      }

      /// The set of [Place]s in the local repository copy.
      ///
      /// Once the remote and local repository copy have been synchronized it's
      /// possible to remove the [Place]s not available in the remote repository
      /// anymore from the local repository copy.
      local = Set<Place>.unmodifiable(_placeBox.getAll());

      final danglingPlaces = local.difference(remote);

      final danglingIds = danglingPlaces.map((e) => e.id).toList();

      _placeBox.removeMany(danglingIds);

      /// Regenerates the relations to the [Attraction]s of any [Place] that
      /// might have been lost during synchronization.
      for (final place in local) {
        if (place.attractions.isEmpty) {
          final attractions =
              _attractionBox
                  .getAll()
                  .where((e) => e.backlinkId == place.id)
                  .toList();
          place.attractions.addAll(attractions);
          _placeBox.put(place);
        }
      }

      return const Result.success(null);
    } on Exception catch (error) {
      _logger.severe(LogEvents.repositoryUpdateError(error));

      return Result.error(error);
    }
  }

  @override
  Future<Place> getPlaceFromAttractionId(int id) async {
    final builder = _placeBox.query(Place_.id.greaterThan(0));
    builder.backlink(Attraction_.place, Attraction_.id.equals(id));
    final query = builder.build();

    try {
      final place = await query.findUniqueAsync();

      query.close();

      if (place == null) {
        return Future.error(PlaceNullException(id));
      }

      return place;
    } catch (error) {
      rethrow;
    }
  }
}
