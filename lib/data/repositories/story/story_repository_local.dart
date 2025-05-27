import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/story/story_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/story/story.dart';
import 'package:moliseis/domain/models/story/story_supabase_table.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/log_events.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryRepositoryLocal implements StoryRepository {
  StoryRepositoryLocal({
    required Supabase supabaseI,
    required StorySupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _attractionBox = objectBoxI.store.box<Attraction>(),
       _storyBox = objectBoxI.store.box<Story>();

  final _log = Logger('StoryRepositoryLocal');

  final Supabase _supabase;
  final StorySupabaseTable _supabaseTable;
  // The box to which the [Story] box depends upon.
  final Box<Attraction> _attractionBox;
  final Box<Story> _storyBox;

  bool _isInitialized = false;

  @override
  Future<Result<List<Story>>> get allStories => throw UnimplementedError();

  @override
  Future<Result<List<Story>>> getStoriesFromAttractionId(int id) async {
    if (!_isInitialized) {
      try {
        _log.info(LogEvents.repositoryUpdate);

        await _initialize();
        _isInitialized = true;
      } on Exception catch (error) {
        _log.severe(LogEvents.repositoryUpdateError(error));

        return Result.error(error);
      }
    }

    final stories = await _storyBox.getAllAsync();

    final filter = stories
        .where((element) => element.backlinkId == id)
        .toList();

    if (filter.isEmpty) {
      return Result.error(Exception(ArgumentError()));
    }

    return Result.success(filter);
  }

  Future<void> _initialize() async {
    final client = _supabase.client;

    final stories = await client.from(_supabaseTable.tableName).select();

    final remote = Set<Story>.unmodifiable(
      stories.map((element) => Story.fromJson(element)),
    );

    var local = Set<Story>.unmodifiable(_storyBox.getAll());

    final storiesToPut = remote.difference(local);

    if (storiesToPut.isNotEmpty) {
      for (final story in storiesToPut) {
        if (_attractionBox.contains(story.backlinkId)) {
          if (!_storyBox.contains(story.id)) {
            story.attraction.targetId = story.backlinkId;

            _storyBox.putAsync(story);
          } else {
            final old = await _storyBox.getAsync(story.id);

            if (old!.modifiedAt.toUtc() != story.modifiedAt) {
              final copy = old.copyWith(
                title: story.title,
                author: story.author,
                shortDescription: story.shortDescription,
                sources: story.sources,
                backlinkId: story.backlinkId,
                createdAt: story.createdAt,
                modifiedAt: story.modifiedAt,
                attraction: story.attraction,
              );

              _storyBox.putAsync(copy);
            }
          }
        } else {
          _storyBox.removeAsync(story.id);
        }
      }
    }

    local = Set<Story>.unmodifiable(await _storyBox.getAllAsync());

    final danglingStories = local.difference(remote);

    final danglingIds = danglingStories.map((e) => e.id).toList();

    _storyBox.removeManyAsync(danglingIds);
  }
}
