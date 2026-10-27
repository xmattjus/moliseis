import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_draft_mapper.dart';
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
