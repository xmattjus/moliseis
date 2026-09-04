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
  /// Each generated file contains a different valid ancillary text chunk so
  /// digest-based selection treats it as distinct while `Image.file` can decode
  /// the exact bytes available through [XFile.path].
  XFile createPng({String? name}) {
    final fileIndex = _nextFileIndex++;
    final fileName = name ?? 'image_$fileIndex.png';
    final bytes = _pngBytesForIndex(fileIndex);
    final file = File('${_directory.path}/$fileName')..writeAsBytesSync(bytes);
    return XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: 'image/png',
      path: file.path,
    );
  }

  /// Deletes every temporary image file owned by this fixture.
  void dispose() => _directory.deleteSync(recursive: true);
}

List<int> _pngBytesForIndex(int index) {
  final textData = <int>[
    102, // f
    105, // i
    120, // x
    116, // t
    117, // u
    114, // r
    101, // e
    0,
    ...index.toString().codeUnits,
  ];
  final typeAndData = <int>[116, 69, 88, 116, ...textData]; // tEXt
  final crc = _crc32(typeAndData);
  final chunk = <int>[
    ..._uint32Bytes(textData.length),
    ...typeAndData,
    ..._uint32Bytes(crc),
  ];
  final iendStart = _onePixelPng.length - 12;
  return <int>[
    ..._onePixelPng.sublist(0, iendStart),
    ...chunk,
    ..._onePixelPng.sublist(iendStart),
  ];
}

List<int> _uint32Bytes(int value) => <int>[
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ 0xedb88320;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
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
