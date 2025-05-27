import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/gallery/gallery_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/molis_image/image_supabase_table.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/log_events.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GalleryRepositoryLocal implements GalleryRepository {
  GalleryRepositoryLocal({
    required Supabase supabaseI,
    required ImageSupabaseTable imageSupabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = imageSupabaseTable,
       _attractionBox = objectBoxI.store.box<Attraction>(),
       _imageBox = objectBoxI.store.box<MolisImage>();

  final _log = Logger('GalleryRepositoryLocal');

  final Supabase _supabase;
  final ImageSupabaseTable _supabaseTable;
  final Box<Attraction> _attractionBox;
  final Box<MolisImage> _imageBox;

  @override
  List<MolisImage> getAllImages(AttractionSort sortBy) {
    final attractions = _attractionBox.getAll();

    attractions.sort(
      (a, b) => switch (sortBy) {
        AttractionSort.byName => a.name.compareTo(b.name),
        AttractionSort.byDate => b.modifiedAt.compareTo(a.modifiedAt),
      },
    );

    final images = <MolisImage>[];

    for (final attraction in attractions) {
      images.addAll(attraction.images);
    }
    return images;
  }

  @override
  Future<Result<void>> synchronize() async {
    try {
      _log.info(LogEvents.repositoryUpdate);

      await _synchronize();

      return const Result.success(null);
    } on Exception catch (error) {
      _log.severe(LogEvents.repositoryUpdateError(error));

      return Result.error(error);
    }
  }

  @override
  Future<Result<List<MolisImage>>> getImagesFromAttractionId(int id) async {
    try {
      await _synchronize();
    } on Exception catch (e) {
      return Result.error(e);
    }

    final condition = MolisImage_.backlinkId.equals(id);
    final builder = _imageBox.query(condition).build();
    final query = await builder.findAsync();

    return Result.success(query);
  }

  Future<void> _synchronize() async {
    final images = await _supabase.client
        .from(_supabaseTable.tableName)
        .select();

    /// The set of [MolisImage]s in the remote repository.
    final remote = Set<MolisImage>.unmodifiable(
      images.map<MolisImage>((element) => MolisImage.fromJson(element)),
    );

    /// The set of [MolisImage]s in the local repository copy.
    var local = Set<MolisImage>.unmodifiable(_imageBox.getAll());

    /// Creates a set containing only new / different [MolisImage]s that need
    /// to be inserted / updated in the local repository copy.
    final imagesToPut = remote.difference(local);

    if (imagesToPut.isNotEmpty) {
      for (final image in imagesToPut) {
        /// Inserts or updates the [MolisImage] in the local repository copy
        /// only if it has a valid backlink, e.g. the attraction to which it is
        /// related does exist.
        if (_attractionBox.contains(image.backlinkId)) {
          if (!_imageBox.contains(image.id)) {
            _log.info(
              'Inserting new image with id: ${image.id} and '
              'backlink id: ${image.backlinkId}',
            );

            /// Prepares the other Box this object relates to, to be updated
            /// once this object has been put in its own Box.
            image.attraction.targetId = image.backlinkId;

            _imageBox.put(image);
          } else {
            // At this point the attraction cannot be null.
            final old = _imageBox.get(image.id)!;

            if (old.modifiedAt.toUtc() != image.modifiedAt) {
              _log.info(
                'Updating image with id: ${image.id} and '
                'backlink id: ${image.backlinkId}',
              );

              final copy = old.copyWith(
                title: image.title,
                author: image.author,
                license: image.license,
                licenseUrl: image.licenseUrl,
                url: image.url,
                width: image.width,
                height: image.height,
                createdAt: image.createdAt,
                modifiedAt: image.modifiedAt,
                backlinkId: image.backlinkId,
              );

              _imageBox.put(copy);
            }
          }
        } else {
          if (_imageBox.contains(image.id)) {
            _log.warning(
              'Image with id: ${image.id} does not have a valid backlink and '
              'will be removed from the local copy',
            );

            _imageBox.remove(image.id);
          } else {
            _log.warning(
              'Image with id: ${image.id} does not have a valid backlink and '
              'will not be put',
            );
          }
        }
      }
    }

    /// The set of [MolisImage]s in the local repository copy.
    ///
    /// Once the remote and local repository copy have been synchronized it's
    /// possible to remove the [MolisImage]s not available in the remote
    /// repository anymore from the local repository copy.
    local = Set<MolisImage>.unmodifiable(_imageBox.getAll());

    final danglingImages = local.difference(remote);

    final danglingIds = danglingImages.map((e) => e.id).toList();

    _imageBox.removeMany(danglingIds);

    /// Regenerates the relation to an [Attraction] of any [MolisImage] that
    /// might have been lost during synchronization.
    for (final image in local) {
      if (!image.attraction.hasValue) {
        image.attraction.targetId = image.backlinkId;
        _imageBox.putAsync(image);
      }
    }
  }
}
