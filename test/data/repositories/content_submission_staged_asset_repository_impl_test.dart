import 'dart:io';

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/content_submission_staged_asset_entity.dart';
import 'package:moliseis/data/repositories/content_submission_staged_asset_repository_impl.dart';
import 'package:moliseis/domain/models/content_submission_staged_asset.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/result.dart';
import 'package:path/path.dart' as p;

import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  const sessionA = '2a1b0c3d-4e5f-4a6b-8c9d-0e1f2a3b4c5d';
  const sessionB = '3b2c1d4e-5f6a-4b7c-9d0e-1f2a3b4c5d6e';
  late TestObjectBoxEnvironment objectBoxEnvironment;
  late Directory supportDirectory;
  late ContentSubmissionStagedAssetRepositoryImpl repository;

  setUp(() async {
    objectBoxEnvironment = await TestObjectBoxEnvironment.create();
    supportDirectory = await Directory.systemTemp.createTemp(
      'moliseis_content_submission_support_',
    );
    repository = ContentSubmissionStagedAssetRepositoryImpl(
      logger: MockLogger(),
      objectBoxI: TestObjectBox(objectBoxEnvironment.store),
      getSupportDirectory: () async => supportDirectory,
    );
  });

  tearDown(() async {
    await objectBoxEnvironment.dispose();
    await supportDirectory.delete(recursive: true);
  });

  group('ContentSubmissionStagedAssetRepositoryImpl', () {
    test('acquires an independent digest-named staged copy', () async {
      final source = File('${supportDirectory.path}/picker-source.jpg');
      final bytes = <int>[1, 2, 3, 4];
      await source.writeAsBytes(bytes);
      final digest = sha1.convert(bytes).toString();

      final result = await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      );

      final asset = switch (result) {
        Success<ContentSubmissionStagedAsset>(:final value) => value,
        Error<ContentSubmissionStagedAsset>(:final error) => throw error,
      };
      final resolved = await repository.resolveAbsolutePath(asset);
      final stagedFile = switch (resolved) {
        Success<File>(:final value) => value,
        Error<File>(:final error) => throw error,
      };

      expect(asset.relativePath, '$sessionA/$digest');
      expect(stagedFile.path, startsWith('${supportDirectory.path}/'));
      expect(stagedFile.path, isNot(source.path));
      expect(await stagedFile.readAsBytes(), bytes);

      await source.writeAsBytes(<int>[9, 9, 9]);
      expect(await stagedFile.readAsBytes(), bytes);
    });

    test('rejects invalid ownership before creating a staged path', () async {
      final source = File('${supportDirectory.path}/picker-source.jpg');
      await source.writeAsBytes(<int>[1]);

      final result = await repository.acquire(
        clientSubmissionId: 'not-a-uuid',
        digest: sha1.convert(<int>[1]).toString(),
        source: source,
      );

      expect(result, isA<Error<ContentSubmissionStagedAsset>>());
      expect(
        Directory(
          '${supportDirectory.path}/content_submission/staged',
        ).existsSync(),
        isFalse,
      );
    });

    test(
      'does not follow a staged-session symlink during reconciliation',
      () async {
        final outside = await Directory.systemTemp.createTemp(
          'moliseis_outside_staging_',
        );
        addTearDown(() => outside.delete(recursive: true));
        final root = Directory(
          '${supportDirectory.path}/content_submission/staged',
        );
        await root.create(recursive: true);
        final outsideFile = File('${outside.path}/keep.txt');
        await outsideFile.writeAsString('outside');
        await Link('${root.path}/$sessionA').create(outside.path);

        final result = await repository.reconcileAndLoad(sessionA);

        expect(result, isA<Success<List<ContentSubmissionStagedAsset>>>());
        expect(await Link('${root.path}/$sessionA').exists(), isFalse);
        expect(await outsideFile.readAsString(), 'outside');
      },
    );

    test('does not follow a feature-root ancestor symlink', () async {
      final outside = await Directory.systemTemp.createTemp(
        'moliseis_outside_feature_root_',
      );
      addTearDown(() => outside.delete(recursive: true));
      final outsideFile = File('${outside.path}/keep.txt')
        ..writeAsStringSync('outside');
      final featureRoot = Link(
        '${supportDirectory.path}/content_submission',
      );
      await featureRoot.create(outside.path);

      final result = await repository.reconcileAndLoad(sessionA);

      expect(result, isA<Success<List<ContentSubmissionStagedAsset>>>());
      expect(featureRoot.existsSync(), isFalse);
      expect(outsideFile.readAsStringSync(), 'outside');
    });

    test(
      'acquire replaces a linked session directory without touching it',
      () async {
        final outside = await Directory.systemTemp.createTemp(
          'moliseis_outside_acquire_session_',
        );
        addTearDown(() => outside.delete(recursive: true));
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final outsideFile = File('${outside.path}/$digest')
          ..writeAsBytesSync(<int>[9, 9, 9]);
        final root = Directory(
          '${supportDirectory.path}/content_submission/staged',
        )..createSync(recursive: true);
        await Link('${root.path}/$sessionA').create(outside.path);
        final source = File('${supportDirectory.path}/picker-source.jpg')
          ..writeAsBytesSync(bytes);

        final result = await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        );

        expect(result, isA<Success<ContentSubmissionStagedAsset>>());
        expect(outsideFile.readAsBytesSync(), <int>[9, 9, 9]);
        expect(
          File('${root.path}/$sessionA/$digest').readAsBytesSync(),
          bytes,
        );
      },
    );

    test('acquire revalidates a session directory before final '
        'rename', () async {
      final outside = await Directory.systemTemp.createTemp(
        'moliseis_outside_rename_session_',
      );
      addTearDown(() => outside.delete(recursive: true));
      final bytes = <int>[1, 2, 3];
      final digest = sha1.convert(bytes).toString();
      final outsideFile = File('${outside.path}/$digest')
        ..writeAsBytesSync(<int>[9, 9, 9]);
      final source = File('${supportDirectory.path}/picker-source.jpg')
        ..writeAsBytesSync(bytes);
      repository = ContentSubmissionStagedAssetRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        getSupportDirectory: () async => supportDirectory,
        beforeFinalRename: (temporary, sessionDirectory) async {
          final moved = await temporary.rename(
            '${supportDirectory.path}/temporary-outside-staging',
          );
          await sessionDirectory.delete(recursive: true);
          await Link(sessionDirectory.path).create(outside.path);
          return moved;
        },
      );

      final result = await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      );

      expect(result, isA<Success<ContentSubmissionStagedAsset>>());
      expect(outsideFile.readAsBytesSync(), <int>[9, 9, 9]);
      expect(
        File(
          '${supportDirectory.path}/content_submission/staged/$sessionA/$digest',
        ).readAsBytesSync(),
        bytes,
      );
    });

    test('resolveAbsolutePath unlinks a linked session directory', () async {
      final outside = await Directory.systemTemp.createTemp(
        'moliseis_outside_resolve_session_',
      );
      addTearDown(() => outside.delete(recursive: true));
      final bytes = <int>[1, 2, 3];
      final digest = sha1.convert(bytes).toString();
      final source = File('${supportDirectory.path}/picker-source.jpg')
        ..writeAsBytesSync(bytes);
      final asset = (await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      )).getOrNull()!;
      final outsideFile = File('${outside.path}/$digest')
        ..writeAsBytesSync(<int>[9, 9, 9]);
      final sessionDirectory = Directory(
        '${supportDirectory.path}/content_submission/staged/$sessionA',
      );
      await sessionDirectory.delete(recursive: true);
      final link = Link(sessionDirectory.path);
      await link.create(outside.path);

      final resolved = await repository.resolveAbsolutePath(asset);

      expect(resolved, isA<Error<File>>());
      expect(link.existsSync(), isFalse);
      expect(outsideFile.readAsBytesSync(), <int>[9, 9, 9]);
    });

    test(
      'remove unlinks a linked session directory without deleting outside',
      () async {
        final outside = await Directory.systemTemp.createTemp(
          'moliseis_outside_remove_session_',
        );
        addTearDown(() => outside.delete(recursive: true));
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final source = File('${supportDirectory.path}/picker-source.jpg')
          ..writeAsBytesSync(bytes);
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        );
        final outsideFile = File('${outside.path}/$digest')
          ..writeAsBytesSync(<int>[9, 9, 9]);
        final sessionDirectory = Directory(
          '${supportDirectory.path}/content_submission/staged/$sessionA',
        );
        await sessionDirectory.delete(recursive: true);
        final link = Link(sessionDirectory.path);
        await link.create(outside.path);

        final result = await repository.remove(
          clientSubmissionId: sessionA,
          digest: digest,
        );

        expect(result, isA<Success<void>>());
        expect(link.existsSync(), isFalse);
        expect(outsideFile.readAsBytesSync(), <int>[9, 9, 9]);
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          0,
        );
      },
    );

    test(
      'clearSession unlinks a linked session directory without deleting '
      'outside',
      () async {
        final outside = await Directory.systemTemp.createTemp(
          'moliseis_outside_clear_session_',
        );
        addTearDown(() => outside.delete(recursive: true));
        final outsideFile = File('${outside.path}/keep.txt')
          ..writeAsStringSync('outside');
        final root = Directory(
          '${supportDirectory.path}/content_submission/staged',
        )..createSync(recursive: true);
        final link = Link('${root.path}/$sessionA');
        await link.create(outside.path);
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .put(
              ContentSubmissionStagedAssetEntity(
                clientSubmissionId: sessionA,
                digest: sha1.convert(<int>[1]).toString(),
                relativePath: '$sessionA/${sha1.convert(<int>[1])}',
              ),
            );

        final result = await repository.clearSession(sessionA);

        expect(result, isA<Success<void>>());
        expect(link.existsSync(), isFalse);
        expect(outsideFile.readAsStringSync(), 'outside');
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          0,
        );
      },
    );

    test(
      'rejects source bytes that no longer match the supplied digest',
      () async {
        final source = File('${supportDirectory.path}/picker-source.jpg');
        await source.writeAsBytes(<int>[1, 2, 3]);
        final digest = sha1.convert(<int>[1, 2, 3]).toString();
        await source.writeAsBytes(<int>[4, 5, 6]);

        final result = await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        );

        expect(result, isA<Error<ContentSubmissionStagedAsset>>());
        final restored = await repository.reconcileAndLoad(sessionA);
        expect(restored.getOrNull(), isEmpty);
      },
    );

    test('rejects source mutation performed between digest and copy', () async {
      final initialBytes = <int>[1, 2, 3];
      final source = File('${supportDirectory.path}/picker-source.jpg')
        ..writeAsBytesSync(initialBytes);
      repository = ContentSubmissionStagedAssetRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        getSupportDirectory: () async => supportDirectory,
        copyAndClose: (source, destination) async {
          await source.writeAsBytes(<int>[4, 5, 6]);
          await destination.writeAsBytes(await source.readAsBytes());
        },
      );

      final result = await repository.acquire(
        clientSubmissionId: sessionA,
        digest: sha1.convert(initialBytes).toString(),
        source: source,
      );

      expect(result, isA<Error<ContentSubmissionStagedAsset>>());
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
    });

    test('rejects a copied source that grows beyond the size limit', () async {
      final initialBytes = <int>[1, 2, 3];
      final source = File('${supportDirectory.path}/picker-source.jpg')
        ..writeAsBytesSync(initialBytes);
      repository = ContentSubmissionStagedAssetRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        getSupportDirectory: () async => supportDirectory,
        copyAndClose: (source, destination) async {
          final grown = List<int>.filled(10 * 1024 * 1024 + 1, 7);
          await source.writeAsBytes(grown);
          await destination.writeAsBytes(await source.readAsBytes());
        },
      );

      final result = await repository.acquire(
        clientSubmissionId: sessionA,
        digest: sha1.convert(initialBytes).toString(),
        source: source,
      );

      expect(result, isA<Error<ContentSubmissionStagedAsset>>());
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
    });

    test('copy failure commits no descriptor', () async {
      final bytes = <int>[1, 2, 3];
      final result = await repository.acquire(
        clientSubmissionId: sessionA,
        digest: sha1.convert(bytes).toString(),
        source: File('${supportDirectory.path}/missing-source.jpg'),
      );

      expect(result, isA<Error<ContentSubmissionStagedAsset>>());
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
    });

    test(
      'interrupted partial copy commits no descriptor or temporary file',
      () async {
        final bytes = <int>[1, 2, 3];
        final source = File('${supportDirectory.path}/picker-source.jpg')
          ..writeAsBytesSync(bytes);
        repository = ContentSubmissionStagedAssetRepositoryImpl(
          logger: MockLogger(),
          objectBoxI: TestObjectBox(objectBoxEnvironment.store),
          getSupportDirectory: () async => supportDirectory,
          copyAndClose: (_, destination) async {
            await destination.writeAsBytes(<int>[1]);
            throw const FileSystemException('interrupted copy');
          },
        );

        final result = await repository.acquire(
          clientSubmissionId: sessionA,
          digest: sha1.convert(bytes).toString(),
          source: source,
        );

        expect(result, isA<Error<ContentSubmissionStagedAsset>>());
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          0,
        );
        expect(
          await Directory(
            '${supportDirectory.path}/content_submission/staged/$sessionA',
          ).list(followLinks: false).toList(),
          isEmpty,
        );
      },
    );

    test('rename failure commits no descriptor or final file', () async {
      final bytes = <int>[1, 2, 3];
      final digest = sha1.convert(bytes).toString();
      final source = File('${supportDirectory.path}/picker-source.jpg')
        ..writeAsBytesSync(bytes);
      repository = ContentSubmissionStagedAssetRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        getSupportDirectory: () async => supportDirectory,
        renameFile: (_, _) => Future<File>.error(
          const FileSystemException('rename failed'),
        ),
      );

      final result = await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      );

      expect(result, isA<Error<ContentSubmissionStagedAsset>>());
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
      expect(
        File(
          '${supportDirectory.path}/content_submission/staged/$sessionA/$digest',
        ).existsSync(),
        isFalse,
      );
    });

    test(
      'closes and verifies a temporary file before rename and descriptor',
      () async {
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final source = File('${supportDirectory.path}/picker-source.jpg')
          ..writeAsBytesSync(bytes);
        final steps = <String>[];
        repository = ContentSubmissionStagedAssetRepositoryImpl(
          logger: MockLogger(),
          objectBoxI: TestObjectBox(objectBoxEnvironment.store),
          getSupportDirectory: () async => supportDirectory,
          copyAndClose: (_, destination) async {
            await destination.writeAsBytes(bytes);
            steps.add('temporary closed');
          },
          temporaryLength: (temporary) async {
            steps.add('size verified');
            return temporary.lengthSync();
          },
          temporaryHasDigest: (_, _) async {
            steps.add('digest verified');
            return true;
          },
          renameFile: (temporary, destinationPath) async {
            steps.add('final renamed');
            return temporary.rename(destinationPath);
          },
          putEntity: (entity) async {
            steps.add('descriptor persisted');
            return objectBoxEnvironment.store
                .box<ContentSubmissionStagedAssetEntity>()
                .put(entity);
          },
        );

        final result = await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        );

        expect(result, isA<Success<ContentSubmissionStagedAsset>>());
        expect(steps, [
          'temporary closed',
          'size verified',
          'digest verified',
          'final renamed',
          'descriptor persisted',
        ]);
      },
    );

    test('descriptor failure leaves a final file '
        'that retry converges', () async {
      final source = File('${supportDirectory.path}/picker-source.jpg');
      final bytes = <int>[1, 2, 3];
      final digest = sha1.convert(bytes).toString();
      await source.writeAsBytes(bytes);
      repository = ContentSubmissionStagedAssetRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        getSupportDirectory: () async => supportDirectory,
        putEntity: (_) => Future<int>.error(Exception('descriptor failure')),
      );

      final failed = await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      );

      expect(failed, isA<Error<ContentSubmissionStagedAsset>>());
      expect(
        File(
          '${supportDirectory.path}/content_submission/staged/$sessionA/$digest',
        ).existsSync(),
        isTrue,
      );
      repository = ContentSubmissionStagedAssetRepositoryImpl(
        logger: MockLogger(),
        objectBoxI: TestObjectBox(objectBoxEnvironment.store),
        getSupportDirectory: () async => supportDirectory,
      );
      expect(
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        ),
        isA<Success<ContentSubmissionStagedAsset>>(),
      );
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        1,
      );
    });

    test('a later failed acquire preserves an earlier '
        'committed asset', () async {
      final source = File('${supportDirectory.path}/picker-source.jpg');
      final bytes = <int>[1, 2, 3];
      final digest = sha1.convert(bytes).toString();
      await source.writeAsBytes(bytes);
      await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      );

      final failed = await repository.acquire(
        clientSubmissionId: sessionA,
        digest: sha1.convert(<int>[4, 5, 6]).toString(),
        source: File('${supportDirectory.path}/missing-source.jpg'),
      );

      expect(failed, isA<Error<ContentSubmissionStagedAsset>>());
      expect(
        File(
          '${supportDirectory.path}/content_submission/staged/$sessionA/$digest',
        ).existsSync(),
        isTrue,
      );
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        1,
      );
    });

    test(
      'keeps ownership separate for equal content in different sessions',
      () async {
        final source = File('${supportDirectory.path}/picker-source.jpg');
        final bytes = <int>[1, 2, 3];
        await source.writeAsBytes(bytes);
        final digest = sha1.convert(bytes).toString();

        final first = await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        );
        final second = await repository.acquire(
          clientSubmissionId: sessionB,
          digest: digest,
          source: source,
        );

        expect(first, isA<Success<ContentSubmissionStagedAsset>>());
        expect(second, isA<Success<ContentSubmissionStagedAsset>>());
        expect(
          File(
            '${supportDirectory.path}/content_submission/staged/$sessionA/$digest',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            '${supportDirectory.path}/content_submission/staged/$sessionB/$digest',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'converges repeated staging to one final file and descriptor',
      () async {
        final source = File('${supportDirectory.path}/picker-source.jpg');
        final bytes = <int>[1, 2, 3];
        await source.writeAsBytes(bytes);
        final digest = sha1.convert(bytes).toString();

        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        );
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        );

        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          1,
        );
        expect(
          await Directory(
            '${supportDirectory.path}/content_submission/staged/$sessionA',
          ).list(followLinks: false).toList(),
          hasLength(1),
        );
      },
    );

    test(
      'rejects an oversized source without a descriptor or session path',
      () async {
        final source = File('${supportDirectory.path}/picker-source.jpg');
        final bytes = List<int>.filled(10 * 1024 * 1024 + 1, 1);
        await source.writeAsBytes(bytes);

        final result = await repository.acquire(
          clientSubmissionId: sessionA,
          digest: sha1.convert(bytes).toString(),
          source: source,
        );

        expect(result, isA<Error<ContentSubmissionStagedAsset>>());
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          0,
        );
        expect(
          Directory(
            '${supportDirectory.path}/content_submission/staged/$sessionA',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'reconstructs descriptor-less finals after existing descriptors '
      'in explicit ID order',
      () async {
        final existingBytes = <int>[9];
        final firstBytes = <int>[1];
        final secondBytes = <int>[2];
        final existingDigest = sha1.convert(existingBytes).toString();
        final firstDigest = sha1.convert(firstBytes).toString();
        final secondDigest = sha1.convert(secondBytes).toString();
        final sessionDirectory = Directory(
          '${supportDirectory.path}/content_submission/staged/$sessionA',
        );
        await sessionDirectory.create(recursive: true);
        await File('${sessionDirectory.path}/$secondDigest').writeAsBytes(
          secondBytes,
        );
        await File('${sessionDirectory.path}/$firstDigest').writeAsBytes(
          firstBytes,
        );
        await File('${sessionDirectory.path}/$existingDigest').writeAsBytes(
          existingBytes,
        );
        final box = objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>();
        final existingId = box.put(
          ContentSubmissionStagedAssetEntity(
            clientSubmissionId: sessionA,
            digest: existingDigest,
            relativePath: '$sessionA/$existingDigest',
          ),
        );

        final restored = await repository.reconcileAndLoad(sessionA);
        final reconstructedDigests = [firstDigest, secondDigest]..sort();
        final expected = [existingDigest, ...reconstructedDigests];
        final query = box
            .query()
            .order(ContentSubmissionStagedAssetEntity_.id)
            .build();
        final descriptors = query.find();
        query.close();

        expect(
          restored.getOrNull()!.map((asset) => asset.digest),
          expected,
        );
        expect(descriptors.map((descriptor) => descriptor.id), [
          existingId,
          greaterThan(existingId),
          greaterThan(existingId),
        ]);
        expect(
          descriptors.map((descriptor) => descriptor.digest),
          expected,
        );
      },
    );

    test(
      'removes a mismatched descriptor final without disturbing valid order',
      () async {
        final validBytes = <int>[9];
        final validDigest = sha1.convert(validBytes).toString();
        final source = File('${supportDirectory.path}/valid-source.jpg')
          ..writeAsBytesSync(validBytes);
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: validDigest,
          source: source,
        );
        final mismatchedDigest = sha1.convert(<int>[1]).toString();
        final sessionDirectory = Directory(
          '${supportDirectory.path}/content_submission/staged/$sessionA',
        );
        final mismatchedFile = File(
          '${sessionDirectory.path}/$mismatchedDigest',
        )..writeAsBytesSync(<int>[2]);
        final box = objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>();
        final mismatchedRowId = box.put(
          ContentSubmissionStagedAssetEntity(
            clientSubmissionId: sessionA,
            digest: mismatchedDigest,
            relativePath: '$sessionA/$mismatchedDigest',
          ),
        );

        final restored = await repository.reconcileAndLoad(sessionA);

        expect(restored.getOrNull()!.map((asset) => asset.digest), [
          validDigest,
        ]);
        expect(box.get(mismatchedRowId), isNull);
        expect(mismatchedFile.existsSync(), isFalse);
        expect(box.count(), 1);
      },
    );

    test(
      'removes a mismatched descriptor-less final without reconstruction',
      () async {
        final validBytes = <int>[9];
        final validDigest = sha1.convert(validBytes).toString();
        final source = File('${supportDirectory.path}/valid-source.jpg')
          ..writeAsBytesSync(validBytes);
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: validDigest,
          source: source,
        );
        final mismatchedDigest = sha1.convert(<int>[1]).toString();
        final mismatchedFile = File(
          '${supportDirectory.path}/content_submission/staged/$sessionA/'
          '$mismatchedDigest',
        )..writeAsBytesSync(<int>[2]);

        final restored = await repository.reconcileAndLoad(sessionA);

        expect(restored.getOrNull()!.map((asset) => asset.digest), [
          validDigest,
        ]);
        expect(mismatchedFile.existsSync(), isFalse);
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          1,
        );
      },
    );

    test(
      'removes an oversized existing final without disturbing valid order',
      () async {
        final validBytes = <int>[9];
        final validDigest = sha1.convert(validBytes).toString();
        final source = File('${supportDirectory.path}/valid-source.jpg')
          ..writeAsBytesSync(validBytes);
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: validDigest,
          source: source,
        );
        final oversizedBytes = List<int>.filled(
          kCloudinaryMaxUploadBytes + 1,
          1,
        );
        final oversizedDigest = sha1.convert(oversizedBytes).toString();
        final oversizedFile = File(
          '${supportDirectory.path}/content_submission/staged/$sessionA/'
          '$oversizedDigest',
        )..writeAsBytesSync(oversizedBytes);
        final box = objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>();
        final oversizedRowId = box.put(
          ContentSubmissionStagedAssetEntity(
            clientSubmissionId: sessionA,
            digest: oversizedDigest,
            relativePath: '$sessionA/$oversizedDigest',
          ),
        );

        final restored = await repository.reconcileAndLoad(sessionA);

        expect(restored.getOrNull()!.map((asset) => asset.digest), [
          validDigest,
        ]);
        expect(box.get(oversizedRowId), isNull);
        expect(oversizedFile.existsSync(), isFalse);
        expect(box.count(), 1);
      },
    );

    test(
      'removes a wrong relative filename row and invalid final '
      'without reconstruction',
      () async {
        final validBytes = <int>[9];
        final validDigest = sha1.convert(validBytes).toString();
        final source = File('${supportDirectory.path}/valid-source.jpg')
          ..writeAsBytesSync(validBytes);
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: validDigest,
          source: source,
        );
        final rowDigest = sha1.convert(<int>[1]).toString();
        final wrongFilenameDigest = sha1.convert(<int>[2]).toString();
        final invalidFile = File(
          '${supportDirectory.path}/content_submission/staged/$sessionA/'
          '$wrongFilenameDigest',
        )..writeAsBytesSync(<int>[3]);
        final box = objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>();
        final malformedRowId = box.put(
          ContentSubmissionStagedAssetEntity(
            clientSubmissionId: sessionA,
            digest: rowDigest,
            relativePath: '$sessionA/$wrongFilenameDigest',
          ),
        );

        final restored = await repository.reconcileAndLoad(sessionA);

        expect(restored.getOrNull()!.map((asset) => asset.digest), [
          validDigest,
        ]);
        expect(box.get(malformedRowId), isNull);
        expect(invalidFile.existsSync(), isFalse);
        expect(box.count(), 1);
      },
    );

    test('retains the lowest valid descriptor ID for duplicates', () async {
      final bytes = <int>[1, 2, 3];
      final digest = sha1.convert(bytes).toString();
      final sessionDirectory = Directory(
        '${supportDirectory.path}/content_submission/staged/$sessionA',
      );
      await sessionDirectory.create(recursive: true);
      await File('${sessionDirectory.path}/$digest').writeAsBytes(bytes);
      final box = objectBoxEnvironment.store
          .box<ContentSubmissionStagedAssetEntity>();
      final firstId = box.put(
        ContentSubmissionStagedAssetEntity(
          clientSubmissionId: sessionA,
          digest: digest,
          relativePath: '$sessionA/$digest',
        ),
      );
      box.put(
        ContentSubmissionStagedAssetEntity(
          clientSubmissionId: sessionA,
          digest: digest,
          relativePath: '$sessionA/$digest',
        ),
      );

      final restored = await repository.reconcileAndLoad(sessionA);

      expect(restored.getOrNull(), hasLength(1));
      expect(box.count(), 1);
      expect(box.get(firstId), isNotNull);
    });

    test(
      'removes a malformed descriptor by technical ID without dereferencing it',
      () async {
        final outside = await Directory.systemTemp.createTemp(
          'moliseis_outside_malformed_descriptor_',
        );
        addTearDown(() => outside.delete(recursive: true));
        final outsideFile = File('${outside.path}/keep.txt')
          ..writeAsStringSync('outside');
        final digest = sha1.convert(<int>[1, 2, 3]).toString();
        final box = objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>();
        final rowId = box.put(
          ContentSubmissionStagedAssetEntity(
            clientSubmissionId: sessionA,
            digest: digest,
            relativePath: '../../${outside.path}/keep.txt',
          ),
        );

        final restored = await repository.reconcileAndLoad(sessionA);

        expect(restored.getOrNull(), isEmpty);
        expect(box.get(rowId), isNull);
        expect(outsideFile.readAsStringSync(), 'outside');
      },
    );

    test('removes a linked final file without following its target', () async {
      final outside = await Directory.systemTemp.createTemp(
        'moliseis_outside_linked_final_',
      );
      addTearDown(() => outside.delete(recursive: true));
      final bytes = <int>[1, 2, 3];
      final digest = sha1.convert(bytes).toString();
      final source = File('${supportDirectory.path}/picker-source.jpg')
        ..writeAsBytesSync(bytes);
      await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      );
      final outsideFile = File('${outside.path}/$digest')
        ..writeAsBytesSync(<int>[9, 9, 9]);
      final finalPath =
          '${supportDirectory.path}/content_submission/staged/$sessionA/$digest';
      await File(finalPath).delete();
      final link = Link(finalPath);
      await link.create(outsideFile.path);

      final restored = await repository.reconcileAndLoad(sessionA);

      expect(restored.getOrNull(), isEmpty);
      expect(link.existsSync(), isFalse);
      expect(outsideFile.readAsBytesSync(), <int>[9, 9, 9]);
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
    });

    test(
      'removes stale descriptors and temporary files during reconciliation',
      () async {
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final sessionDirectory = Directory(
          '${supportDirectory.path}/content_submission/staged/$sessionA',
        );
        await sessionDirectory.create(recursive: true);
        final temporary = File(
          '${sessionDirectory.path}/.$digest.deadbeef.tmp',
        );
        await temporary.writeAsBytes(bytes);
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .put(
              ContentSubmissionStagedAssetEntity(
                clientSubmissionId: sessionA,
                digest: digest,
                relativePath: '$sessionA/$digest',
              ),
            );

        final restored = await repository.reconcileAndLoad(sessionA);

        expect(restored.getOrNull(), isEmpty);
        expect(temporary.existsSync(), isFalse);
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          0,
        );
      },
    );

    test('removes non-active session state without adopting it', () async {
      final source = File('${supportDirectory.path}/picker-source.jpg');
      final bytes = <int>[1, 2, 3];
      await source.writeAsBytes(bytes);
      final digest = sha1.convert(bytes).toString();
      await repository.acquire(
        clientSubmissionId: sessionB,
        digest: digest,
        source: source,
      );

      final restored = await repository.reconcileAndLoad(sessionA);

      expect(restored.getOrNull(), isEmpty);
      expect(
        Directory(
          '${supportDirectory.path}/content_submission/staged/$sessionB',
        ).existsSync(),
        isFalse,
      );
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
    });

    test(
      'cleans malformed and linked foreign root children without following',
      () async {
        final outside = await Directory.systemTemp.createTemp(
          'moliseis_outside_foreign_root_',
        );
        addTearDown(() => outside.delete(recursive: true));
        final outsideFile = File('${outside.path}/keep.txt')
          ..writeAsStringSync('outside');
        final root = Directory(
          '${supportDirectory.path}/content_submission/staged',
        )..createSync(recursive: true);
        final linkedForeign = Link('${root.path}/$sessionB');
        await linkedForeign.create(outside.path);
        final malformed = File('${root.path}/not-a-session')
          ..writeAsStringSync('malformed');

        final restored = await repository.reconcileAndLoad(sessionA);

        expect(restored.getOrNull(), isEmpty);
        expect(linkedForeign.existsSync(), isFalse);
        expect(malformed.existsSync(), isFalse);
        expect(outsideFile.readAsStringSync(), 'outside');
      },
    );

    test(
      'treats every session as orphaned without an active identity',
      () async {
        final source = File('${supportDirectory.path}/picker-source.jpg');
        final bytes = <int>[1, 2, 3];
        await source.writeAsBytes(bytes);
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: sha1.convert(bytes).toString(),
          source: source,
        );

        final restored = await repository.reconcileAndLoad(null);

        expect(restored.getOrNull(), isEmpty);
        expect(
          Directory(
            '${supportDirectory.path}/content_submission/staged/$sessionA',
          ).existsSync(),
          isFalse,
        );
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          0,
        );
      },
    );

    test('removes one asset and idempotently clears a mixed session', () async {
      final source = File('${supportDirectory.path}/picker-source.jpg');
      final bytes = <int>[1, 2, 3];
      await source.writeAsBytes(bytes);
      final digest = sha1.convert(bytes).toString();
      await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      );
      final sessionDirectory = Directory(
        '${supportDirectory.path}/content_submission/staged/$sessionA',
      );
      final temporary = File('${sessionDirectory.path}/.$digest.deadbeef.tmp');
      await temporary.writeAsBytes(bytes);

      expect(
        await repository.remove(
          clientSubmissionId: sessionA,
          digest: digest,
        ),
        isA<Success<void>>(),
      );
      expect(temporary.existsSync(), isFalse);
      expect(sessionDirectory.existsSync(), isFalse);
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
      expect(
        await repository.clearSession(sessionA),
        isA<Success<void>>(),
      );
      expect(
        await repository.clearSession(sessionA),
        isA<Success<void>>(),
      );
    });

    test(
      'removal retries after descriptor deletion and final-file failure',
      () async {
        final bytes = <int>[1, 2, 3];
        final digest = sha1.convert(bytes).toString();
        final source = File('${supportDirectory.path}/picker-source.jpg')
          ..writeAsBytesSync(bytes);
        await repository.acquire(
          clientSubmissionId: sessionA,
          digest: digest,
          source: source,
        );
        var failFinalDeletion = true;
        repository = ContentSubmissionStagedAssetRepositoryImpl(
          logger: MockLogger(),
          objectBoxI: TestObjectBox(objectBoxEnvironment.store),
          getSupportDirectory: () async => supportDirectory,
          deleteEntry: (entry) async {
            if (failFinalDeletion && p.basename(entry.path) == digest) {
              failFinalDeletion = false;
              throw const FileSystemException('final deletion failed');
            }
            await entry.delete();
          },
        );

        final failed = await repository.remove(
          clientSubmissionId: sessionA,
          digest: digest,
        );

        expect(failed, isA<Error<void>>());
        expect(
          objectBoxEnvironment.store
              .box<ContentSubmissionStagedAssetEntity>()
              .count(),
          0,
        );
        expect(
          File(
            '${supportDirectory.path}/content_submission/staged/$sessionA/$digest',
          ).existsSync(),
          isTrue,
        );

        final retried = await repository.remove(
          clientSubmissionId: sessionA,
          digest: digest,
        );

        expect(retried, isA<Success<void>>());
        expect(
          Directory(
            '${supportDirectory.path}/content_submission/staged/$sessionA',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test('removal succeeds when its final file is already missing', () async {
      final bytes = <int>[1, 2, 3];
      final digest = sha1.convert(bytes).toString();
      final source = File('${supportDirectory.path}/picker-source.jpg')
        ..writeAsBytesSync(bytes);
      await repository.acquire(
        clientSubmissionId: sessionA,
        digest: digest,
        source: source,
      );
      await File(
        '${supportDirectory.path}/content_submission/staged/$sessionA/$digest',
      ).delete();

      final result = await repository.remove(
        clientSubmissionId: sessionA,
        digest: digest,
      );

      expect(result, isA<Success<void>>());
      expect(
        objectBoxEnvironment.store
            .box<ContentSubmissionStagedAssetEntity>()
            .count(),
        0,
      );
    });
  });
}
