import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moliseis/ui/user_contribution/view_models/user_contribution_view_model.dart';

import '../../../support/fake_image_picker.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/mock_logger.dart';

void main() {
  UserContributionViewModel buildViewModel({FakeImagePicker? imagePicker}) {
    return UserContributionViewModel(
      logger: MockLogger(),
      userContributionRepository: FakeUserContributionRepository(),
      imagePicker: imagePicker ?? FakeImagePicker(),
    );
  }

  group('UserContributionViewModel', () {
    group('addMedia', () {
      test('adds a new file to mediaFileList', () async {
        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [file],
          ),
        );

        await vm.addMedia.execute();

        expect(vm.mediaFileList, hasLength(1));
        expect(vm.addMedia.completed, isTrue);
      });

      test(
        'deduplicates files with the same content in a single pick',
        () async {
          final bytes = Uint8List.fromList([1, 2, 3]);
          final vm = buildViewModel(
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(bytes, name: 'a.jpg'),
                XFile.fromData(bytes, name: 'a_copy.jpg'),
              ],
            ),
          );

          await vm.addMedia.execute();

          expect(vm.mediaFileList, hasLength(1));
        },
      );

      test('does not add a file whose content was already added', () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(bytes, name: 'a.jpg'),
            ],
          ),
        );

        await vm.addMedia.execute();
        await vm.addMedia.execute(); // same content, second session

        expect(vm.mediaFileList, hasLength(1));
      });

      test('adds two files with different content', () async {
        var callCount = 0;
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              callCount++;
              return callCount == 1
                  ? [
                      XFile.fromData(
                        Uint8List.fromList([1, 2, 3]),
                        name: 'a.jpg',
                      ),
                    ]
                  : [
                      XFile.fromData(
                        Uint8List.fromList([4, 5, 6]),
                        name: 'b.jpg',
                      ),
                    ];
            },
          ),
        );

        await vm.addMedia.execute();
        await vm.addMedia.execute();

        expect(vm.mediaFileList, hasLength(2));
      });
    });

    group('removeMediaAt', () {
      test('removes the file at the specified index', () async {
        var callCount = 0;
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async {
              callCount++;
              return callCount == 1
                  ? [
                      XFile.fromData(
                        Uint8List.fromList([1, 2, 3]),
                        name: 'a.jpg',
                      ),
                    ]
                  : [
                      XFile.fromData(
                        Uint8List.fromList([4, 5, 6]),
                        name: 'b.jpg',
                      ),
                    ];
            },
          ),
        );

        await vm.addMedia.execute();
        await vm.addMedia.execute();
        final nameAtIndex1 = vm.mediaFileList[1].name;

        await vm.removeMediaAt.execute(0);

        expect(vm.mediaFileList, hasLength(1));
        expect(vm.mediaFileList.first.name, nameAtIndex1);
        expect(vm.removeMediaAt.completed, isTrue);
      });

      test('allows a removed file to be added again', () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onPickMultipleMedia: () async => [
              XFile.fromData(bytes, name: 'a.jpg'),
            ],
          ),
        );

        await vm.addMedia.execute();
        expect(vm.mediaFileList, hasLength(1));

        await vm.removeMediaAt.execute(0);
        expect(vm.mediaFileList, isEmpty);

        // Same content must now be accepted because the digest was removed.
        await vm.addMedia.execute();
        expect(vm.mediaFileList, hasLength(1));
      });
    });

    group('retrieveLostMedia', () {
      test('is a no-op on non-Android platforms', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        var retrieveLostDataCalled = false;
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async {
              retrieveLostDataCalled = true;
              return LostDataResponse.empty();
            },
          ),
        );

        await vm.retrieveLostMedia.execute();

        expect(retrieveLostDataCalled, isFalse);
        expect(vm.mediaFileList, isEmpty);
        expect(vm.retrieveLostMedia.completed, isTrue);
        expect(vm.retrieveLostMedia.error, isFalse);
      });

      test('does not modify mediaFileList when response is empty', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse.empty(),
          ),
        );

        await vm.retrieveLostMedia.execute();

        expect(vm.mediaFileList, isEmpty);
        expect(vm.retrieveLostMedia.completed, isTrue);
      });

      test('recovers a single lost file', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final file = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'lost.jpg',
        );
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async => LostDataResponse(file: file),
          ),
        );

        await vm.retrieveLostMedia.execute();

        expect(vm.mediaFileList, hasLength(1));
        expect(vm.retrieveLostMedia.completed, isTrue);
      });

      test('recovers multiple lost files', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final fileA = XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'a.jpg',
        );
        final fileB = XFile.fromData(
          Uint8List.fromList([4, 5, 6]),
          name: 'b.jpg',
        );
        final vm = buildViewModel(
          imagePicker: FakeImagePicker(
            onRetrieveLostData: () async =>
                LostDataResponse(file: fileA, files: [fileA, fileB]),
          ),
        );

        await vm.retrieveLostMedia.execute();

        expect(vm.mediaFileList, hasLength(2));
        expect(vm.retrieveLostMedia.completed, isTrue);
      });

      test(
        'deduplicates recovered files against already-added files',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);

          final bytes = Uint8List.fromList([1, 2, 3]);
          final vm = buildViewModel(
            imagePicker: FakeImagePicker(
              onPickMultipleMedia: () async => [
                XFile.fromData(bytes, name: 'a.jpg'),
              ],
              onRetrieveLostData: () async => LostDataResponse(
                // Same bytes as the already-added file — should be rejected.
                file: XFile.fromData(bytes, name: 'a_recovered.jpg'),
              ),
            ),
          );

          await vm.addMedia.execute();
          expect(vm.mediaFileList, hasLength(1));

          await vm.retrieveLostMedia.execute();
          expect(vm.mediaFileList, hasLength(1)); // no duplicate
        },
      );

      test(
        'returns success and clears error state when picker reports an '
        'exception',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);

          final vm = buildViewModel(
            imagePicker: FakeImagePicker(
              onRetrieveLostData: () async => LostDataResponse(
                exception: PlatformException(
                  code: 'MEDIA_ERROR',
                  message: 'test error',
                ),
              ),
            ),
          );

          await vm.retrieveLostMedia.execute();

          expect(vm.mediaFileList, isEmpty);
          expect(vm.retrieveLostMedia.error, isFalse);
          expect(vm.retrieveLostMedia.completed, isTrue);
        },
      );
    });
  });
}
