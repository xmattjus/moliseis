import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/utils/result.dart';

/// Persists exact account/target checkpoints without retiring asset owners.
abstract interface class AdminSubmissionDraftRepository {
  /// Returns null only for authoritative absence; unreadable rows are errors.
  Future<Result<AdminSubmissionDraft?>> loadDraft({
    required String accountId,
    int? submissionId,
  });

  /// Creates or replaces this exact owner's checkpoint, retaining its identity.
  ///
  /// A different owner at the same account/target is rejected, never adopted.
  Future<Result<void>> saveDraft(AdminSubmissionDraft draft);
}
