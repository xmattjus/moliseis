import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/story/paragraph_repository.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/paragraph/paragraph.dart';
import 'package:moliseis/domain/models/paragraph/paragraph_supabase_table.dart';
import 'package:moliseis/domain/models/story/story.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/log_events.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParagraphRepositoryLocal implements ParagraphRepository {
  ParagraphRepositoryLocal({
    required Supabase supabaseI,
    required ParagraphSupabaseTable supabaseTable,
    required ObjectBox objectBoxI,
  }) : _supabase = supabaseI,
       _supabaseTable = supabaseTable,
       _storyBox = objectBoxI.store.box<Story>(),
       _paragraphBox = objectBoxI.store.box<Paragraph>();

  final Supabase _supabase;
  final ParagraphSupabaseTable _supabaseTable;
  // The box to which the [Story] box depends upon.
  final Box<Story> _storyBox;
  final Box<Paragraph> _paragraphBox;

  bool _isInitialized = false;
  final _logger = Logger('ParagraphRepositoryLocal');

  @override
  Future<Result<List<Paragraph>>> getParagraphsFromStoryId(int id) async {
    if (!_isInitialized) {
      try {
        _logger.info(LogEvents.repositoryUpdate);

        await _initialize();
        _isInitialized = true;
      } on Exception catch (error) {
        _logger.severe(LogEvents.repositoryUpdateError(error));

        return Result.error(error);
      }
    }

    final paragraphs = await _paragraphBox.getAllAsync();

    final filter = paragraphs
        .where((element) => element.backlinkId == id)
        .toList();

    return Result.success(filter);
  }

  Future<void> _initialize() async {
    final client = _supabase.client;

    final paragraphs = await client.from(_supabaseTable.tableName).select();

    final remote = Set<Paragraph>.unmodifiable(
      paragraphs.map((e) => Paragraph.fromJson(e)),
    );

    var local = Set<Paragraph>.unmodifiable(await _paragraphBox.getAllAsync());

    final paragraphsToPut = remote.difference(local);

    if (paragraphsToPut.isNotEmpty) {
      for (final paragraph in paragraphsToPut) {
        if (_storyBox.contains(paragraph.backlinkId)) {
          if (!_paragraphBox.contains(paragraph.id)) {
            paragraph.story.targetId = paragraph.backlinkId;

            _paragraphBox.put(paragraph);
          } else {
            final old = _paragraphBox.get(paragraph.id);

            if (old!.modifiedAt.toUtc() != paragraph.modifiedAt) {
              final copy = old.copyWith(
                heading: paragraph.heading,
                subheading: paragraph.subheading,
                body: paragraph.body,
                backlinkId: paragraph.backlinkId,
                createdAt: paragraph.createdAt,
                modifiedAt: paragraph.modifiedAt,
                story: paragraph.story,
              );

              _paragraphBox.put(copy);
            }
          }
        } else {
          _paragraphBox.remove(paragraph.id);
        }
      }
    }

    local = Set<Paragraph>.unmodifiable(await _paragraphBox.getAllAsync());

    final danglingParagraphs = local.difference(remote);

    final danglingIds = danglingParagraphs.map((e) => e.id).toList();

    _paragraphBox.removeMany(danglingIds);
  }
}
