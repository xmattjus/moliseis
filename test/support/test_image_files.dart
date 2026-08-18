import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Owns temporary, valid image files for widget tests that render `Image.file`.
///
/// Call [dispose] through the test teardown after creating an instance.
final class TestImageFiles {
  TestImageFiles._(this._directory);

  /// Creates an isolated directory for image files used by one test.
  factory TestImageFiles.create() =>
      TestImageFiles._(Directory.systemTemp.createTempSync('test_images_'));

  final Directory _directory;
  var _nextFileIndex = 0;

  /// Writes a valid one-pixel PNG and returns it as an [XFile].
  ///
  /// The picker bytes vary per file so digest-based selection treats generated
  /// images as distinct while `Image.file` reads the valid file at
  /// [XFile.path].
  XFile createPng({String? name}) {
    final fileIndex = _nextFileIndex++;
    final fileName = name ?? 'image_$fileIndex.png';
    final file = File('${_directory.path}/$fileName')
      ..writeAsBytesSync(_onePixelPng);
    return XFile.fromData(
      Uint8List.fromList([fileIndex]),
      mimeType: 'image/png',
      path: file.path,
    );
  }

  /// Deletes every temporary image file owned by this fixture.
  void dispose() => _directory.deleteSync(recursive: true);
}

const _onePixelPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
