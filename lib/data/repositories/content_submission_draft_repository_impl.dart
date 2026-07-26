import 'dart:async';

import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/data/mappers/content_submission_draft_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

class ContentSubmissionDraftRepositoryImpl
    implements ContentSubmissionDraftRepository {
  ContentSubmissionDraftRepositoryImpl({
    required Logger logger,
    required ObjectBox objectBoxI,
  }) : _logger = logger,
       _box = objectBoxI.store.box<ContentSubmissionDraftEntity>();

  final Logger _logger;
  final Box<ContentSubmissionDraftEntity> _box;

  @override
  Future<Result<void>> clearDraft() async {
    _logger.log(const ContentSubmissionDraftClearStarted());

    try {
      await _box.removeAsync(1);
      _logger.log(const ContentSubmissionDraftClearSuccess());
      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionDraftClearFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<ContentSubmissionDraft?>> loadDraft() async {
    _logger.log(const ContentSubmissionDraftLoadStarted());

    try {
      ContentSubmissionDraft? state;
      final draft = await _box.getAsync(1);
      if (draft != null) {
        state = draft.toModel();
      }
      _logger.log(const ContentSubmissionDraftLoadSuccess());
      return Result.success(state);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionDraftLoadFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<void>> saveDraft(ContentSubmissionDraft state) async {
    _logger.log(ContentSubmissionDraftSaveStarted(draft: state.toString()));

    try {
      final draft = state.toEntity();
      await _box.putAsync(draft);
      _logger.log(ContentSubmissionDraftSaveSuccess(draft: state.toString()));
      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionDraftSaveFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }
}
