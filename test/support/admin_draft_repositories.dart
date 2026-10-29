import 'dart:io' show File;

import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/admin_submission_staged_asset_repository.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/utils/result.dart';

/// Callback-controlled domain boundary; it makes no ObjectBox claims.
final class FakeAdminDraftRepository implements AdminSubmissionDraftRepository {
  /// Snapshots returned by exact account/target lookup.
  final drafts = <String, AdminSubmissionDraft>{};

  /// Every attempted immutable write, including failed writes.
  final saves = <AdminSubmissionDraft>[];

  /// Number of exact-target lookups.
  int loadCalls = 0;

  /// Optional controlled read, used for initialization interleavings.
  Future<Result<AdminSubmissionDraft?>> Function(String, int?)? onLoad;

  /// Optional controlled resume lookup, without altering exact-target reads.
  Future<Result<AdminSubmissionDraft?>> Function(String, String)?
  onLoadBySession;

  /// Optional barrier before identity adoption commits in this domain fake.
  Future<void> Function()? onAdopt;

  /// Optional controlled write; successful results update [drafts].
  Future<Result<void>> Function(AdminSubmissionDraft)? onSave;

  @override
  Future<Result<AdminSubmissionDraft?>> loadDraft({
    required String accountId,
    int? submissionId,
  }) async {
    loadCalls++;
    if (onLoad case final callback?) {
      return await callback(accountId, submissionId);
    }
    return Result.success(drafts['$accountId/${submissionId ?? 'new'}']);
  }

  @override
  Future<Result<AdminSubmissionDraft?>> loadDraftBySession({
    required String accountId,
    required String sessionId,
  }) async {
    if (onLoadBySession case final callback?) {
      return await callback(accountId, sessionId);
    }
    for (final draft in drafts.values) {
      if (draft.owner.accountId == accountId &&
          draft.owner.sessionId == sessionId) {
        return Result.success(draft);
      }
    }
    return const Result.success(null);
  }

  @override
  Future<Result<AdminSubmissionDraft?>> loadNavigationDraft({
    required String accountId,
  }) async {
    final matches = drafts.values
        .where(
          (draft) =>
              draft.owner.accountId == accountId &&
              draft.navigationIntent != null,
        )
        .toList();
    if (matches.length > 1) return Result.error(Exception('Ambiguous resume.'));
    return Result.success(matches.isEmpty ? null : matches.single);
  }

  @override
  Future<Result<AdminSubmissionDraft>> saveNavigationIntent({
    required AdminDraftOwner owner,
    required String requestNonce,
  }) async {
    final old = drafts[owner.lookupKey];
    if (old == null || old.owner != owner) {
      return Result.error(Exception('Missing owner.'));
    }
    for (final draft in drafts.values.toList()) {
      if (draft.owner.accountId != owner.accountId) continue;
      drafts[draft.owner.lookupKey] = AdminSubmissionDraft(
        owner: draft.owner,
        snapshot: draft.snapshot,
        remoteBaseline: draft.remoteBaseline,
        fieldWriteIntent: draft.fieldWriteIntent,
        navigationIntent: draft.owner == owner
            ? AdminNavigationIntent(requestNonce: requestNonce)
            : null,
      );
    }
    return Result.success(drafts[owner.lookupKey]!);
  }

  @override
  Future<Result<AdminSubmissionDraft>> clearNavigationIntent({
    required AdminDraftOwner owner,
    required String requestNonce,
  }) async {
    final old = drafts[owner.lookupKey];
    if (old == null || old.owner != owner) {
      return Result.error(Exception('Missing owner.'));
    }
    if (old.navigationIntent?.requestNonce != requestNonce) {
      return Result.success(old);
    }
    final next = AdminSubmissionDraft(
      owner: owner,
      snapshot: old.snapshot,
      remoteBaseline: old.remoteBaseline,
      fieldWriteIntent: old.fieldWriteIntent,
    );
    drafts[owner.lookupKey] = next;
    return Result.success(next);
  }

  @override
  Future<Result<AdminSubmissionDraft>> adoptRemoteIdentity({
    required AdminDraftOwner owner,
    required int submissionId,
    required String attemptId,
    required AdminRemoteBaseline remoteBaseline,
  }) async {
    await onAdopt?.call();
    final old = drafts[owner.lookupKey];
    if (old == null ||
        old.owner != owner ||
        old.fieldWriteIntent?.attemptId != attemptId) {
      return Result.error(Exception('Adoption unavailable.'));
    }
    final next = AdminSubmissionDraft(
      owner: AdminDraftOwner(
        accountId: owner.accountId,
        sessionId: owner.sessionId,
        submissionId: submissionId,
      ),
      snapshot: old.snapshot,
      remoteBaseline: remoteBaseline,
      navigationIntent: old.navigationIntent,
    );
    if (drafts.containsKey(next.owner.lookupKey)) {
      return Result.error(Exception('Occupied destination.'));
    }
    drafts.remove(owner.lookupKey);
    drafts[next.owner.lookupKey] = next;
    return Result.success(next);
  }

  @override
  Future<Result<void>> saveDraft(AdminSubmissionDraft draft) async {
    saves.add(draft);
    final result =
        await (onSave?.call(draft) ??
            Future.value(const Result<void>.success(null)));
    if (result is Success<void>) drafts[draft.owner.lookupKey] = draft;
    return result;
  }
}

/// Local-file repository fake for testing orchestration without filesystem IO.
final class FakeAdminStagedAssetRepository
    implements AdminSubmissionStagedAssetRepository {
  /// Persisted-looking descriptors scoped to the exact immutable owner.
  final assets = <AdminDraftOwner, List<AdminSubmissionStagedAsset>>{};

  /// Owners/counts forwarded only after session admission succeeds.
  final acquisitions = <({AdminDraftOwner owner, int associatedCount})>[];

  /// Captured exact-owner removals.
  final removals = <({AdminDraftOwner owner, String digest})>[];

  /// Controlled restoration, independent from draft-read completion.
  Future<Result<List<AdminSubmissionStagedAsset>>> Function(AdminDraftOwner)?
  onReconcile;

  /// Controlled intake; does not read the supplied test file.
  Future<Result<AdminSubmissionStagedAsset>> Function(AdminDraftOwner, int)?
  onAcquire;

  /// Controlled descriptor removal.
  Future<Result<void>> Function(AdminDraftOwner, String)? onRemove;

  /// Optional private-file resolver for orchestration tests.
  Future<Result<File>> Function(AdminSubmissionStagedAsset)? onResolve;

  /// Optional write barrier/failure; success retains existing fake semantics.
  Future<Result<void>> Function(
    AdminSubmissionStagedAsset,
    AdminStagedAssetProgress,
  )?
  onSaveProgress;

  /// Receipt writes attempted in deterministic item order.
  final progressSaves = <AdminStagedAssetProgress>[];

  int _nextDigest = 0;

  @override
  Future<Result<List<AdminSubmissionStagedAsset>>> reconcileAndLoad(
    AdminDraftOwner owner,
  ) async {
    if (onReconcile case final callback?) return await callback(owner);
    return Result.success(List.of(assets[owner] ?? const []));
  }

  @override
  Future<Result<AdminSubmissionStagedAsset>> acquire({
    required AdminDraftOwner owner,
    required File source,
    required int associatedCount,
  }) async {
    acquisitions.add((owner: owner, associatedCount: associatedCount));
    if (onAcquire case final callback?) {
      final result = await callback(owner, associatedCount);
      if (result case Success<AdminSubmissionStagedAsset>(:final value)) {
        final owned = assets.putIfAbsent(owner, () => []);
        if (!owned.contains(value)) owned.add(value);
      }
      return result;
    }
    final owned = assets.putIfAbsent(owner, () => []);
    if (associatedCount + owned.length >= 5) {
      return Result.error(Exception('Capacity unavailable.'));
    }
    final digest = (++_nextDigest).toRadixString(16).padLeft(40, '0');
    final asset = AdminSubmissionStagedAsset(
      owner: owner,
      digest: digest,
      relativePath: '${owner.accountId}/${owner.sessionId}/$digest',
    );
    owned.add(asset);
    return Result.success(asset);
  }

  @override
  Future<Result<void>> remove({
    required AdminDraftOwner owner,
    required String digest,
  }) async {
    removals.add((owner: owner, digest: digest));
    final result =
        await (onRemove?.call(owner, digest) ??
            Future.value(const Result<void>.success(null)));
    if (result is Success<void>) {
      assets[owner]?.removeWhere((asset) => asset.digest == digest);
    }
    return result;
  }

  @override
  Future<Result<void>> saveProgress({
    required AdminSubmissionStagedAsset asset,
    required AdminStagedAssetProgress progress,
  }) async {
    progressSaves.add(progress);
    final result = await onSaveProgress?.call(asset, progress);
    if (result is Error<void>) return result;
    final owned = assets[asset.owner];
    final index =
        owned?.indexWhere((item) => item.digest == asset.digest) ?? -1;
    if (index < 0) return Result.error(Exception('Missing descriptor.'));
    owned![index] = AdminSubmissionStagedAsset(
      owner: asset.owner,
      digest: asset.digest,
      relativePath: asset.relativePath,
      progress: progress,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<File>> resolveAbsolutePath(AdminSubmissionStagedAsset asset) =>
      onResolve?.call(asset) ??
      (throw UnsupportedError('Session tests do not resolve private files.'));
}

/// Pure-domain session fixture using only explicit local repository boundaries.
final class AdminDraftSessionHarness {
  AdminDraftSessionHarness() {
    session = AdminDraftSession(
      draftRepository: drafts,
      stagedAssetRepository: staged,
    );
  }

  /// Configurable domain checkpoint persistence.
  final drafts = FakeAdminDraftRepository();

  /// Configurable domain staged-file persistence.
  final staged = FakeAdminStagedAssetRepository();

  /// The production local orchestrator under test.
  late final AdminDraftSession session;

  /// Stable account A.
  static const accountA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  /// Stable account B.
  static const accountB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  /// An existing target owned locally by account A.
  final owner = AdminDraftOwner(
    accountId: accountA,
    sessionId: '11111111-1111-4111-8111-111111111111',
    submissionId: 7,
  );

  /// Builds one remote observation with stable timestamp for freshness tests.
  AdminRemoteBaseline remote(String name) => AdminRemoteBaseline(
    snapshot: AdminDraftSnapshot(name: name),
    status: AdminSubmissionStatus.pending,
    modifiedAt: DateTime.utc(2026, 10, 20),
  );

  /// Seeds the exact durable checkpoint with a historical remote projection.
  void seed({String name = 'A', String? remoteName = 'A'}) {
    drafts.drafts[owner.lookupKey] = AdminSubmissionDraft(
      owner: owner,
      snapshot: AdminDraftSnapshot(name: name),
      remoteBaseline: remoteName == null ? null : remote(remoteName),
    );
  }
}
