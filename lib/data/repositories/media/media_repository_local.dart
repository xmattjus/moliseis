import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/media/media_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/media/media.dart';
import 'package:moliseis/domain/models/media/media_supabase_table.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/messages.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaRepositoryLocal implements MediaRepository {
  MediaRepositoryLocal({
    required Supabase supabaseI,
    required MediaSupabaseTable imageSupabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = imageSupabaseTable,
       _mediaBox = objectBoxI.store.box<Media>();

  final _log = Logger('MediaRepositoryLocal');

  final Supabase _supabase;
  final MediaSupabaseTable _supabaseTable;
  final Box<Media> _mediaBox;

  @override
  Future<Result<void>> synchronize() async {
    try {
      _log.info(Messages.repositoryUpdate);

      final media = await _supabase.client
          .from(_supabaseTable.tableName)
          .select();

      final remote = Set<Media>.unmodifiable(
        media.map<Media>((element) => Media.fromJson(element)),
      );

      final local = Set<Media>.unmodifiable(_mediaBox.getAll());

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
      _log.severe(Messages.repositoryUpdateException, error, stackTrace);

      return Result.error(error);
    }
  }

  @override
  Future<Result<List<Media>>> getByEventId(int id) async {
    Query<Media>? query;

    try {
      final builder = _mediaBox.query();
      builder.link(Media_.event, Event_.remoteId.equals(id));
      query = builder.build();
      final results = await query.findAsync();
      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
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
    Query<Media>? query;

    try {
      final builder = _mediaBox.query();
      builder.link(Media_.place, Place_.remoteId.equals(id));
      query = builder.build();
      final results = await query.findAsync();
      return Result.success(results);
    } on Exception catch (error, stackTrace) {
      _log.severe(
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
