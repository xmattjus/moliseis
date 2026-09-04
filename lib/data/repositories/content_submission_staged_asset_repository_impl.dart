import 'dart:io';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' show sha1;
import 'package:moliseis/data/data-sources/content_submission_staged_asset_entity.dart';
import 'package:moliseis/data/mappers/content_submission_staged_asset_mapper.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/domain/repositories/content_submission_staged_asset_repository.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;

/// ObjectBox and filesystem implementation of staged Content Submission assets.
class ContentSubmissionStagedAssetRepositoryImpl
    implements ContentSubmissionStagedAssetRepository {
  ContentSubmissionStagedAssetRepositoryImpl({
    required Logger logger,
    required ObjectBox objectBoxI,
    Future<Directory> Function()? getSupportDirectory,
    Future<int> Function(ContentSubmissionStagedAssetEntity)? putEntity,
    Future<void> Function(File source, File destination)? copyAndClose,
    Future<int> Function(File temporary)? temporaryLength,
    Future<bool> Function(File temporary, String digest)? temporaryHasDigest,
    Future<File> Function(File temporary, Directory sessionDirectory)?
    beforeFinalRename,
    Future<void> Function()? beforeReconcile,
    Future<void> Function(ContentSubmissionStagedAsset asset)? beforeResolve,
    Future<File> Function(File source, String destinationPath)? renameFile,
    Future<void> Function(FileSystemEntity entry)? deleteEntry,
  }) : _logger = logger,
       _box = objectBoxI.store.box<ContentSubmissionStagedAssetEntity>(),
       _getSupportDirectory =
           getSupportDirectory ?? getApplicationSupportDirectory,
       _putEntity =
           putEntity ??
           ((entity) => objectBoxI.store
               .box<ContentSubmissionStagedAssetEntity>()
               .putAsync(entity)),
       _copyAndCloseOverride = copyAndClose,
       _temporaryLengthOverride = temporaryLength,
       _temporaryHasDigestOverride = temporaryHasDigest,
       _beforeFinalRenameOverride = beforeFinalRename,
       _beforeReconcileOverride = beforeReconcile,
       _beforeResolveOverride = beforeResolve,
       _renameFileOverride = renameFile,
       _deleteEntryOverride = deleteEntry;

  final Logger _logger;
  final Box<ContentSubmissionStagedAssetEntity> _box;
  final Future<Directory> Function() _getSupportDirectory;
  final Future<int> Function(ContentSubmissionStagedAssetEntity) _putEntity;
  final Future<void> Function(File source, File destination)?
  _copyAndCloseOverride;
  final Future<int> Function(File temporary)? _temporaryLengthOverride;
  final Future<bool> Function(File temporary, String digest)?
  _temporaryHasDigestOverride;
  final Future<File> Function(File temporary, Directory sessionDirectory)?
  _beforeFinalRenameOverride;
  final Future<void> Function()? _beforeReconcileOverride;
  final Future<void> Function(ContentSubmissionStagedAsset asset)?
  _beforeResolveOverride;
  final Future<File> Function(File source, String destinationPath)?
  _renameFileOverride;
  final Future<void> Function(FileSystemEntity entry)? _deleteEntryOverride;
  Future<Directory>? _supportDirectoryFuture;

  Future<Directory> get _stagingRoot async {
    final supportDirectory = await (_supportDirectoryFuture ??=
        _getSupportDirectory());
    final featureDirectory = Directory(
      p.join(supportDirectory.path, 'content_submission'),
    );
    // Construct each owned path segment separately so a pre-existing link at
    // either level is unlinked rather than followed by a recursive create.
    await _ensureDirectory(featureDirectory);
    final root = Directory(p.join(featureDirectory.path, 'staged'));
    await _ensureDirectory(root);
    return root;
  }

  @override
  Future<Result<ContentSubmissionStagedAsset>> acquire({
    required String clientSubmissionId,
    required String digest,
    required File source,
  }) async {
    if (!_isValidIdentity(clientSubmissionId) ||
        !ContentSubmissionStagedAsset.isValidDigest(digest)) {
      return Result.error(Exception('Invalid staged asset ownership.'));
    }

    File? temporary;
    try {
      final sourceLength = source.lengthSync();
      if (sourceLength > kCloudinaryMaxUploadBytes) {
        return Result.error(Exception('Staged source exceeds the size limit.'));
      }

      final asset = _assetFor(clientSubmissionId, digest);
      final finalFile = (await _finalFileFor(asset, createSession: true))!;
      final existing = await _loadRowsFor(clientSubmissionId, digest: digest);
      if (await _isValidFinal(asset, finalFile)) {
        final validRows = existing
            .where((row) => row.toModel() == asset)
            .toList();
        if (validRows.isEmpty) {
          await _putEntity(asset.toEntity());
        }
        final retainedId = validRows.isEmpty ? null : validRows.first.id;
        for (final row in existing) {
          if (row.id != retainedId) {
            await _box.removeAsync(row.id);
          }
        }
        return Result.success(asset);
      }
      for (final row in existing) {
        await _box.removeAsync(row.id);
      }
      await _deleteFinalFile(asset);

      final sessionDirectory = (await _sessionDirectory(clientSubmissionId))!;
      temporary = File(
        p.join(sessionDirectory.path, '.$digest.${_randomHex()}.tmp'),
      );
      await _copyAndClose(source, temporary);

      if (await _temporaryLength(temporary) > kCloudinaryMaxUploadBytes ||
          !await _temporaryHasDigest(temporary, digest)) {
        await _deleteEntryIfPresent(temporary);
        return Result.error(
          Exception('Staged copy did not pass verification.'),
        );
      }

      if (await _isValidFinal(asset, finalFile)) {
        await _deleteEntryIfPresent(temporary);
      } else {
        await _deleteFinalFile(asset);
        final sourceForRename = await _prepareFinalRename(
          temporary,
          sessionDirectory,
        );
        final finalFileBeforeRename = (await _finalFileFor(
          asset,
          createSession: true,
        ))!;
        await _renameFile(sourceForRename, finalFileBeforeRename.path);
      }
      temporary = null;

      await _putEntity(asset.toEntity());
      return Result.success(asset);
    } on Exception catch (exception, stackTrace) {
      if (temporary != null) {
        try {
          await _deleteEntryIfPresent(temporary);
        } on Exception {
          // Best-effort temporary cleanup; the next reconciliation repairs it.
        }
      }
      _logger.log(
        const ContentSubmissionAssetAddFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<void>> clearSession(String clientSubmissionId) async {
    if (!_isValidIdentity(clientSubmissionId)) {
      return Result.error(Exception('Invalid staged asset ownership.'));
    }

    try {
      await _clearSessionUnchecked(clientSubmissionId);
      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionAssetRemovalFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<void>> remove({
    required String clientSubmissionId,
    required String digest,
  }) async {
    if (!_isValidIdentity(clientSubmissionId) ||
        !ContentSubmissionStagedAsset.isValidDigest(digest)) {
      return Result.error(Exception('Invalid staged asset ownership.'));
    }

    try {
      for (final row in await _loadRowsFor(
        clientSubmissionId,
        digest: digest,
      )) {
        await _box.removeAsync(row.id);
      }
      await _deleteFinalFile(_assetFor(clientSubmissionId, digest));
      await _deleteTemporaryFiles(clientSubmissionId, digest: digest);
      await _deleteSessionDirectoryIfEmpty(clientSubmissionId);
      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionAssetRemovalFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<List<ContentSubmissionStagedAsset>>> reconcileAndLoad(
    String? activeClientSubmissionId,
  ) async {
    if (activeClientSubmissionId != null &&
        !_isValidIdentity(activeClientSubmissionId)) {
      return Result.error(Exception('Invalid staged asset ownership.'));
    }

    try {
      await _beforeReconcileOverride?.call();
      final rows = await _loadRows();
      if (activeClientSubmissionId == null) {
        for (final row in rows) {
          await _box.removeAsync(row.id);
        }
        await _clearAllRootEntries();
        return const Result.success([]);
      }

      for (final row in rows) {
        if (!_isValidIdentity(row.clientSubmissionId)) {
          await _box.removeAsync(row.id);
        }
      }
      final validRows = rows.where(
        (row) => _isValidIdentity(row.clientSubmissionId),
      );
      final foreignIdentities = validRows
          .where((row) => row.clientSubmissionId != activeClientSubmissionId)
          .map((row) => row.clientSubmissionId)
          .toSet();
      for (final identity in foreignIdentities) {
        await _clearSessionUnchecked(identity);
      }
      await _clearForeignRootEntries(activeClientSubmissionId);

      final activeRows = await _loadRowsFor(activeClientSubmissionId);
      final retainedDigests = <String>{};
      for (final row in activeRows) {
        final asset = row.toModel();
        if (asset == null ||
            !await _isValidFinal(
              asset,
              await _finalFileFor(asset, createSession: false),
            ) ||
            !retainedDigests.add(asset.digest)) {
          await _box.removeAsync(row.id);
        }
      }

      final activeDirectory = (await _sessionDirectory(
        activeClientSubmissionId,
      ))!;
      final descriptorDigests = (await _loadRowsFor(
        activeClientSubmissionId,
      )).map((row) => row.digest).toSet();
      final descriptorlessFinals = <({String digest, File file})>[];
      await for (final entry in activeDirectory.list(followLinks: false)) {
        final type = FileSystemEntity.typeSync(
          entry.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.link) {
          await _deleteEntryIfPresent(entry);
          continue;
        }
        if (type != FileSystemEntityType.file) {
          await _deleteTreeWithoutFollowingLinks(entry);
          continue;
        }
        final basename = p.basename(entry.path);
        if (_isTemporaryName(basename)) {
          await _deleteEntryIfPresent(entry);
          continue;
        }
        if (!ContentSubmissionStagedAsset.isValidDigest(basename)) {
          await _deleteEntryIfPresent(entry);
          continue;
        }
        final candidate = _assetFor(activeClientSubmissionId, basename);
        if (!await _isValidFinal(candidate, File(entry.path))) {
          await _deleteEntryIfPresent(entry);
          continue;
        }
        if (!descriptorDigests.contains(basename)) {
          descriptorlessFinals.add((digest: basename, file: File(entry.path)));
        }
      }
      descriptorlessFinals.sort(
        (left, right) => left.digest.compareTo(right.digest),
      );
      for (final candidate in descriptorlessFinals) {
        await _box.putAsync(
          _assetFor(activeClientSubmissionId, candidate.digest).toEntity(),
        );
      }

      final restored = <ContentSubmissionStagedAsset>[];
      for (final row in await _loadRowsFor(activeClientSubmissionId)) {
        final asset = row.toModel();
        if (asset != null &&
            await _isValidFinal(
              asset,
              await _finalFileFor(asset, createSession: false),
            )) {
          restored.add(asset);
        }
      }
      return Result.success(restored);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionAssetRetrievalFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<File>> resolveAbsolutePath(
    ContentSubmissionStagedAsset asset,
  ) async {
    try {
      await _beforeResolveOverride?.call(asset);
      final file = await _finalFileFor(asset, createSession: false);
      if (!await _isValidFinal(asset, file)) {
        return Result.error(Exception('Staged asset is unavailable.'));
      }
      return Result.success(file!);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const ContentSubmissionAssetRetrievalFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  ContentSubmissionStagedAsset _assetFor(String identity, String digest) =>
      ContentSubmissionStagedAsset(
        clientSubmissionId: identity,
        digest: digest,
        relativePath: '$identity/$digest',
      );

  Future<void> _clearAllRootEntries() async {
    final root = await _stagingRoot;
    await for (final entry in root.list(followLinks: false)) {
      await _deleteTreeWithoutFollowingLinks(entry);
    }
  }

  Future<void> _clearForeignRootEntries(String activeIdentity) async {
    final root = await _stagingRoot;
    await for (final entry in root.list(followLinks: false)) {
      final type = FileSystemEntity.typeSync(entry.path, followLinks: false);
      final basename = p.basename(entry.path);
      if (type == FileSystemEntityType.directory &&
          basename == activeIdentity) {
        continue;
      }
      if (type == FileSystemEntityType.directory &&
          _isValidIdentity(basename)) {
        await _clearSessionUnchecked(basename);
      } else {
        await _deleteTreeWithoutFollowingLinks(entry);
      }
    }
  }

  Future<void> _clearSessionUnchecked(String clientSubmissionId) async {
    for (final row in await _loadRowsFor(clientSubmissionId)) {
      await _box.removeAsync(row.id);
    }
    final directory = await _sessionDirectory(
      clientSubmissionId,
      createIfMissing: false,
    );
    if (directory != null) await _deleteTreeWithoutFollowingLinks(directory);
  }

  Future<void> _deleteTemporaryFiles(
    String clientSubmissionId, {
    String? digest,
  }) async {
    final directory = await _sessionDirectory(
      clientSubmissionId,
      createIfMissing: false,
    );
    if (directory == null) return;
    await for (final entry in directory.list(followLinks: false)) {
      final basename = p.basename(entry.path);
      if (_isTemporaryName(basename) &&
          (digest == null || basename.startsWith('.$digest.'))) {
        await _deleteEntryIfPresent(entry);
      }
    }
  }

  Future<void> _deleteSessionDirectoryIfEmpty(String clientSubmissionId) async {
    final directory = await _sessionDirectory(
      clientSubmissionId,
      createIfMissing: false,
    );
    if (directory == null) return;
    if (FileSystemEntity.typeSync(directory.path, followLinks: false) ==
            FileSystemEntityType.directory &&
        await directory.list(followLinks: false).isEmpty) {
      await directory.delete();
    }
  }

  Future<void> _copyAndClose(File source, File destination) async {
    final override = _copyAndCloseOverride;
    if (override != null) return override(source, destination);
    final sink = destination.openWrite();
    try {
      await source.openRead().forEach(sink.add);
      await sink.close();
    } on Object {
      await sink.close();
      rethrow;
    }
  }

  Future<void> _deleteEntryIfPresent(FileSystemEntity entry) async {
    final type = FileSystemEntity.typeSync(entry.path, followLinks: false);
    if (type != FileSystemEntityType.notFound) {
      final override = _deleteEntryOverride;
      if (override != null) {
        await override(entry);
      } else {
        await entry.delete();
      }
    }
  }

  Future<void> _deleteTreeWithoutFollowingLinks(FileSystemEntity entry) async {
    final type = FileSystemEntity.typeSync(entry.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      await entry.delete();
      return;
    }
    final directory = Directory(entry.path);
    await for (final child in directory.list(followLinks: false)) {
      await _deleteTreeWithoutFollowingLinks(child);
    }
    await directory.delete();
  }

  Future<void> _ensureDirectory(Directory directory) async {
    final type = FileSystemEntity.typeSync(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      await Link(directory.path).delete();
    } else if (type == FileSystemEntityType.file) {
      await File(directory.path).delete();
    }
    await directory.create(recursive: true);
  }

  Future<File?> _finalFileFor(
    ContentSubmissionStagedAsset asset, {
    required bool createSession,
  }) async {
    if (!ContentSubmissionStagedAsset.isValidRelativePath(
      asset.relativePath,
      asset.clientSubmissionId,
      asset.digest,
    )) {
      throw const FileSystemException('Invalid staged asset path.');
    }
    final directory = await _sessionDirectory(
      asset.clientSubmissionId,
      createIfMissing: createSession,
    );
    if (directory == null) return null;
    return File(p.join(directory.path, asset.digest));
  }

  Future<bool> _hasDigest(File file, String expectedDigest) async =>
      (await sha1.bind(file.openRead()).first).toString() == expectedDigest;

  Future<bool> _isValidFinal(
    ContentSubmissionStagedAsset asset,
    File? file,
  ) async {
    if (file == null ||
        await _sessionDirectory(
              asset.clientSubmissionId,
              createIfMissing: false,
            ) ==
            null) {
      return false;
    }
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    if (await _sessionDirectory(
          asset.clientSubmissionId,
          createIfMissing: false,
        ) ==
        null) {
      return false;
    }
    if (file.lengthSync() > kCloudinaryMaxUploadBytes ||
        await _sessionDirectory(
              asset.clientSubmissionId,
              createIfMissing: false,
            ) ==
            null) {
      return false;
    }
    return _hasDigest(file, asset.digest);
  }

  bool _isTemporaryName(String value) => RegExp(
    r'^\.[0-9a-f]{40}\.[0-9a-f]+\.tmp$',
  ).hasMatch(value);

  bool _isValidIdentity(String value) =>
      ContentSubmissionDraft.isValidClientSubmissionId(value);

  Future<List<ContentSubmissionStagedAssetEntity>> _loadRows() async {
    Query<ContentSubmissionStagedAssetEntity>? query;
    try {
      query = _box
          .query()
          .order(ContentSubmissionStagedAssetEntity_.id)
          .build();
      return await query.findAsync();
    } finally {
      query?.close();
    }
  }

  Future<List<ContentSubmissionStagedAssetEntity>> _loadRowsFor(
    String clientSubmissionId, {
    String? digest,
  }) async {
    Query<ContentSubmissionStagedAssetEntity>? query;
    try {
      final condition = ContentSubmissionStagedAssetEntity_.clientSubmissionId
          .equals(clientSubmissionId);
      final queryBuilder = _box
          .query(
            digest == null
                ? condition
                : condition.and(
                    ContentSubmissionStagedAssetEntity_.digest.equals(digest),
                  ),
          )
          .order(ContentSubmissionStagedAssetEntity_.id);
      query = queryBuilder.build();
      return await query.findAsync();
    } finally {
      query?.close();
    }
  }

  Future<void> _deleteFinalFile(ContentSubmissionStagedAsset asset) async {
    final file = await _finalFileFor(asset, createSession: false);
    if (file != null) await _deleteEntryIfPresent(file);
  }

  Future<int> _temporaryLength(File temporary) async =>
      _temporaryLengthOverride?.call(temporary) ?? temporary.lengthSync();

  Future<bool> _temporaryHasDigest(File temporary, String digest) async =>
      _temporaryHasDigestOverride?.call(temporary, digest) ??
      _hasDigest(temporary, digest);

  Future<File> _renameFile(File source, String destinationPath) async =>
      _renameFileOverride?.call(source, destinationPath) ??
      source.rename(destinationPath);

  Future<File> _prepareFinalRename(
    File temporary,
    Directory sessionDirectory,
  ) async =>
      _beforeFinalRenameOverride?.call(temporary, sessionDirectory) ??
      temporary;

  /// Returns a regular in-root session directory, never a link target.
  ///
  /// Every operation that reads, writes, deletes, or resolves a session child
  /// enters through this boundary. Links are removed as in-root state instead
  /// of being traversed; callers that do not need to create a directory then
  /// receive `null` and treat the requested final file as unavailable.
  Future<Directory?> _sessionDirectory(
    String clientSubmissionId, {
    bool createIfMissing = true,
  }) async {
    final root = await _stagingRoot;
    final directory = Directory(p.join(root.path, clientSubmissionId));
    final type = FileSystemEntity.typeSync(directory.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      await Link(directory.path).delete();
      if (!createIfMissing) return null;
    } else if (type == FileSystemEntityType.file) {
      await File(directory.path).delete();
      if (!createIfMissing) return null;
    } else if (type == FileSystemEntityType.notFound && !createIfMissing) {
      return null;
    }
    if (FileSystemEntity.typeSync(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      await directory.create();
    }
    return directory;
  }

  String _randomHex() => List<int>.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
