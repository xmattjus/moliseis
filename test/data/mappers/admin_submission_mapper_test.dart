import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/mappers/admin_submission_mapper.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
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
    test('serializes exactly the nine editor-owned keys', () {
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
          'latitude',
          'longitude',
        ]),
      );
      expect(wire, isNot(contains('user_id')));
      expect(wire, isNot(contains('status')));
      expect(wire, isNot(contains('assets')));
    });

    test('serializes a null coordinate pair explicitly', () {
      final wire = adminSubmissionInputToWireMap(
        AdminSubmissionInput(
          category: ContentCategory.history,
          city: 'Isernia',
          name: 'Palazzo storico',
        ),
      );

      expect(wire.containsKey('latitude'), isTrue);
      expect(wire.containsKey('longitude'), isTrue);
      expect(wire['latitude'], isNull);
      expect(wire['longitude'], isNull);
    });

    test('serializes a valid pair as numbers', () {
      final wire = adminSubmissionInputToWireMap(
        AdminSubmissionInput(
          category: ContentCategory.history,
          city: 'Campobasso',
          name: 'Teatro',
          latitude: 41.5575078,
          longitude: 14.6485406,
        ),
      );

      expect(wire['latitude'], 41.5575078);
      expect(wire['longitude'], 14.6485406);
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
      expect(submission.latitude, isNull);
      expect(submission.longitude, isNull);
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

    test('restores coordinates and normalizes JSON ints to doubles', () {
      final submission = adminSubmissionFromWire(<String, dynamic>{
        ...validWire,
        'latitude': 41.5575078,
        'longitude': 14.6485406,
      });
      expect(submission.latitude, 41.5575078);
      expect(submission.longitude, 14.6485406);

      final intTyped = adminSubmissionFromWire(<String, dynamic>{
        ...validWire,
        'latitude': 41,
        'longitude': -14,
      });
      expect(intTyped.latitude, 41.0);
      expect(intTyped.longitude, -14.0);
    });

    test('parses absent coordinate keys as null', () {
      final wire = <String, dynamic>{...validWire}
        ..remove('latitude')
        ..remove('longitude');
      final submission = adminSubmissionFromWire(wire);
      expect(submission.latitude, isNull);
      expect(submission.longitude, isNull);
    });

    test('maps absent and null promotion links to no promotion', () {
      expect(adminSubmissionFromWire(validWire).promotion, isNull);

      final nullLinks = adminSubmissionFromWire(<String, dynamic>{
        ...validWire,
        'promoted_place_id': null,
        'promoted_event_id': null,
      });
      expect(nullLinks.promotion, isNull);
    });

    test('maps a place link and an event link to their promotion', () {
      final placeLink = adminSubmissionFromWire(<String, dynamic>{
        ...validWire,
        'promoted_place_id': 42,
        'promoted_event_id': null,
      });
      expect(
        placeLink.promotion,
        const AdminSubmissionPromotion(
          target: AdminPromotionTarget.place,
          entityId: 42,
        ),
      );

      final eventLink = adminSubmissionFromWire(<String, dynamic>{
        ...validWire,
        'promoted_place_id': null,
        'promoted_event_id': 43,
      });
      expect(
        eventLink.promotion,
        const AdminSubmissionPromotion(
          target: AdminPromotionTarget.event,
          entityId: 43,
        ),
      );
    });

    test('rejects malformed promotion link wire data', () {
      for (final value in <Object?>[
        // Both links populated violate the database CHECK constraint.
        <String, dynamic>{
          ...validWire,
          'promoted_place_id': 42,
          'promoted_event_id': 43,
        },
        <String, dynamic>{...validWire, 'promoted_place_id': 42.0},
        <String, dynamic>{...validWire, 'promoted_place_id': '42'},
        <String, dynamic>{...validWire, 'promoted_event_id': 0},
        <String, dynamic>{...validWire, 'promoted_event_id': -1},
      ]) {
        expect(() => adminSubmissionFromWire(value), throwsFormatException);
      }
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
        <String, dynamic>{...validWire, 'latitude': '41.55'},
        <String, dynamic>{...validWire, 'longitude': true},
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

  group('adminSubmissionPromotionFromWire', () {
    test('parses a successful promotion envelope', () {
      expect(
        adminSubmissionPromotionFromWire(<String, dynamic>{
          'target_type': 'place',
          'entity_id': 42,
        }),
        const AdminSubmissionPromotion(
          target: AdminPromotionTarget.place,
          entityId: 42,
        ),
      );
      expect(
        adminSubmissionPromotionFromWire(<String, dynamic>{
          'target_type': 'event',
          'entity_id': 43,
        }),
        const AdminSubmissionPromotion(
          target: AdminPromotionTarget.event,
          entityId: 43,
        ),
      );
    });

    test('rejects unknown targets and malformed envelopes', () {
      for (final value in <Object?>[
        <Object?>[],
        null,
        <String, dynamic>{},
        <String, dynamic>{'target_type': 'venue', 'entity_id': 1},
        <String, dynamic>{'target_type': null, 'entity_id': 1},
        <String, dynamic>{'target_type': 'place'},
        <String, dynamic>{'entity_id': 1},
        <String, dynamic>{'target_type': 'place', 'entity_id': null},
        <String, dynamic>{'target_type': 'place', 'entity_id': 0},
        <String, dynamic>{'target_type': 'place', 'entity_id': -1},
        <String, dynamic>{'target_type': 'place', 'entity_id': '42'},
        <String, dynamic>{'target_type': 'place', 'entity_id': 42.5},
        <String, dynamic>{
          'target_type': 'place',
          'entity_id': 1,
          'extra': true,
        },
      ]) {
        expect(
          () => adminSubmissionPromotionFromWire(value),
          throwsFormatException,
        );
      }
    });
  });
}
