import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/data/data-sources/admin_submission_staged_asset_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_draft_mapper.dart';
import 'package:moliseis/data/mappers/admin_submission_staged_asset_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

/// Exact-owner checkpoint persistence with no implicit retirement or cleanup.
final class AdminSubmissionDraftRepositoryImpl
    implements AdminSubmissionDraftRepository {
  /// Uses the existing store; construction performs no reads or initialization.
  AdminSubmissionDraftRepositoryImpl({
    required ObjectBox objectBoxI,
    required Logger logger,
  }) : _store = objectBoxI.store,
       _box = objectBoxI.store.box<AdminSubmissionDraftEntity>(),
       _logger = logger;

  final Store _store;
  final Box<AdminSubmissionDraftEntity> _box;
  final Logger _logger;

  /// Returns authoritative absence only after a successful exact-target read.
  @override
  Future<Result<AdminSubmissionDraft?>> loadDraft({
    required String accountId,
    int? submissionId,
  }) async {
    if (_store.isClosed()) return _failure('load', 'ClosedStore');
    try {
      _validateTarget(accountId, submissionId);
      final rows = _findTarget(accountId, submissionId);
      if (rows.length > 1) {
        throw const FormatException('Conflicting Admin draft owners.');
      }
      return Result.success(rows.isEmpty ? null : rows.single.toModel());
    } on Exception catch (error) {
      return _failure('load', error.runtimeType.toString());
    }
  }

  @override
  Future<Result<AdminSubmissionDraft?>> loadDraftBySession({
    required String accountId,
    required String sessionId,
  }) async {
    if (_store.isClosed()) return _failure('resume', 'ClosedStore');
    try {
      _validateTarget(accountId, null);
      if (!AdminDraftOwner.isValidSessionId(sessionId)) {
        throw const FormatException('Invalid Admin resume identity.');
      }
      final query = _box
          .query(AdminSubmissionDraftEntity_.sessionId.equals(sessionId))
          .build();
      try {
        final rows = query.find();
        if (rows.length > 1) {
          throw const FormatException('Conflicting sessions.');
        }
        if (rows.isEmpty || rows.single.accountId != accountId) {
          return const Result.success(null);
        }
        return Result.success(rows.single.toModel());
      } finally {
        query.close();
      }
    } on Exception catch (error) {
      return _failure('resume', error.runtimeType.toString());
    }
  }

  @override
  Future<Result<AdminSubmissionDraft?>> loadNavigationDraft({
    required String accountId,
  }) async {
    if (_store.isClosed()) return _failure('resume', 'ClosedStore');
    try {
      _validateTarget(accountId, null);
      final drafts = _accountRows(accountId)
          .map((row) => row.toModel())
          .where((draft) => draft.navigationIntent != null)
          .toList();
      if (drafts.length > 1) {
        throw const FormatException('Ambiguous Admin resume.');
      }
      return Result.success(drafts.isEmpty ? null : drafts.single);
    } on Exception catch (error) {
      return _failure('resume', error.runtimeType.toString());
    }
  }

  @override
  Future<Result<AdminSubmissionDraft>> saveNavigationIntent({
    required AdminDraftOwner owner,
    required String requestNonce,
  }) async {
    if (_store.isClosed()) return _failure('navigation', 'ClosedStore');
    try {
      final intent = AdminNavigationIntent(requestNonce: requestNonce);
      final result = _store.runInTransaction(TxMode.write, () {
        final rows = _accountRows(owner.accountId);
        final target = rows
            .where((row) => row.toModel().owner == owner)
            .toList();
        if (target.length != 1) {
          throw const FormatException('Navigation owner missing.');
        }
        late AdminSubmissionDraft selected;
        for (final row in rows) {
          final draft = row.toModel();
          final isTarget = draft.owner == owner;
          if (!isTarget && draft.navigationIntent == null) continue;
          final next = AdminSubmissionDraft(
            owner: draft.owner,
            snapshot: draft.snapshot,
            remoteBaseline: draft.remoteBaseline,
            fieldWriteIntent: draft.fieldWriteIntent,
            navigationIntent: isTarget ? intent : null,
          );
          _box.put(next.toEntity(id: row.id));
          if (isTarget) selected = next;
        }
        return selected;
      });
      return Result.success(result);
    } on Exception catch (error) {
      return _failure('navigation', error.runtimeType.toString());
    }
  }

  @override
  Future<Result<AdminSubmissionDraft>> clearNavigationIntent({
    required AdminDraftOwner owner,
    required String requestNonce,
  }) async {
    if (_store.isClosed()) return _failure('navigation', 'ClosedStore');
    try {
      final result = _store.runInTransaction(TxMode.write, () {
        final rows = _findTarget(owner.accountId, owner.submissionId);
        if (rows.length != 1 || rows.single.toModel().owner != owner) {
          throw const FormatException('Navigation owner missing.');
        }
        final old = rows.single.toModel();
        if (old.navigationIntent?.requestNonce != requestNonce) return old;
        final next = AdminSubmissionDraft(
          owner: owner,
          snapshot: old.snapshot,
          remoteBaseline: old.remoteBaseline,
          fieldWriteIntent: old.fieldWriteIntent,
        );
        _box.put(next.toEntity(id: rows.single.id));
        return next;
      });
      return Result.success(result);
    } on Exception catch (error) {
      return _failure('navigation', error.runtimeType.toString());
    }
  }

  List<AdminSubmissionDraftEntity> _accountRows(String accountId) {
    final query = _box
        .query(AdminSubmissionDraftEntity_.accountId.equals(accountId))
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  Future<Result<AdminSubmissionDraft>> adoptRemoteIdentity({
    required AdminDraftOwner owner,
    required int submissionId,
    required String attemptId,
    required AdminRemoteBaseline remoteBaseline,
  }) async {
    if (_store.isClosed()) return _failure('adopt', 'ClosedStore');
    try {
      _validateTarget(owner.accountId, submissionId);
      if (!AdminDraftOwner.isValidSessionId(attemptId) ||
          (owner.submissionId != null && owner.submissionId != submissionId)) {
        throw const FormatException('Invalid adoption target.');
      }
      final adopted = _store.runInTransaction(TxMode.write, () {
        final query = _box
            .query(
              AdminSubmissionDraftEntity_.sessionId.equals(owner.sessionId),
            )
            .build();
        late AdminSubmissionDraftEntity row;
        try {
          final rows = query.find();
          if (rows.length != 1) {
            throw const FormatException('Missing adoption owner.');
          }
          row = rows.single;
        } finally {
          query.close();
        }
        final draft = row.toModel();
        final nextOwner = AdminDraftOwner(
          accountId: owner.accountId,
          sessionId: owner.sessionId,
          submissionId: submissionId,
        );
        if (draft.owner == nextOwner) return draft;
        if (draft.owner != owner ||
            owner.submissionId != null ||
            draft.fieldWriteIntent?.kind != AdminFieldWriteKind.create ||
            draft.fieldWriteIntent?.attemptId != attemptId) {
          throw const FormatException('Adoption authority mismatch.');
        }
        if (_findTarget(owner.accountId, submissionId).isNotEmpty) {
          throw const FormatException('Adoption destination occupied.');
        }
        final assets = _store.box<AdminSubmissionStagedAssetEntity>();
        final assetQuery = assets
            .query(
              AdminSubmissionStagedAssetEntity_.sessionId.equals(
                owner.sessionId,
              ),
            )
            .build();
        try {
          for (final descriptor in assetQuery.find()) {
            final model = descriptor.toModel();
            if (model == null ||
                model.owner != owner ||
                model.progressInvalid) {
              throw const FormatException('Malformed adoption descriptor.');
            }
            assets.put(
              AdminSubmissionStagedAssetEntity(
                id: descriptor.id,
                accountId: descriptor.accountId,
                sessionId: descriptor.sessionId,
                submissionId: submissionId,
                digest: descriptor.digest,
                relativePath: descriptor.relativePath,
                progressPayload: descriptor.progressPayload,
              ),
            );
          }
        } finally {
          assetQuery.close();
        }
        final result = AdminSubmissionDraft(
          owner: nextOwner,
          snapshot: draft.snapshot,
          remoteBaseline: remoteBaseline,
          navigationIntent: draft.navigationIntent,
        );
        _box.put(result.toEntity(id: row.id));
        return result;
      });
      return Result.success(adopted);
    } on Exception catch (error) {
      return _failure('adopt', error.runtimeType.toString());
    }
  }

  /// Replaces one checkpoint atomically without changing its technical ID.
  @override
  Future<Result<void>> saveDraft(AdminSubmissionDraft draft) async {
    if (_store.isClosed()) return _failure('checkpoint', 'ClosedStore');
    try {
      _store.runInTransaction(TxMode.write, () {
        final owner = draft.owner;
        final rows = _findTarget(owner.accountId, owner.submissionId);
        if (rows.length > 1) {
          throw const FormatException('Conflicting Admin draft owners.');
        }
        if (rows.isNotEmpty && rows.single.toModel().owner != owner) {
          throw const FormatException(
            'Admin target belongs to another session.',
          );
        }
        _box.put(draft.toEntity(id: rows.isEmpty ? 0 : rows.single.id));
      });
      return const Result.success(null);
    } on Exception catch (error) {
      return _failure('checkpoint', error.runtimeType.toString());
    }
  }

  List<AdminSubmissionDraftEntity> _findTarget(String accountId, int? target) {
    final lookupKey = '$accountId/${target ?? 'new'}';
    final query = _box
        .query(
          AdminSubmissionDraftEntity_.accountId
              .equals(accountId)
              .or(AdminSubmissionDraftEntity_.lookupKey.equals(lookupKey)),
        )
        .build();
    try {
      // Match raw ownership before decoding, so malformed/unsupported payloads
      // at the requested target cannot masquerade as authoritative absence.
      return query
          .find()
          .where(
            (row) =>
                (row.accountId == accountId && row.submissionId == target) ||
                row.lookupKey == lookupKey,
          )
          .toList();
    } finally {
      query.close();
    }
  }

  void _validateTarget(String accountId, int? target) {
    if (!AdminDraftOwner.isValidAccountId(accountId) ||
        (target != null && target <= 0)) {
      throw const FormatException('Invalid Admin lookup target.');
    }
  }

  Result<T> _failure<T>(String operation, String errorType) {
    _logger.log(
      AdminLocalStorageFailed(operation: 'draft_$operation'),
      extra: {'errorType': errorType},
    );
    return Result.error(Exception('Admin draft $operation unavailable.'));
  }
}
