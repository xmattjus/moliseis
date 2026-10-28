import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/utils/result.dart';

/// Persists exact account/target checkpoints without retiring asset owners.
abstract interface class AdminSubmissionDraftRepository {
  /// Returns null only for authoritative absence; unreadable rows are errors.
  Future<Result<AdminSubmissionDraft?>> loadDraft({
    required String accountId,
    int? submissionId,
  });

  /// Resolves an exact account/session even after its target was adopted.
  Future<Result<AdminSubmissionDraft?>> loadDraftBySession({
    required String accountId,
    required String sessionId,
  });

  /// Finds the single account-checked Admin resume hint, never media ownership.
  Future<Result<AdminSubmissionDraft?>> loadNavigationDraft({
    required String accountId,
  });

  /// Replaces only route hints for this account in one local transaction.
  Future<Result<AdminSubmissionDraft>> saveNavigationIntent({
    required AdminDraftOwner owner,
    required String requestNonce,
  });

  /// Removes only the exact request's route hint, preserving any newer hint.
  Future<Result<AdminSubmissionDraft>> clearNavigationIntent({
    required AdminDraftOwner owner,
    required String requestNonce,
  });

  /// Rebinds the retained new owner and every descriptor in one transaction.
  Future<Result<AdminSubmissionDraft>> adoptRemoteIdentity({
    required AdminDraftOwner owner,
    required int submissionId,
    required String attemptId,
    required AdminRemoteBaseline remoteBaseline,
  });

  /// Creates or replaces this exact owner's checkpoint, retaining its identity.
  ///
  /// A different owner at the same account/target is rejected, never adopted.
  Future<Result<void>> saveDraft(AdminSubmissionDraft draft);
}
