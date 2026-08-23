import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
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

  /// Transitions the moderation status of [id].
  Future<Result<void>> changeStatus(int id, AdminSubmissionStatus status);

  /// Persists an uploaded [asset] association for submission [submissionId].
  Future<Result<AdminSubmissionAsset>> addAsset(
    int submissionId,
    SubmissionAsset asset,
  );

  /// Removes the persisted asset association [assetId] from [submissionId].
  Future<Result<void>> deleteAsset(int submissionId, int assetId);
}
