import 'dart:io' show File;

import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/utils/result.dart';

/// Owns private files and descriptors, without platform or remote operations.
///
/// Compound calls are ordered by the local Admin draft session. Existing-target
/// capacity is already qualified against its activation and accepted context
/// there; storage independently rechecks durable ownership and combined count.
abstract interface class AdminSubmissionStagedAssetRepository {
  /// Restores verified exact-owner files without sweeping other sessions.
  Future<Result<List<AdminSubmissionStagedAsset>>> reconcileAndLoad(
    AdminDraftOwner owner,
  );

  /// Acquires a supplied file after durable-owner and capacity verification.
  Future<Result<AdminSubmissionStagedAsset>> acquire({
    required AdminDraftOwner owner,
    required File source,
    required int associatedCount,
  });

  /// Monotonically records remote confirmation on an exact retained descriptor.
  Future<Result<void>> saveProgress({
    required AdminSubmissionStagedAsset asset,
    required AdminStagedAssetProgress progress,
  });

  /// Resolves a structurally contained file without following owned links.
  Future<Result<File>> resolveAbsolutePath(AdminSubmissionStagedAsset asset);

  /// Removes exact descriptor ownership before best-effort file cleanup.
  Future<Result<void>> remove({
    required AdminDraftOwner owner,
    required String digest,
  });
}
