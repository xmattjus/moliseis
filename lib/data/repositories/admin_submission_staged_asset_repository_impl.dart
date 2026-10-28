import 'dart:io';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' show sha1;
import 'package:moliseis/data/data-sources/admin_submission_staged_asset_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_staged_asset_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/admin_submission_staged_asset_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;

/// Exact-owner ObjectBox descriptors and verified private Admin file copies.
///
/// The session owns cross-operation arbitration. No inactive session is swept,
/// and no local operation can retire its durable owner.
final class AdminSubmissionStagedAssetRepositoryImpl
    implements AdminSubmissionStagedAssetRepository {
  /// Builds unregistered storage with injectable app-support lookup.
  AdminSubmissionStagedAssetRepositoryImpl({
    required Logger logger,
    required ObjectBox objectBoxI,
    required AdminSubmissionDraftRepository draftRepository,
    Future<Directory> Function()? getSupportDirectory,
  }) : _logger = logger,
       _store = objectBoxI.store,
       _box = objectBoxI.store.box<AdminSubmissionStagedAssetEntity>(),
       _drafts = draftRepository,
       _getSupportDirectory =
           getSupportDirectory ?? getApplicationSupportDirectory;

  final Logger _logger;
  final Store _store;
  final Box<AdminSubmissionStagedAssetEntity> _box;
  final AdminSubmissionDraftRepository _drafts;
  final Future<Directory> Function() _getSupportDirectory;

  @override
  Future<Result<AdminSubmissionStagedAsset>> acquire({
    required AdminDraftOwner owner,
    required File source,
    required int associatedCount,
  }) async {
    File? temporary;
    try {
      await _requireOwner(owner);
      if (associatedCount < 0 ||
          associatedCount > 5 ||
          (owner.submissionId == null && associatedCount != 0)) {
        throw const FormatException('Unavailable capacity.');
      }
      if (await source.length() > kCloudinaryMaxUploadBytes) {
        throw const FormatException('Source exceeds size limit.');
      }
      final digest = (await sha1.bind(source.openRead()).first).toString();
      final asset = AdminSubmissionStagedAsset(
        owner: owner,
        digest: digest,
        relativePath: '${owner.accountId}/${owner.sessionId}/$digest',
      );
      final restored = await _reconcile(owner);
      for (final existing in restored) {
        if (existing.digest == digest) return Result.success(existing);
      }
      if (restored
                  .where((asset) => asset.progress?.associationId == null)
                  .length +
              associatedCount >=
          5) {
        throw const FormatException('Asset capacity exhausted.');
      }
      final directory = await _directory(owner, create: true);
      final finalFile = File(p.join(directory!.path, digest));
      await _rejectLink(finalFile.path);
      temporary = File(p.join(directory.path, '.$digest.${_randomHex()}.tmp'));
      await temporary.create(exclusive: true);
      final output = await temporary.open(mode: FileMode.writeOnly);
      try {
        await for (final bytes in source.openRead()) {
          await output.writeFrom(bytes);
          if (await output.position() > kCloudinaryMaxUploadBytes) {
            throw const FormatException('Copy exceeds size limit.');
          }
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (!await _validFile(temporary, digest)) {
        throw const FormatException('Copy failed integrity verification.');
      }
      await temporary.rename(finalFile.path);
      temporary = null;
      _ensureOpen();
      await _box.putAsync(asset.toEntity());
      return Result.success(asset);
    } on Exception catch (error) {
      if (temporary != null) {
        await _cleanup(temporary, 'acquire_temp_cleanup');
      }
      return _failure('acquire', error);
    }
  }

  @override
  Future<Result<List<AdminSubmissionStagedAsset>>> reconcileAndLoad(
    AdminDraftOwner owner,
  ) async {
    try {
      await _requireOwner(owner);
      return Result.success(await _reconcile(owner));
    } on Exception catch (error) {
      return _failure('reconcile', error);
    }
  }

  Future<List<AdminSubmissionStagedAsset>> _reconcile(
    AdminDraftOwner owner,
  ) async {
    final restored = <AdminSubmissionStagedAsset>[];
    final digests = <String>{};
    for (final row in await _rows(owner)) {
      final asset = row.toModel();
      if (asset == null || asset.owner != owner) {
        await _removeRow(row.id);
        continue;
      }
      if (digests.contains(asset.digest)) {
        await _removeRow(row.id);
        continue;
      }
      final file = await _file(asset, create: false);
      if (file == null || !await _validFile(file, asset.digest)) {
        if (file != null) await _cleanup(file, 'invalid_file_cleanup');
        // A confirmed upload is sufficient for replay-safe association. Never
        // erase remote progress merely because its former source disappeared.
        if (asset.progress != null || asset.progressInvalid) {
          digests.add(asset.digest);
          restored.add(asset);
          continue;
        }
        await _removeRow(row.id);
        continue;
      }
      digests.add(asset.digest);
      restored.add(asset);
    }
    final directory = await _directory(owner, create: false);
    if (directory != null) {
      await for (final entry in directory.list(followLinks: false)) {
        if (!digests.contains(p.basename(entry.path)) ||
            FileSystemEntity.typeSync(entry.path, followLinks: false) !=
                FileSystemEntityType.file) {
          await _cleanup(entry, 'orphan_cleanup');
        }
      }
    }
    return List.unmodifiable(restored);
  }

  @override
  Future<Result<void>> saveProgress({
    required AdminSubmissionStagedAsset asset,
    required AdminStagedAssetProgress progress,
  }) async {
    try {
      await _requireOwner(asset.owner);
      final rows = await _rows(asset.owner);
      _store.runInTransaction(TxMode.write, () {
        final matching = rows
            .where((row) => row.digest == asset.digest)
            .toList();
        if (matching.length != 1) {
          throw const FormatException('Receipt descriptor unavailable.');
        }
        final row = _box.get(matching.single.id);
        final current = row?.toModel();
        if (current == null ||
            current.owner != asset.owner ||
            current.relativePath != asset.relativePath ||
            current.progressInvalid) {
          throw const FormatException('Receipt owner unavailable.');
        }
        final previous = current.progress;
        if (previous != null &&
            (previous.upload != progress.upload ||
                (previous.associationId != null &&
                    previous.associationId != progress.associationId))) {
          throw const FormatException(
            'Receipt confirmation cannot be replaced.',
          );
        }
        final next = AdminSubmissionStagedAsset(
          owner: current.owner,
          digest: current.digest,
          relativePath: current.relativePath,
          progress: progress,
        );
        _box.put(next.toEntity(id: row!.id));
      });
      return const Result.success(null);
    } on Exception catch (error) {
      return _failure('receipt', error);
    }
  }

  @override
  Future<Result<File>> resolveAbsolutePath(
    AdminSubmissionStagedAsset asset,
  ) async {
    try {
      await _requireOwner(asset.owner);
      final file = await _file(asset, create: false);
      if (file == null || !await _validFile(file, asset.digest)) {
        throw const FormatException('Staged file unavailable.');
      }
      return Result.success(file);
    } on Exception catch (error) {
      return _failure('resolve', error);
    }
  }

  @override
  Future<Result<void>> remove({
    required AdminDraftOwner owner,
    required String digest,
  }) async {
    try {
      await _requireOwner(owner);
      if (!AdminSubmissionStagedAsset.isValidDigest(digest)) {
        throw const FormatException('Invalid digest.');
      }
      final rows = (await _rows(
        owner,
      )).where((row) => row.digest == digest).toList();
      _ensureOpen();
      // One database transaction means a failed delete never publishes partial
      // ownership removal when duplicate rows exist.
      _store.runInTransaction(TxMode.write, () {
        _box.removeMany(rows.map((row) => row.id).toList());
      });
      try {
        final directory = await _directory(owner, create: false);
        if (directory != null) {
          await _cleanup(File(p.join(directory.path, digest)), 'remove_file');
          await for (final entry in directory.list(followLinks: false)) {
            if (p.basename(entry.path).startsWith('.$digest.')) {
              await _cleanup(entry, 'remove_temp');
            }
          }
        }
      } on Exception catch (error) {
        _log('remove_cleanup', error);
      }
      return const Result.success(null);
    } on Exception catch (error) {
      return _failure('remove', error);
    }
  }

  Future<void> _requireOwner(AdminDraftOwner owner) async {
    _ensureOpen();
    final result = await _drafts.loadDraft(
      accountId: owner.accountId,
      submissionId: owner.submissionId,
    );
    if (result is! Success<AdminSubmissionDraft?> ||
        result.value?.owner != owner) {
      throw const FormatException('Durable owner unavailable.');
    }
  }

  void _ensureOpen() {
    if (_store.isClosed()) throw const FormatException('Storage unavailable.');
  }

  Future<List<AdminSubmissionStagedAssetEntity>> _rows(
    AdminDraftOwner owner,
  ) async {
    _ensureOpen();
    final query = _box
        .query(
          AdminSubmissionStagedAssetEntity_.accountId
              .equals(owner.accountId)
              .and(
                AdminSubmissionStagedAssetEntity_.sessionId.equals(
                  owner.sessionId,
                ),
              ),
        )
        .order(AdminSubmissionStagedAssetEntity_.id)
        .build();
    try {
      return await query.findAsync();
    } finally {
      query.close();
    }
  }

  Future<void> _removeRow(int id) async {
    _ensureOpen();
    await _box.removeAsync(id);
  }

  Future<Directory?> _directory(
    AdminDraftOwner owner, {
    required bool create,
  }) async {
    var directory = await _getSupportDirectory();
    // The application-support directory is supplied by the OS. Every owned
    // segment beneath it is checked independently before touching a child.
    for (final segment in [
      'admin_submission',
      'staged',
      owner.accountId,
      owner.sessionId,
    ]) {
      directory = Directory(p.join(directory.path, segment));
      final type = FileSystemEntity.typeSync(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.link) {
        await Link(directory.path).delete();
        throw const FormatException('Linked storage unavailable.');
      }
      if (type != FileSystemEntityType.directory) {
        if (type != FileSystemEntityType.notFound) {
          throw const FormatException('Storage directory unavailable.');
        }
        if (!create) return null;
        await directory.create();
      }
    }
    return directory;
  }

  Future<File?> _file(
    AdminSubmissionStagedAsset asset, {
    required bool create,
  }) async {
    if (!AdminSubmissionStagedAsset.isValidRelativePath(
      asset.relativePath,
      asset.owner,
      asset.digest,
    )) {
      throw const FormatException('Invalid staged path.');
    }
    final directory = await _directory(asset.owner, create: create);
    if (directory == null) return null;
    final file = File(p.join(directory.path, asset.digest));
    await _rejectLink(file.path);
    return file;
  }

  Future<void> _rejectLink(String path) async {
    if (FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.link) {
      await Link(path).delete();
      throw const FormatException('Linked storage unavailable.');
    }
  }

  Future<bool> _validFile(File file, String digest) async =>
      FileSystemEntity.typeSync(file.path, followLinks: false) ==
          FileSystemEntityType.file &&
      await file.length() <= kCloudinaryMaxUploadBytes &&
      (await sha1.bind(file.openRead()).first).toString() == digest;

  Future<void> _cleanup(FileSystemEntity entry, String operation) async {
    try {
      final type = FileSystemEntity.typeSync(entry.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) return;
      if (type == FileSystemEntityType.directory) {
        await for (final child in Directory(
          entry.path,
        ).list(followLinks: false)) {
          await _cleanup(child, operation);
        }
        await Directory(entry.path).delete();
      } else if (type == FileSystemEntityType.link) {
        await Link(entry.path).delete();
      } else {
        await File(entry.path).delete();
      }
    } on Exception catch (error) {
      _log(operation, error);
    }
  }

  Result<T> _failure<T>(String operation, Exception error) {
    _log(operation, error);
    return Result.error(Exception('Admin staged storage $operation failed.'));
  }

  void _log(String operation, Exception error) => _logger.log(
    AdminLocalStorageFailed(operation: operation),
    extra: {'errorType': error.runtimeType.toString()},
  );

  String _randomHex() => List.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
