import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/result.dart';

/// Administration access to content submissions.
///
/// Backend-agnostic on purpose: no endpoint names, table names, or DTO shapes
/// are committed to here. The production implementation is a typed-error
/// placeholder until the backend round defines the contract.
abstract class AdminContentSubmissionRepository {
  /// Lists submissions for moderation.
  Future<Result<List<AdminSubmission>>> list();

  /// Loads one submission for editing.
  Future<Result<AdminSubmission>> getById(int id);

  /// Creates a submission from the editable [input].
  ///
  /// Contributor identity is not part of [input]; the future backend derives it
  /// from the authenticated session.
  Future<Result<AdminSubmission>> create(AdminSubmissionInput input);

  /// Updates the editable fields of submission [id].
  Future<Result<AdminSubmission>> update(int id, AdminSubmissionInput input);

  /// Rejects the pending submission [id].
  ///
  /// Rejection is the only non-promotion moderation transition; acceptance is
  /// reachable through [promote], [link] or [apply], so this interface
  /// cannot express
  /// a direct pending-to-accepted operation.
  Future<Result<AdminEventResolution>> reject(
    int id, {
    bool? ignoreSource,
    bool? acknowledgeCurrentSource,
    String? expectedSourceHash,
  });

  /// Publishes the clean, pending submission [id] as the kind of entity named
  /// by [target].
  ///
  /// Returns the durable promotion pointing at the created place or event;
  /// an idempotent same-target retry reports the original promotion exactly
  /// like a first success.
  Future<Result<AdminSubmissionPromotion>> promote(
    int id,
    AdminPromotionTarget target, {
    bool? acknowledgeCurrentSource,
    String? expectedSourceHash,
  });

  /// Returns advisory matches; pending submissions are not link targets.
  Future<Result<AdminEventCandidates>> eventCandidates(
    int id, {
    String? searchName,
    int? targetEventId,
  });

  /// Loads the backend-computed merge and its opaque concurrency tokens.
  Future<Result<AdminEventMergePreview>> mergePreview(
    int id,
    int targetEventId,
  );

  /// Accepts an Event-like submission against an existing Event.
  Future<Result<AdminEventResolution>> link(
    int id,
    int targetEventId, {
    bool? acknowledgeCurrentSource,
    String? expectedSourceHash,
  });

  /// Applies a preview using its original tokens; groups remain server-owned.
  Future<Result<AdminEventResolution>> apply(
    int id,
    AdminEventMergePreview preview, {
    bool? acknowledgeCurrentSource,
    String? expectedSourceHash,
  });

  /// Lists ignored sources even when they have no pending proposal.
  Future<Result<List<AdminIgnoredSource>>> listIgnoredSources();

  /// Removes ignore and immediately asks the backend to reevaluate the source.
  Future<Result<AdminEventResolution>> unIgnoreSource(int recordId);

  /// Persists an uploaded [asset] association for submission [submissionId].
  Future<Result<AdminSubmissionAsset>> addAsset(
    int submissionId,
    SubmissionAsset asset,
  );

  /// Removes the persisted asset association [assetId] from [submissionId].
  Future<Result<void>> deleteAsset(int submissionId, int assetId);
}
