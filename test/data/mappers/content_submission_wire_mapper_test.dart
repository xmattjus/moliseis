import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/mappers/content_submission_wire_mapper.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/submission_asset.dart';

void main() {
  test('maps only the allowlisted public wire fields', () {
    final delta = <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'Visita guidata\n'},
    ];
    final submission = ContentSubmission(
      category: ContentCategory.history,
      city: 'Isernia',
      name: 'Visita guidata',
      description: 'Visita guidata',
      descriptionDelta: delta,
      latitude: 41.6,
      longitude: 14.2,
      address: 'Centro storico',
      startDate: DateTime.parse('2026-07-25T12:30:00+02:00'),
      endDate: DateTime.parse('2026-07-26T12:30:00+02:00'),
      userEmail: 'author@example.com',
      userName: 'Author',
      createdAt: DateTime.utc(2020),
      modifiedAt: DateTime.utc(2021),
    );

    final wire = contentSubmissionToWireMap(
      clientSubmissionId: '00000000-0000-4000-8000-000000000001',
      contentSubmission: submission,
      submissionAssets: const <SubmissionAsset>[
        SubmissionAsset(
          secureUrl: 'https://res.cloudinary.com/example/image/upload/a.jpg',
          width: 100,
          height: 200,
        ),
        SubmissionAsset(
          secureUrl: 'https://res.cloudinary.com/example/image/upload/b.jpg',
          width: 300,
          height: 400,
          mimeType: 'image/jpeg',
          durationSeconds: 3,
        ),
      ],
    );

    expect(
      wire.keys,
      unorderedEquals(<String>[
        'client_submission_id',
        'category',
        'city',
        'name',
        'description',
        'description_delta',
        'latitude',
        'longitude',
        'address',
        'start_date',
        'end_date',
        'user_email',
        'user_name',
        'assets',
      ]),
    );
    expect(wire['start_date'], '2026-07-25T10:30:00.000Z');
    expect(wire['end_date'], '2026-07-26T10:30:00.000Z');
    expect(wire['description_delta'], delta);
    expect(wire['assets'], <Map<String, dynamic>>[
      <String, dynamic>{
        'url': 'https://res.cloudinary.com/example/image/upload/a.jpg',
        'width': 100,
        'height': 200,
        'mime_type': null,
        'duration_seconds': null,
      },
      <String, dynamic>{
        'url': 'https://res.cloudinary.com/example/image/upload/b.jpg',
        'width': 300,
        'height': 400,
        'mime_type': 'image/jpeg',
        'duration_seconds': 3,
      },
    ]);
    expect(wire, isNot(contains('user_id')));
    expect(wire, isNot(contains('created_at')));
    expect(wire, isNot(contains('modified_at')));
    expect(wire, isNot(contains('accepted_terms')));
  });

  test('preserves null optional fields', () {
    final wire = contentSubmissionToWireMap(
      clientSubmissionId: '00000000-0000-4000-8000-000000000001',
      contentSubmission: ContentSubmission(
        city: 'Isernia',
        name: 'Visita guidata',
        userEmail: 'author@example.com',
        userName: 'Author',
      ),
      submissionAssets: const <SubmissionAsset>[],
    );

    expect(wire['category'], isNull);
    expect(wire['description'], isNull);
    expect(wire['description_delta'], isNull);
    expect(wire['latitude'], isNull);
    expect(wire['longitude'], isNull);
    expect(wire['address'], isNull);
    expect(wire['start_date'], isNull);
    expect(wire['end_date'], isNull);
  });
}
