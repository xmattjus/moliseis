import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';

void main() {
  test('round-trips complete media metadata', () {
    final media = Media(
      remoteId: 42,
      title: 'Title',
      author: 'Author',
      license: 'CC BY-SA',
      licenseUrl: 'https://example.com/license',
      url: 'https://example.com/image.jpg',
      width: 1200,
      height: 800,
      createdAt: DateTime.utc(2025, 1, 2, 3, 4),
      modifiedAt: DateTime.utc(2026, 2, 3, 4, 5),
      areaName: 'Area',
      cityName: 'City',
    );

    final data = GalleryPreviewRouteData(media: [media], initialIndex: 0);
    final parsed = GalleryPreviewRouteData.tryParse(data.toExtra());

    expect(parsed, isNotNull);
    expect(parsed!.initialIndex, 0);
    expect(parsed.media, [media]);
  });

  test('rejects malformed, empty, and out-of-range payloads', () {
    expect(GalleryPreviewRouteData.tryParse(null), isNull);
    expect(
      GalleryPreviewRouteData.tryParse(<String, Object?>{
        'initialIndex': 0,
        'media': <Object?>[],
      }),
      isNull,
    );
    expect(
      GalleryPreviewRouteData.tryParse(<String, Object?>{
        'initialIndex': -1,
        'media': GalleryPreviewRouteData(
          media: [_buildMedia()],
          initialIndex: 0,
        ).toExtra()['media'],
      }),
      isNull,
    );
    expect(
      GalleryPreviewRouteData.tryParse(<String, Object?>{
        'initialIndex': 1,
        'media': GalleryPreviewRouteData(
          media: [_buildMedia()],
          initialIndex: 0,
        ).toExtra()['media'],
      }),
      isNull,
    );
  });

  test('extreme timestamps are rejected without throwing', () {
    final extra = GalleryPreviewRouteData(
      media: [_buildMedia()],
      initialIndex: 0,
    ).toExtra();
    final encodedMedia = extra['media']! as List<Object?>;
    final encodedItem = encodedMedia.single! as Map<String, Object?>;
    encodedItem['createdAt'] = -9223372036854775807 - 1;

    expect(() => GalleryPreviewRouteData.tryParse(extra), returnsNormally);
    expect(GalleryPreviewRouteData.tryParse(extra), isNull);
  });

  test('encodes only standard message-codec values', () {
    final extra = GalleryPreviewRouteData(
      media: [_buildMedia()],
      initialIndex: 0,
    ).toExtra();

    expect(_isSerializable(extra), isTrue);
  });

  test('constructor validates internal caller input', () {
    expect(
      () => GalleryPreviewRouteData(media: const [], initialIndex: 0),
      throwsArgumentError,
    );
    expect(
      () => GalleryPreviewRouteData(media: [_buildMedia()], initialIndex: 1),
      throwsRangeError,
    );
  });

  group('_tryParseMedia field-level validation', () {
    const badValuesByKey = <String, List<Object?>>{
      'remoteId': ['not-an-int', null],
      'url': [null, 5],
      'width': ['not-an-int', null],
      'height': ['not-an-int', null],
      'createdAt': [
        'not-an-int',
        null,
        -9223372036854775807 - 1,
        9223372036854775807,
        -8640000000000001,
        8640000000000001,
      ],
      'modifiedAt': [
        'not-an-int',
        null,
        -9223372036854775807 - 1,
        9223372036854775807,
        -8640000000000001,
        8640000000000001,
      ],
      'areaName': [null, 5],
      'cityName': [null, 5],
      'title': [
        5,
        ['not-a-string'],
      ],
      'author': [
        5,
        ['not-a-string'],
      ],
      'license': [
        5,
        ['not-a-string'],
      ],
      'licenseUrl': [
        5,
        ['not-a-string'],
      ],
    };

    for (final entry in badValuesByKey.entries) {
      final key = entry.key;
      final badValues = entry.value;

      for (final badValue in badValues) {
        test('rejects $key = $badValue', () {
          final encoded = _encodedMedia()..[key] = badValue;

          expect(
            GalleryPreviewRouteData.tryParse(_extraWith([encoded])),
            isNull,
          );
        });
      }
    }

    test('accepts boundary timestamps', () {
      for (final timestamp in const <int>[
        -8640000000000000,
        8640000000000000,
      ]) {
        final encoded = _encodedMedia()..['createdAt'] = timestamp;

        expect(
          GalleryPreviewRouteData.tryParse(_extraWith([encoded])),
          isNotNull,
          reason: 'createdAt = $timestamp',
        );
      }
    });

    test('accepts negative width and height', () {
      final encoded = _encodedMedia()
        ..['width'] = -5
        ..['height'] = -5;

      expect(
        GalleryPreviewRouteData.tryParse(_extraWith([encoded])),
        isNotNull,
      );
    });

    test('accepts null for every nullable field', () {
      final media = Media(
        remoteId: 1,
        url: 'https://example.com/image.jpg',
        width: 800,
        height: 600,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        areaName: 'Event',
        cityName: 'Molise',
      );
      final extra = GalleryPreviewRouteData(
        media: [media],
        initialIndex: 0,
      ).toExtra();

      final parsed = GalleryPreviewRouteData.tryParse(extra);

      expect(parsed, isNotNull);
      expect(parsed!.media.single.title, isNull);
      expect(parsed.media.single.author, isNull);
      expect(parsed.media.single.license, isNull);
      expect(parsed.media.single.licenseUrl, isNull);
    });

    test('never throws for arbitrary payloads', () {
      final random = Random(42);
      final values = <Object?>[
        null,
        true,
        0,
        -1,
        42,
        8640000000000001,
        -8640000000000001,
        -9223372036854775807 - 1,
        9223372036854775807,
        '',
        'x',
        1.5,
        <Object?>[],
        <String, Object?>{},
      ];
      final keys = [
        'remoteId',
        'title',
        'author',
        'license',
        'licenseUrl',
        'url',
        'width',
        'height',
        'createdAt',
        'modifiedAt',
        'areaName',
        'cityName',
      ];

      for (var i = 0; i < 100; i++) {
        final media = <Object?>[];
        for (var j = 0; j < 3; j++) {
          final map = <Object?, Object?>{};
          for (final key in keys) {
            map[key] = values[random.nextInt(values.length)];
          }
          media.add(map);
        }

        expect(
          () => GalleryPreviewRouteData.tryParse(
            <String, Object?>{
              'initialIndex': random.nextInt(3),
              'media': media,
            },
          ),
          returnsNormally,
          reason: 'iteration $i',
        );
      }
    });

    group('restorationBundle round-trip', () {
      test('round-trips a multi-media payload at a non-zero initial index', () {
        final media = <Media>[
          _buildMediaWith(id: 1, title: 'First'),
          _buildMediaWith(id: 2, title: 'Second'),
          _buildMediaWith(id: 3, title: 'Third'),
          _buildMediaWith(id: 4, title: 'Fourth'),
        ];
        final data = GalleryPreviewRouteData(media: media, initialIndex: 2);

        final parsed = GalleryPreviewRouteData.tryParse(data.toExtra());

        expect(parsed, isNotNull);
        expect(parsed!.initialIndex, 2);
        expect(parsed.media.length, 4);
        expect(parsed.media, media);
      });

      test('toExtra() survives JSON encode/decode (router codec proxy)', () {
        final data = GalleryPreviewRouteData(
          media: <Media>[
            _buildMediaWith(id: 1),
            _buildMediaWith(id: 2),
            _buildMediaWith(id: 3),
          ],
          initialIndex: 1,
        );

        final decoded =
            jsonDecode(jsonEncode(data.toExtra())) as Map<String, Object?>;
        final parsed = GalleryPreviewRouteData.tryParse(decoded);

        expect(parsed, isNotNull);
        expect(parsed!.initialIndex, 1);
        expect(parsed.media.length, 3);
        expect(parsed.media[1].remoteId, 2);
      });

      test('re-encoding the parsed payload is stable', () {
        final data = GalleryPreviewRouteData(
          media: <Media>[
            _buildMediaWith(id: 1),
            _buildMediaWith(id: 2),
          ],
          initialIndex: 1,
        );

        final once = GalleryPreviewRouteData.tryParse(data.toExtra())!;
        final twice = GalleryPreviewRouteData.tryParse(once.toExtra())!;

        expect(twice.initialIndex, once.initialIndex);
        expect(twice.media, once.media);
      });
    });
  });
}

Map<String, Object?> _encodedMedia([Media? media]) {
  final effective = media ?? _buildMedia();
  final extra = GalleryPreviewRouteData(
    media: [effective],
    initialIndex: 0,
  ).toExtra();
  return (extra['media']! as List<Object?>).single! as Map<String, Object?>;
}

Map<String, Object?> _extraWith(List<Object?> media) => <String, Object?>{
  'initialIndex': 0,
  'media': media,
};

bool _isSerializable(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return true;
  }
  if (value is List<Object?>) return value.every(_isSerializable);
  if (value is Map<Object?, Object?>) {
    return value.keys.every((key) => key is String) &&
        value.values.every(_isSerializable);
  }
  return false;
}

Media _buildMedia() => Media(
  remoteId: 1,
  url: 'https://example.com/image.jpg',
  width: 800,
  height: 600,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  areaName: 'Event',
  cityName: 'Molise',
);

/// Single [Media] with a distinct [Media.remoteId] and [Media.url].
Media _buildMediaWith({required int id, String? title}) => Media(
  remoteId: id,
  title: title,
  url: 'https://example.com/$id.jpg',
  width: 800,
  height: 600,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  areaName: 'Event',
  cityName: 'Molise',
);
