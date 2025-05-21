import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/attraction/attraction_supabase_table.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/log_events.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttractionRepositoryLocal implements AttractionRepository {
  AttractionRepositoryLocal({
    required Supabase supabaseI,
    required AttractionSupabaseTable attractionSupabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = attractionSupabaseTable,
       _attractionBox = objectBoxI.store.box<Attraction>();

  final Supabase _supabase;
  final AttractionSupabaseTable _supabaseTable;
  final Box<Attraction> _attractionBox;
  final _logger = Logger('AttractionRepositoryLocal');

  @override
  Future<List<Attraction>> getAll(AttractionSort sortBy) async {
    final attractions = await _attractionBox.getAllAsync();

    attractions.sort(
      (a, b) => switch (sortBy) {
        AttractionSort.byName => a.name.compareTo(b.name),
        AttractionSort.byDate => b.modifiedAt.compareTo(a.modifiedAt),
      },
    );

    return attractions;
  }

  @override
  int getTypeIndexFromAttractionId(int id) {
    final attraction = _attractionBox.get(id);
    return attraction?.type.index ?? AttractionType.unknown.index;
  }

  @override
  Future<List<int>> getAttractionIdsByType(
    AttractionType type,
    AttractionSort orderBy,
  ) async {
    final condition = Attraction_.dbType.equals(type.index);
    final queryBuilder = _attractionBox
        .query(condition)
        .order(
          orderBy == AttractionSort.byName
              ? Attraction_.name
              : Attraction_.modifiedAt,
          flags: orderBy == AttractionSort.byDate
              ? Order.descending
              : Order.unsigned,
        );
    final query = queryBuilder.build();

    final results = await query.findIdsAsync();

    query.close();

    return Future.value(results);
  }

  @override
  Future<Result<Attraction>> getById(int id) async {
    final attraction = await _attractionBox.getAsync(id);

    if (attraction != null) {
      return Result.success(attraction);
    } else {
      return Result.error(AttractionNullException(id));
    }
  }

  @override
  Future<List<int>> getNearAttractionIds(List<double> coordinates) async {
    final query = _attractionBox
        .query(Attraction_.coordinates.nearestNeighborsF32(coordinates, 3))
        .build();
    final results = await query.findIdsWithScoresAsync();
    query.close();

    return results.map<int>((element) => element.id).toList();
  }

  @override
  Future<Result<void>> synchronize() async {
    _logger.info(LogEvents.repositoryUpdate);

    try {
      final attractions = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      /// The set of [Attraction]s in the remote repository.
      final remote = Set<Attraction>.unmodifiable(
        attractions.map<Attraction>((element) => Attraction.fromJson(element)),
      );

      /// The set of [Attraction]s in the local repository copy.
      var local = Set<Attraction>.unmodifiable(_attractionBox.getAll());

      /// Creates a set containing only new / different [Attraction]s that need to
      /// be inserted / updated in the local repository copy.
      final attractionsToPut = remote.difference(local);

      if (attractionsToPut.isNotEmpty) {
        for (final attraction in attractionsToPut) {
          attraction.place.targetId = attraction.backlinkId;

          final old = _attractionBox.get(attraction.id);

          if (old == null) {
            _logger.info('Inserting new attraction with id: ${attraction.id}');

            _attractionBox.put(attraction);
          } else {
            if (old != attraction) {
              _logger.info('updating attraction with id: ${attraction.id}');

              final updated = old.copyWith(
                name: attraction.name,
                summary: attraction.summary,
                description: attraction.description,
                history: attraction.history,
                coordinates: attraction.coordinates,
                type: attraction.type,
                sources: attraction.sources,
                backlinkId: attraction.backlinkId,
                createdAt: attraction.createdAt,
                modifiedAt: attraction.modifiedAt,
                isSaved: old.isSaved,
              );

              _attractionBox.put(updated);
            }
          }
        }
      }

      /// The set of [Attraction]s in the local repository copy.
      ///
      /// Once the remote and local repository copy have been synchronized it's
      /// possible to remove the [Attraction]s not available in the remote
      /// repository anymore from the local repository copy.
      local = Set<Attraction>.unmodifiable(_attractionBox.getAll());

      final danglingAttractions = local.difference(remote);

      final danglingIds = danglingAttractions.map((e) => e.id).toList();

      _attractionBox.removeMany(danglingIds);

      return const Result.success(null);
    } on Exception catch (error) {
      _logger.severe(LogEvents.repositoryUpdateError(error));

      return Result.error(error);
    }
  }

  @override
  Future<List<int>> get latestAttractionsIds async {
    final query = _attractionBox.query().order(
      Attraction_.modifiedAt,
      flags: Order.descending,
    );
    final builder = query.build()..limit = 6;
    final attractions = await builder.findIdsAsync();
    builder.close();
    return attractions;
  }

  @override
  List<int> get savedAttractionIds {
    final query = _attractionBox
        .query(Attraction_.isSaved.equals(true))
        .build();
    // Casts the query results to a growable list with toList().
    final attractions = query.findIds().toList();
    query.close();
    return attractions;
  }

  @override
  Future<void> setSavedAttraction(int id, bool save) async {
    final attraction = await _attractionBox.getAsync(id);

    if (attraction != null) {
      final copy = attraction.copyWith(isSaved: save);

      _attractionBox.putAsync(copy, mode: PutMode.update);
    } else {
      return Future.error(AttractionNullException(id));
    }
  }

  @override
  Future<List<int>> get suggestedAttractionsIds async {
    final query = _attractionBox.query();
    final builder = query.build()..limit = 5;
    final attractions = await builder.findIdsAsync();
    builder.close();
    return attractions..shuffle();
  }
}
