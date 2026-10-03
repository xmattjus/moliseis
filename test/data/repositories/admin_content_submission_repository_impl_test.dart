import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/data/repositories/admin_content_submission_repository_impl.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/domain/models/admin_submission_asset.dart';
import 'package:moliseis/domain/models/admin_submission_input.dart';
import 'package:moliseis/domain/models/admin_submission_promotion.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/admin_moderation_error_cases.dart';
import '../../support/mock_logger.dart';
import '../../support/recording_supabase_functions_http_client.dart';

void main() {
  final submission = <String, dynamic>{
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
    'created_at': '2026-08-22T10:00:00Z',
    'modified_at': '2026-08-22T11:00:00Z',
    'assets': <Object?>[],
  };

  late RecordingSupabaseFunctionsHttpClient httpClient;
  late MockLogger logger;
  late SupabaseClient client;
  late AdminContentSubmissionRepositoryImpl repository;

  setUp(() {
    httpClient = RecordingSupabaseFunctionsHttpClient();
    logger = MockLogger();
    client = SupabaseClient(
      'https://test-project.supabase.co',
      'test-publishable-key',
      httpClient: httpClient,
      accessToken: () async => 'test-staff-access-token',
    );
    repository = AdminContentSubmissionRepositoryImpl(
      logger: logger,
      supabaseClient: client,
    );
  });

  tearDown(() => client.dispose());

  test(
    'preview tokens survive Edge JSON to Apply request byte for byte',
    () async {
      const submissionToken = '2026-10-02 10:30:00.123456+02';
      const eventToken = '2026-10-02T08:30:00.000001Z';
      httpClient.queueJson({
        'preview': {
          'target_event_id': 42,
          'submission_version_token': submissionToken,
          'event_version_token': eventToken,
          'groups': <Object?>[],
        },
      });
      final preview = (await repository.mergePreview(7, 42)).getOrNull()!;
      httpClient.queueJson({
        'resolution': {
          'outcome': 'applied',
          'target_event_id': 42,
          'pending_submission_id': 8,
        },
      });
      final result = (await repository.apply(7, preview)).getOrNull()!;
      expect(result.pendingId, 8);
      expect(httpClient.requests.last.body, {
        'operation': 'apply',
        'submission_id': 7,
        'target_event_id': 42,
        'submission_version_token': submissionToken,
        'event_version_token': eventToken,
      });
      expect(result, isA<AdminEventResolution>());
    },
  );

  test(
    'candidate discovery keeps canonical targets separate from warnings',
    () async {
      httpClient.queueJson({
        'candidates': {
          'events': [
            {'id': 42, 'name': 'Event', 'city': null},
          ],
          'pending_warnings': [
            {'id': 8, 'name': 'Pending', 'city': 'Termoli'},
          ],
        },
      });
      final matches = (await repository.eventCandidates(
        7,
        searchName: 'festa',
      )).getOrNull()!;
      expect(matches.events.single.id, 42);
      expect(matches.events.single.city, isNull);
      expect(matches.pendingWarnings.single.id, 8);
      expect(httpClient.requests.single.body, {
        'operation': 'eventCandidates',
        'submission_id': 7,
        'search_name': 'festa',
      });
    },
  );

  for (final (code, status, _) in adminModerationErrorCases) {
    test('preserves $code API status/message on resolution failure', () async {
      httpClient.queueJson({
        'code': code,
        'message': 'Original backend message',
      }, status: status);
      final result = await repository.link(7, 42);
      final error =
          (result as Error<AdminEventResolution>).error
              as AdminContentSubmissionApiException;
      expect(error.statusCode, status);
      expect(error.code, code);
      expect(error.message, 'Original backend message');
    });
  }

  test(
    'already linked source stays API error and never parses promotion success',
    () async {
      httpClient.queueJson({
        'code': 'PROMOTION_SOURCE_ALREADY_LINKED',
        'message': 'Use Link or Apply',
        'promotion': {'target_type': 'wrong', 'entity_id': -1},
      }, status: 409);
      final result = await repository.promote(7, AdminPromotionTarget.event);
      expect(result, isA<Error<AdminSubmissionPromotion>>());
      final error =
          (result as Error<AdminSubmissionPromotion>).error
              as AdminContentSubmissionApiException;
      expect(error.code, 'PROMOTION_SOURCE_ALREADY_LINKED');
      expect(error.statusCode, 409);
      expect(error.message, 'Use Link or Apply');
      expect(error, isNot(isA<FormatException>()));
    },
  );

  test(
    'source options preserve displayed hash across all resolution envelopes',
    () async {
      final hash = 'abcdef0123456789' * 4;
      httpClient.queueJson({
        'ok': true,
        'status': 'rejected',
        'pending_submission_id': 9,
      });
      final rejected = (await repository.reject(
        7,
        ignoreSource: true,
        acknowledgeCurrentSource: true,
        expectedSourceHash: hash,
      )).getOrNull()!;
      expect(rejected.outcome, 'rejected');
      expect(rejected.pendingId, 9);
      expect(httpClient.requests.last.body, {
        'operation': 'changeStatus',
        'submission_id': 7,
        'status': 'rejected',
        'ignore_source': true,
        'acknowledge_current_source': true,
        'expected_source_hash': hash,
      });
      httpClient.queueJson({
        'promotion': {'target_type': 'event', 'entity_id': 42},
      });
      await repository.promote(
        7,
        AdminPromotionTarget.event,
        acknowledgeCurrentSource: true,
        expectedSourceHash: hash,
      );
      expect(httpClient.requests.last.body, {
        'operation': 'promote',
        'submission_id': 7,
        'target': 'event',
        'acknowledge_current_source': true,
        'expected_source_hash': hash,
      });
      httpClient.queueJson({
        'resolution': {
          'outcome': 'linked',
          'target_event_id': 42,
          'pending_submission_id': 10,
        },
      });
      await repository.link(
        7,
        42,
        acknowledgeCurrentSource: true,
        expectedSourceHash: hash,
      );
      expect(httpClient.requests.last.body, {
        'operation': 'link',
        'submission_id': 7,
        'target_event_id': 42,
        'acknowledge_current_source': true,
        'expected_source_hash': hash,
      });
      httpClient.queueJson({
        'resolution': {
          'outcome': 'already_resolved',
          'target_event_id': 42,
          'pending_submission_id': null,
        },
      });
      final applied = (await repository.apply(
        7,
        AdminEventMergePreview(
          targetEventId: 42,
          submissionVersionToken: 'raw s',
          eventVersionToken: 'raw e',
          groups: [],
        ),
        acknowledgeCurrentSource: true,
        expectedSourceHash: hash,
      )).getOrNull()!;
      expect(applied.outcome, 'already_resolved');
      expect(httpClient.requests.last.body, {
        'operation': 'apply',
        'submission_id': 7,
        'target_event_id': 42,
        'submission_version_token': 'raw s',
        'event_version_token': 'raw e',
        'acknowledge_current_source': true,
        'expected_source_hash': hash,
      });
      for (final request in httpClient.requests) {
        expect(request.body! as Map, isNot(contains('handled_by')));
        expect(
          request.headers['authorization'],
          'Bearer test-staff-access-token',
        );
      }
    },
  );

  test(
    'ignored sources and un-ignore are authenticated minimal operations',
    () async {
      httpClient.queueJson({
        'sources': [
          {
            'id': 12,
            'name': 'Ignored',
            'provider': 'eventimolise',
            'external_id': 'a',
            'occurrence_key': null,
            'ignored_at': '2026-10-02T10:00:00Z',
            'event_id': null,
          },
        ],
      });
      final sources = (await repository.listIgnoredSources()).getOrNull()!;
      expect(sources.single.externalId, 'a');
      expect(sources.single.eventId, isNull);
      expect(httpClient.requests.last.body, {
        'operation': 'listIgnoredSources',
      });
      httpClient.queueJson({
        'outcome': 'unignored',
        'pending_submission_id': 8,
      });
      final result = (await repository.unIgnoreSource(12)).getOrNull()!;
      expect(result.outcome, 'unignored');
      expect(result.pendingId, 8);
      expect(httpClient.requests.last.body, {
        'operation': 'unIgnoreSource',
        'external_event_record_id': 12,
      });
      httpClient.queueJson({
        'code': 'FORBIDDEN',
        'message': 'Admin only',
      }, status: 403);
      final denied = await repository.unIgnoreSource(12);
      expect(
        (denied as Error<AdminEventResolution>).error,
        isA<AdminContentSubmissionApiException>(),
      );
      expect(
        httpClient.requests.last.headers['authorization'],
        'Bearer test-staff-access-token',
      );
    },
  );

  group('successful Function operations', () {
    test(
      'list sends the exact request and maps submissions without logging',
      () async {
        httpClient.queueJson(<String, dynamic>{
          'submissions': <Object?>[submission],
        });

        final result = await repository.list();

        expect(result, isA<Success<List<AdminSubmission>>>());
        expect((result as Success<List<AdminSubmission>>).value.single.id, 7);
        expect(httpClient.requests, hasLength(1));
        final request = httpClient.requests.single;
        expect(request.method, 'POST');
        expect(request.url.path, '/functions/v1/admin-content-submissions');
        expect(
          request.headers['authorization'],
          'Bearer test-staff-access-token',
        );
        expect(request.headers['apikey'], 'test-publishable-key');
        expect(request.headers['content-type'], contains('application/json'));
        expect(request.body, <String, dynamic>{'operation': 'list'});
        expect(logger.eventsOfType<AdminBackendRequestFailed>(), isEmpty);
      },
    );

    test('getById maps read-only assets in one request', () async {
      httpClient.queueJson(<String, dynamic>{
        'submission': <String, dynamic>{
          ...submission,
          'assets': <Object?>[
            <String, dynamic>{
              'id': 5,
              'url': 'https://example.com/image.jpg',
              'width': 1200,
              'height': 800,
            },
          ],
        },
      });

      final result = await repository.getById(7);

      expect((result as Success<AdminSubmission>).value.assets.single.id, 5);
      expect(httpClient.requests.single.body, <String, dynamic>{
        'operation': 'getById',
        'submission_id': 7,
      });
      expect(httpClient.requests, hasLength(1));
    });

    test('create sends only the twelve editor-owned fields', () async {
      httpClient.queueJson(<String, dynamic>{'submission': submission});
      final input = AdminSubmissionInput(
        category: ContentCategory.history,
        city: 'Isernia',
        name: 'Palazzo storico',
      );

      final result = await repository.create(input);

      expect(result, isA<Success<AdminSubmission>>());
      final Map<String, dynamic> body;
      switch (httpClient.requests.single.body) {
        case final Map<String, dynamic> value:
          body = value;
        default:
          fail('Expected JSON object request body.');
      }
      expect(body['operation'], 'create');
      expect(
        (body['input'] as Map<String, dynamic>).keys,
        unorderedEquals(<String>[
          'category',
          'city',
          'name',
          'description',
          'description_delta',
          'all_day',
          'start_calendar_date',
          'end_calendar_date',
          'start_date',
          'end_date',
          'latitude',
          'longitude',
        ]),
      );
      expect(body['input'], isNot(contains('user_email')));
      expect(body['input'], isNot(contains('status')));
      expect(httpClient.requests, hasLength(1));
    });

    test('create and update include populated coordinates when set', () async {
      httpClient
        ..queueJson(<String, dynamic>{'submission': submission})
        ..queueJson(<String, dynamic>{'submission': submission});
      final input = AdminSubmissionInput(
        category: ContentCategory.history,
        city: 'Isernia',
        name: 'Palazzo storico',
        latitude: 41.5575078,
        longitude: 14.6485406,
      );

      await repository.create(input);
      await repository.update(7, input);

      for (final request in httpClient.requests) {
        final body = request.body! as Map<String, dynamic>;
        final payload = body['input'] as Map<String, dynamic>;
        expect(payload['latitude'], 41.5575078);
        expect(payload['longitude'], 14.6485406);
      }
    });

    test('update maps its response without a follow-up request', () async {
      httpClient.queueJson(<String, dynamic>{'submission': submission});

      final result = await repository.update(
        7,
        AdminSubmissionInput(
          category: ContentCategory.history,
          city: 'Isernia',
          name: 'Palazzo aggiornato',
        ),
      );

      expect((result as Success<AdminSubmission>).value.assets, isEmpty);
      expect(httpClient.requests.single.body, <String, dynamic>{
        'operation': 'update',
        'submission_id': 7,
        'input': <String, dynamic>{
          'category': 'history',
          'city': 'Isernia',
          'name': 'Palazzo aggiornato',
          'description': null,
          'description_delta': null,
          'all_day': false,
          'start_calendar_date': null,
          'end_calendar_date': null,
          'start_date': null,
          'end_date': null,
          'latitude': null,
          'longitude': null,
        },
      });
      expect(httpClient.requests, hasLength(1));
    });

    test('maps response coordinates from JSON numbers to doubles', () async {
      httpClient.queueJson(<String, dynamic>{
        'submission': <String, dynamic>{
          ...submission,
          'latitude': 41,
          'longitude': 14.5,
        },
      });

      final result = await repository.getById(7);

      expect((result as Success<AdminSubmission>).value.latitude, 41.0);
      expect(result.value.longitude, 14.5);
      expect(httpClient.requests, hasLength(1));
    });

    test('invalid response coordinate types fail once without retry', () async {
      httpClient.queueJson(<String, dynamic>{
        'submission': <String, dynamic>{...submission, 'latitude': '41'},
      });

      final result = await repository.getById(7);

      expect(result, isA<Error<AdminSubmission>>());
      expect(httpClient.requests, hasLength(1));
      final failedCalls = logger.calls
          .where((call) => call.event is AdminBackendRequestFailed)
          .toList();
      expect(failedCalls, hasLength(1));
      expect(failedCalls.single.error, isA<FormatException>());
    });

    test('reject sends the exact reject-only request body', () async {
      httpClient.queueJson(<String, dynamic>{'ok': true, 'status': 'rejected'});

      final result = await repository.reject(7);

      expect(result, isA<Success<void>>());
      expect(httpClient.requests.single.body, <String, dynamic>{
        'operation': 'changeStatus',
        'submission_id': 7,
        'status': 'rejected',
      });
    });

    test('promote sends the exact request and parses the promotion', () async {
      for (final target in AdminPromotionTarget.values) {
        final entityId = target == AdminPromotionTarget.place ? 42 : 43;
        httpClient.queueJson(<String, dynamic>{
          'promotion': <String, dynamic>{
            'target_type': target.name,
            'entity_id': entityId,
          },
        });

        final result = await repository.promote(7, target);

        expect(
          (result as Success<AdminSubmissionPromotion>).value,
          AdminSubmissionPromotion(target: target, entityId: entityId),
        );
        expect(httpClient.requests.last.body, <String, dynamic>{
          'operation': 'promote',
          'submission_id': 7,
          'target': target.name,
        });
      }
    });

    test('list responses preserve durable promotion linkage', () async {
      httpClient.queueJson(<String, dynamic>{
        'submissions': <Object?>[
          <String, dynamic>{
            ...submission,
            'promoted_place_id': null,
            'promoted_event_id': 43,
          },
        ],
      });

      final result = await repository.list();

      expect(
        (result as Success<List<AdminSubmission>>).value.single.promotion,
        const AdminSubmissionPromotion(
          target: AdminPromotionTarget.event,
          entityId: 43,
        ),
      );
    });

    test('addAsset serializes metadata and maps the confirmed asset', () async {
      httpClient.queueJson(<String, dynamic>{
        'asset': <String, dynamic>{
          'id': 11,
          'url': 'https://res.cloudinary.com/moliseis/image/upload/photo.webp',
          'width': 1600,
          'height': 1200,
        },
      });
      const uploadedAsset = SubmissionAsset(
        secureUrl:
            'https://res.cloudinary.com/moliseis/image/upload/photo.webp',
        width: 1600,
        height: 1200,
        mimeType: 'image/webp',
      );

      final result = await repository.addAsset(7, uploadedAsset);

      expect(result, isA<Success<AdminSubmissionAsset>>());
      expect((result as Success<AdminSubmissionAsset>).value.id, 11);
      expect(httpClient.requests.single.body, <String, dynamic>{
        'operation': 'addAsset',
        'submission_id': 7,
        'asset': <String, dynamic>{
          'url': uploadedAsset.secureUrl,
          'width': 1600,
          'height': 1200,
          'mime_type': 'image/webp',
          'duration_seconds': null,
        },
      });
    });

    test('deleteAsset sends the exact request and requires ok true', () async {
      httpClient.queueJson(<String, dynamic>{'ok': true});

      final result = await repository.deleteAsset(7, 11);

      expect(result, isA<Success<void>>());
      expect(httpClient.requests.single.body, <String, dynamic>{
        'operation': 'deleteAsset',
        'submission_id': 7,
        'asset_id': 11,
      });
    });
  });

  group('contract and transport failures', () {
    test(
      'malformed successes are errors, log once, and do not retry',
      () async {
        httpClient
          ..queueJson(<String, dynamic>{})
          ..queueJson(<String, dynamic>{'submission': <Object?>[]})
          ..queueJson(<String, dynamic>{'submission': <Object?>[]})
          ..queueJson(<String, dynamic>{'submission': <Object?>[]})
          ..queueJson(<String, dynamic>{'ok': false, 'status': 'rejected'})
          ..queueJson(<String, dynamic>{
            'promotion': <String, dynamic>{
              'target_type': 'venue',
              'entity_id': 1,
            },
          })
          ..queueJson(<String, dynamic>{
            'promotion': <String, dynamic>{'target_type': 'place'},
          });

        final list = await repository.list();
        final detail = await repository.getById(7);
        final create = await repository.create(
          AdminSubmissionInput(
            category: ContentCategory.history,
            city: 'Isernia',
            name: 'Palazzo',
          ),
        );
        final update = await repository.update(
          7,
          AdminSubmissionInput(
            category: ContentCategory.history,
            city: 'Isernia',
            name: 'Palazzo',
          ),
        );
        final invalidStatus = await repository.reject(7);
        final malformedPromotion = await repository.promote(
          7,
          AdminPromotionTarget.place,
        );
        final malformedEnvelope = await repository.promote(
          8,
          AdminPromotionTarget.event,
        );

        expect(list, isA<Error<List<dynamic>>>());
        expect(detail, isA<Error<AdminSubmission>>());
        expect(create, isA<Error<AdminSubmission>>());
        expect(update, isA<Error<AdminSubmission>>());
        expect(invalidStatus, isA<Error<void>>());
        expect(malformedPromotion, isA<Error<AdminSubmissionPromotion>>());
        expect(malformedEnvelope, isA<Error<AdminSubmissionPromotion>>());
        expect(httpClient.requests, hasLength(7));
        expect(logger.eventsOfType<AdminBackendRequestFailed>(), hasLength(7));
        for (final call in logger.calls) {
          expect(call.error, isA<FormatException>());
          expect(call.stackTrace, isNotNull);
          expect(call.extra, isNull);
          expect(call.event.data.keys, <String>['operation']);
        }
      },
    );

    test('malformed asset mutation responses become logged errors', () async {
      httpClient
        ..queueJson(<String, dynamic>{'asset': <Object?>[]})
        ..queueJson(<String, dynamic>{'ok': false});

      final addResult = await repository.addAsset(
        7,
        const SubmissionAsset(
          secureUrl:
              'https://res.cloudinary.com/moliseis/image/upload/photo.jpg',
          width: 1600,
          height: 1200,
        ),
      );
      final deleteResult = await repository.deleteAsset(7, 11);

      expect(addResult, isA<Error<AdminSubmissionAsset>>());
      expect(deleteResult, isA<Error<void>>());
      expect(logger.eventsOfType<AdminBackendRequestFailed>(), hasLength(2));
    });

    test(
      'preserves custom Function API errors and safe gateway errors',
      () async {
        httpClient
          ..queueJson(<String, dynamic>{
            'code': 'NOT_FOUND',
            'message': 'Submission not found.',
          }, status: 404)
          ..queueJson(<String, dynamic>{
            'code': 'ADMIN_PROFILE_INCOMPLETE',
            'message': 'Profile is incomplete.',
          }, status: 422)
          ..queueJson(<String, dynamic>{
            'code': 'INVALID_STATUS_TRANSITION',
            'message': 'Already moderated.',
          }, status: 409)
          ..queueText('Invalid JWT', status: 401);

        final missing = await repository.getById(7);
        final incomplete = await repository.create(
          AdminSubmissionInput(
            category: ContentCategory.history,
            city: 'Isernia',
            name: 'Palazzo',
          ),
        );
        final invalidTransition = await repository.promote(
          7,
          AdminPromotionTarget.place,
        );
        final gateway = await repository.list();

        final missingError =
            (missing as Error).error as AdminContentSubmissionApiException;
        final incompleteError =
            (incomplete as Error).error as AdminContentSubmissionApiException;
        final transitionError =
            (invalidTransition as Error).error
                as AdminContentSubmissionApiException;
        final gatewayError =
            (gateway as Error).error as AdminContentSubmissionApiException;
        expect(
          (missingError.statusCode, missingError.code, missingError.message),
          (404, 'NOT_FOUND', 'Submission not found.'),
        );
        expect(
          (
            incompleteError.statusCode,
            incompleteError.code,
            incompleteError.message,
          ),
          (422, 'ADMIN_PROFILE_INCOMPLETE', 'Profile is incomplete.'),
        );
        expect(
          (
            transitionError.statusCode,
            transitionError.code,
            transitionError.message,
          ),
          (409, 'INVALID_STATUS_TRANSITION', 'Already moderated.'),
        );
        expect(
          (gatewayError.statusCode, gatewayError.code, gatewayError.message),
          (401, null, 'Invalid JWT'),
        );
        expect(httpClient.requests, hasLength(4));
        expect(logger.eventsOfType<AdminBackendRequestFailed>(), hasLength(4));
      },
    );

    test('normalizes addAsset API errors and logs the operation', () async {
      httpClient.queueJson(<String, dynamic>{
        'code': 'ASSET_LIMIT_REACHED',
        'message': 'A submission can have at most five assets.',
      }, status: 409);

      final result = await repository.addAsset(
        7,
        const SubmissionAsset(
          secureUrl:
              'https://res.cloudinary.com/moliseis/image/upload/photo.jpg',
          width: 1600,
          height: 1200,
        ),
      );

      final error =
          (result as Error).error as AdminContentSubmissionApiException;
      expect((error.statusCode, error.code), (409, 'ASSET_LIMIT_REACHED'));
      expect(
        logger.firstCallOfType<AdminBackendRequestFailed>()?.event.data,
        <String, Object?>{'operation': 'addAsset'},
      );
    });

    test('uses reason phrases for malformed Function error maps', () async {
      httpClient.queueJson(
        <String, dynamic>{'code': 9, 'message': <Object?>[]},
        status: 400,
        reasonPhrase: 'Bad Request',
      );

      final result = await repository.list();
      final error =
          (result as Error).error as AdminContentSubmissionApiException;

      expect(error.statusCode, 400);
      expect(error.code, isNull);
      expect(error.message, 'Bad Request');
    });

    test('returns transport failures without retrying', () async {
      httpClient.error = http.ClientException('network unavailable');

      final result = await repository.list();

      expect(result, isA<Error<List<dynamic>>>());
      expect(httpClient.requests, hasLength(1));
      final call = logger.firstCallOfType<AdminBackendRequestFailed>();
      expect(call?.event.name, 'admin_backend_request_failed');
      expect(call?.event.level.name, 'error');
      expect(call?.event.data, <String, Object?>{'operation': 'list'});
      expect(call?.error, isA<http.ClientException>());
      expect(call?.stackTrace, isNotNull);
      expect(call?.extra, isNull);
    });
  });
  test(
    'Admin all-day full input and stored response retain the mode',
    () async {
      httpClient.queueJson({
        'submission': {
          ...submission,
          'all_day': true,
          'start_date': '2026-10-11T22:00:00Z',
          'end_date': null,
        },
      });
      final result = await repository.create(
        AdminSubmissionInput(
          category: ContentCategory.history,
          city: 'Campobasso',
          name: 'Event',
          allDay: true,
          startDate: DateTime.utc(2026, 10, 11, 22),
        ),
      );
      expect(result.getOrNull()!.allDay, isTrue);
      final body = httpClient.requests.single.body! as Map<String, dynamic>;
      final input = body['input'] as Map<String, dynamic>;
      expect(input['all_day'], isTrue);
      expect(input['start_date'], isNull);
      expect(input['end_date'], isNull);
      expect(input['start_calendar_date'], '2026-10-12');
      expect(input['end_calendar_date'], isNull);
    },
  );
}
