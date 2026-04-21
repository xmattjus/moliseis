import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/media_supabase_table.dart';
import 'package:moliseis/data/mappers/media_entity_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/messages.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({
    required Talker logger,
    required Supabase supabaseI,
    required MediaSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _log = logger,
       _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _mediaBox = objectBoxI.store.box<MediaEntity>();

  final Talker _log;

  final Supabase _supabase;
  final MediaSupabaseTable _supabaseTable;
  final Box<MediaEntity> _mediaBox;

  @override
  Future<Result<void>> synchronize() async {
    try {
      _log.info(Messages.repositoryUpdate);

      final media = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      final remote = Set<MediaEntity>.unmodifiable(
        media.map<MediaEntity>((element) => MediaEntity.fromJson(element)),
      );

      final local = Set<MediaEntity>.unmodifiable(_mediaBox.getAll());

      final mediaToPut = remote.difference(local);

      for (final media in mediaToPut) {
        final existingMedia = local.where(
          (test) => test.remoteId == media.remoteId,
        );

        if (existingMedia.isEmpty) {
          _log.info(Messages.objectInsert('media', media.remoteId));

          media.place.targetId = media.placeToOneId;
          media.event.targetId = media.eventToOneId;

          _mediaBox.put(media);
        } else if (existingMedia.length == 1) {
          if (existingMedia.first != media) {
            _log.info(
              Messages.objectUpdate('media', existingMedia.first.remoteId),
            );

            final copy = existingMedia.first.copyWith(
              title: media.title,
              author: media.author,
              license: media.license,
              licenseUrl: media.licenseUrl,
              url: media.url,
              width: media.width,
              height: media.height,
              placeToOneId: () => media.placeToOneId,
              eventToOneId: () => media.eventToOneId,
              createdAt: media.createdAt,
              modifiedAt: media.modifiedAt,
            );

            _mediaBox.put(copy);
          }
        }
      }

      removeLeftovers(_mediaBox, remote);

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.error(Messages.repositoryUpdateException, error, stackTrace);

      return Result.error(error);
    }
  }

  @override
  Future<Result<List<Media>>> getByEventId(int id) async {
    Query<MediaEntity>? query;

    try {
      final builder = _mediaBox.query();
      builder.link(MediaEntity_.event, EventEntity_.remoteId.equals(id));
      query = builder.build();
      final results = await query.findAsync();
      final mappedResults = results
          .map<Media>((MediaEntity entity) => entity.toModel())
          .toList();
      return Result.success(mappedResults);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while getting media by event with remote ID: $id.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }

  @override
  Future<Result<List<Media>>> getByPlaceId(int id) async {
    Query<MediaEntity>? query;

    try {
      final builder = _mediaBox.query();
      builder.link(MediaEntity_.place, PlaceEntity_.remoteId.equals(id));
      query = builder.build();
      final results = await query.findAsync();
      final mappedResults = results
          .map<Media>((MediaEntity entity) => entity.toModel())
          .toList();
      return Result.success(mappedResults);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while getting media by place with remote ID: $id.',
        error,
        stackTrace,
      );
      return Result.error(error);
    } finally {
      query?.close();
    }
  }
}
