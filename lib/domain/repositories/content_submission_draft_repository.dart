import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/utils/result.dart';

abstract interface class ContentSubmissionDraftRepository {
  Future<Result<ContentSubmissionDraft?>> loadDraft();

  Future<Result<void>> saveDraft(
    ContentSubmissionDraft state,
  );

  Future<Result<void>> clearDraft();
}
