import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/mappers/admin_submission_mapper.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/models/content_category.dart';

void main() {
  final validWire = <String, dynamic>{
    'id': 7,
    'city': 'Isernia',
    'name': 'Palazzo storico',
    'description': null,
    'description_delta': null,
    'start_date': null,
    'end_date': null,
    'category': 'history',
    'user_name': 'Mario Rossi',
    'user_email': 'mario@example.com',
    'status': 'pending',
    'created_at': '2026-08-22T10:00:00+02:00',
    'modified_at': '2026-08-22T11:00:00+02:00',
    'assets': <Object?>[],
  };

  group('adminSubmissionInputToWireMap', () {
    test('serializes exactly the seven editor-owned keys', () {
      final wire = adminSubmissionInputToWireMap(
        AdminSubmissionInput(
          category: ContentCategory.history,
          city: 'Isernia',
          name: 'Palazzo storico',
          description: 'Descrizione',
        ),
      );

      expect(
        wire.keys,
        unorderedEquals(<String>[
          'category',
          'city',
          'name',
          'description',
          'description_delta',
          'start_date',
          'end_date',
        ]),
      );
      expect(wire, isNot(contains('user_id')));
      expect(wire, isNot(contains('status')));
      expect(wire, isNot(contains('assets')));
    });

    test('preserves null optional values and canonical Delta data', () {
      final delta = <Map<String, dynamic>>[
        {'insert': 'Descrizione\n'},
      ];
      final wire = adminSubmissionInputToWireMap(
        AdminSubmissionInput(
          category: ContentCategory.unknown,
          city: 'Termoli',
          name: 'Luogo',
          descriptionDelta: delta,
        ),
      );

      expect(wire['category'], 'unknown');
      expect(wire['city'], 'Termoli');
      expect(wire['name'], 'Luogo');
      expect(wire['description'], isNull);
      expect(wire['description_delta'], delta);
      expect(wire['description_delta'], isA<List<dynamic>>());
      expect(wire['start_date'], isNull);
      expect(wire['end_date'], isNull);
    });

    test('serializes every category through its name', () {
      for (final category in ContentCategory.values) {
        final wire = adminSubmissionInputToWireMap(
          AdminSubmissionInput(category: category, city: 'A', name: 'B'),
        );
        expect(wire['category'], category.name);
      }
    });

    test('converts local-offset dates to UTC ISO-8601 strings', () {
      final wire = adminSubmissionInputToWireMap(
        AdminSubmissionInput(
          category: ContentCategory.experience,
          city: 'Campobasso',
          name: 'Evento',
          startDate: DateTime.parse('2026-08-22T10:00:00+02:00'),
          endDate: DateTime.parse('2026-08-22T12:00:00+02:00'),
        ),
      );

      expect(wire['start_date'], '2026-08-22T08:00:00.000Z');
      expect(wire['end_date'], '2026-08-22T10:00:00.000Z');
    });
  });

  group('adminSubmissionFromWire', () {
    test('maps a pending place with nullable optional fields', () {
      final submission = adminSubmissionFromWire(validWire);

      expect(submission.id, 7);
      expect(submission.category, ContentCategory.history);
      expect(submission.status, AdminSubmissionStatus.pending);
      expect(submission.description, isNull);
      expect(submission.descriptionDelta, isNull);
      expect(submission.startDate, isNull);
      expect(submission.endDate, isNull);
      expect(submission.assets, isEmpty);
      expect(
        submission.createdAt,
        DateTime.parse(validWire['created_at'] as String),
      );
      expect(
        submission.modifiedAt,
        DateTime.parse(validWire['modified_at'] as String),
      );
    });

    test('maps event timestamps, canonical Delta, and actual assets', () {
      final submission = adminSubmissionFromWire(<String, dynamic>{
        ...validWire,
        'description_delta': <Object?>[
          <String, dynamic>{'insert': 'Evento\n'},
        ],
        'start_date': '2026-08-23T09:00:00Z',
        'end_date': '2026-08-23T11:00:00Z',
        'assets': <Object?>[
          <String, dynamic>{
            'id': 11,
            'url': 'https://example.com/image.jpg',
            'width': 1200,
            'height': 800,
          },
        ],
      });

      expect(submission.descriptionDelta, <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'Evento\n'},
      ]);
      expect(submission.startDate, DateTime.parse('2026-08-23T09:00:00Z'));
      expect(submission.endDate, DateTime.parse('2026-08-23T11:00:00Z'));
      expect(submission.assets.single.id, 11);
      expect(submission.assets.single.url, 'https://example.com/image.jpg');
      expect(submission.assets.single.width, 1200);
      expect(submission.assets.single.height, 800);
    });

    test('maps every category and final status', () {
      for (final category in ContentCategory.values) {
        final submission = adminSubmissionFromWire(<String, dynamic>{
          ...validWire,
          'category': category.name,
        });
        expect(submission.category, category);
      }

      for (final status in <AdminSubmissionStatus>[
        AdminSubmissionStatus.accepted,
        AdminSubmissionStatus.rejected,
      ]) {
        final submission = adminSubmissionFromWire(<String, dynamic>{
          ...validWire,
          'status': status.name,
        });
        expect(submission.status, status);
      }
    });

    test('rejects malformed successful responses with FormatException', () {
      final malformedValues = <Object?>[
        <Object?>[],
        <String, dynamic>{...validWire}..remove('id'),
        <String, dynamic>{...validWire, 'user_name': 1},
        <String, dynamic>{...validWire, 'category': 'museum'},
        <String, dynamic>{...validWire, 'status': 'reviewing'},
        <String, dynamic>{...validWire, 'created_at': 'invalid'},
        <String, dynamic>{...validWire, 'modified_at': 'invalid'},
        <String, dynamic>{...validWire, 'start_date': 'invalid'},
        <String, dynamic>{...validWire, 'end_date': 'invalid'},
        <String, dynamic>{...validWire, 'description_delta': '[]'},
        <String, dynamic>{
          ...validWire,
          'description_delta': <Object?>['not an object'],
        },
        <String, dynamic>{...validWire, 'assets': null},
        <String, dynamic>{...validWire, 'assets': <String, dynamic>{}},
        <String, dynamic>{
          ...validWire,
          'assets': <Object?>[
            <String, dynamic>{
              'url': 'https://example.com/image.jpg',
              'width': 1200,
              'height': 800,
            },
          ],
        },
        <String, dynamic>{
          ...validWire,
          'assets': <Object?>[
            <String, dynamic>{
              'id': 1,
              'url': 'https://example.com/image.jpg',
              'width': '1200',
              'height': 800,
            },
          ],
        },
      ];

      for (final value in malformedValues) {
        expect(() => adminSubmissionFromWire(value), throwsFormatException);
      }
    });
  });
}
