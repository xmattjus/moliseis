import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/repositories/admin_content_submission_api_exception.dart';
import 'package:moliseis/data/repositories/admin_content_submission_repository_impl.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/external_event_token_bridge.dart';
import '../support/mock_logger.dart';

void main() {
  test(
    'real authenticated Dart preview/apply preserves PostgreSQL microsecond '
    'tokens, rejects drift and retries a lost committed response',
    () async {
      final bridge = await ExternalEventTokenBridge.start();
      addTearDown(bridge.dispose);
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final email = 'token-admin-$nonce@example.test';
      final password = 'Local-Token-$nonce-Pass!';
      final fixture = await bridge.command({
        'operation': 'setup',
        'email': email,
        'password': password,
      });
      final client = SupabaseClient(
        fixture['url'] as String,
        fixture['fake_key'] as String,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final session = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      expect(session.user!.id, fixture['admin_id']);
      expect(session.user!.id, isNot(fixture['importer_id']));
      final repository = AdminContentSubmissionRepositoryImpl(
        logger: MockLogger(),
        supabaseClient: client,
      );
      final eventId = fixture['event_id'] as int;
      final initial = fixture['submission_id'] as int;
      final linked = await repository.link(initial, eventId);
      expect(linked, isA<Success<AdminEventResolution>>());
      expect((linked as Success<AdminEventResolution>).value.outcome, 'linked');
      final update = await bridge.command({'operation': 'advance'});
      final id = update['submission_id'] as int;
      final previewResult = await repository.mergePreview(id, eventId);
      expect(previewResult, isA<Success<AdminEventMergePreview>>());
      final preview = (previewResult as Success<AdminEventMergePreview>).value;
      final tokens = await bridge.command({'operation': 'tokens'});
      expect(
        preview.submissionVersionToken,
        (tokens['wire_preview'] as Map)['submission_version_token'],
      );
      expect(
        preview.eventVersionToken,
        (tokens['wire_preview'] as Map)['event_version_token'],
      );
      expect(preview.submissionVersionToken, contains('.123456'));
      expect(preview.eventVersionToken, contains('.654321'));
      // No DateTime parsing/reserialization of either original token.
      for (final mismatch in ['submission', 'event']) {
        final shifted = AdminEventMergePreview(
          targetEventId: eventId,
          submissionVersionToken: mismatch == 'submission'
              ? tokens['shifted_submission'] as String
              : preview.submissionVersionToken,
          eventVersionToken: mismatch == 'event'
              ? tokens['shifted_event'] as String
              : preview.eventVersionToken,
          groups: preview.groups,
        );
        final result = await repository.apply(id, shifted);
        expect(result, isA<Error<AdminEventResolution>>());
        final error =
            (result as Error<AdminEventResolution>).error
                as AdminContentSubmissionApiException;
        expect(error.statusCode, 409);
        expect(error.code, '${mismatch.toUpperCase()}_CHANGED');
        final observed = await bridge.command({'operation': 'observe'});
        final apply = observed['apply'] as Map;
        expect(apply['before'], apply['after']);
        expect((apply['equality'] as Map)[mismatch], isFalse);
        expect(
          (apply['equality'] as Map)[mismatch == 'submission'
              ? 'event'
              : 'submission'],
          isTrue,
        );
        expect(
          (apply['body'] as Map)['submission_version_token'],
          shifted.submissionVersionToken,
        );
        expect(
          (apply['body'] as Map)['event_version_token'],
          shifted.eventVersionToken,
        );
      }
      await bridge.command({'operation': 'mutateEvent'});
      final stale = await repository.apply(id, preview);
      expect(stale, isA<Error<AdminEventResolution>>());
      expect(
        ((stale as Error<AdminEventResolution>).error
                as AdminContentSubmissionApiException)
            .code,
        'EVENT_CHANGED',
      );
      final staleProof = await bridge.command({'operation': 'observe'});
      expect((staleProof['apply'] as Map)['status'], 409);
      expect(
        ((staleProof['apply'] as Map)['equality'] as Map)['submission'],
        isTrue,
      );
      expect(
        ((staleProof['apply'] as Map)['equality'] as Map)['event'],
        isFalse,
      );
      expect(
        (staleProof['apply'] as Map)['before'],
        (staleProof['apply'] as Map)['after'],
      );
      final freshResult = await repository.mergePreview(id, eventId);
      expect(freshResult, isA<Success<AdminEventMergePreview>>());
      final fresh = (freshResult as Success<AdminEventMergePreview>).value;
      final freshTokens = await bridge.command({'operation': 'tokens'});
      expect(
        fresh.submissionVersionToken,
        (freshTokens['wire_preview'] as Map)['submission_version_token'],
      );
      expect(
        fresh.eventVersionToken,
        (freshTokens['wire_preview'] as Map)['event_version_token'],
      );
      // Source Z arrives while Y is pending. Resolving Y must enqueue Z with
      // the technical identity, while handled_by belongs to the real Admin JWT.
      await bridge.command({'operation': 'advance'});
      await bridge.command({'operation': 'loseResponse'});
      final lost = await repository.apply(id, fresh);
      expect(lost, isA<Error<AdminEventResolution>>());
      final committed = await bridge.command({'operation': 'observe'});
      final applyProof = committed['apply'] as Map;
      final body = applyProof['body'] as Map;
      expect(body['submission_version_token'], fresh.submissionVersionToken);
      expect(body['event_version_token'], fresh.eventVersionToken);
      expect(body.containsKey('handled_by'), isFalse);
      expect(body.containsKey('groups_to_apply'), isFalse);
      expect(
        applyProof['status'],
        200,
        reason: 'The real handler must commit before the response is lost.',
      );
      final equality = applyProof['equality'] as Map;
      expect(equality['submission'], isTrue);
      expect(equality['event'], isTrue);
      final state = committed['state'] as Map;
      expect((state['submission'] as Map)['status'], 'accepted');
      expect((state['submission'] as Map)['handled_by'], fixture['admin_id']);
      expect((state['event'] as Map)['name'], 'Source Y');
      expect(
        (state['event'] as Map)['description'],
        'Concurrent editorial description',
      );
      expect(
        ((state['record'] as Map)['proposed_normalized'] as Map)['name'],
        'Source Y',
      );
      final pending = (state['pending'] as List).single as Map;
      expect(pending['name'], 'Source Z');
      expect(pending['user_id'], fixture['importer_id']);
      final retry = await repository.apply(id, fresh);
      expect(retry, isA<Success<AdminEventResolution>>());
      expect(
        (retry as Success<AdminEventResolution>).value.outcome,
        'already_resolved',
      );
      final replay = await bridge.command({'operation': 'observe'});
      expect(replay['state'], state);
      expect(
        (replay['apply'] as Map)['before'],
        (replay['apply'] as Map)['after'],
      );
    },
    skip: Platform.environment['MOLISE_EXTERNAL_TOKEN_LOCAL_E2E'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
