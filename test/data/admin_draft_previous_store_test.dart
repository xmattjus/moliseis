import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/admin_submission_draft_entity.dart';
import 'package:moliseis/data/data-sources/admin_submission_staged_asset_entity.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/data/data-sources/content_submission_staged_asset_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/data/mappers/admin_submission_draft_mapper.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import '../support/objectbox_test_store.dart';

void main() {
  test(
    'Admin schema adds exactly two entities and retains all earlier UIDs',
    () {
      final before =
          jsonDecode(
                File(
                  'test/fixtures/objectbox/pre_admin_draft/objectbox-model.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final after =
          jsonDecode(
                File('lib/generated/objectbox-model.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final oldEntities = before['entities'] as List;
      final newEntities = after['entities'] as List;
      expect(newEntities.take(oldEntities.length), oldEntities);
      expect(
        newEntities
            .skip(oldEntities.length)
            .map((dynamic entity) => (entity as Map<String, dynamic>)['name']),
        ['AdminSubmissionDraftEntity', 'AdminSubmissionStagedAssetEntity'],
      );
      for (final key in [
        'retiredEntityUids',
        'retiredPropertyUids',
        'retiredIndexUids',
        'retiredRelationUids',
        'lastRelationId',
        'lastSequenceId',
        'modelVersion',
        'modelVersionParserMinimum',
      ]) {
        expect(after[key], before[key], reason: key);
      }
    },
  );
  test(
    'populated pre-Admin store preserves existing data and adds Admin rows',
    () async {
      final env = await TestObjectBoxEnvironment.create(
        previousStoreGzipPath:
            'test/fixtures/objectbox/pre_admin_draft/data.mdb.gz',
      );
      addTearDown(env.dispose);
      final settings = env.store.box<AppSettings>().get(1)!;
      expect(settings.crashReporting, isFalse);
      expect(settings.contentSyncCursorAt?.toUtc(), DateTime.utc(2026, 10, 20));
      expect(settings.lastSyncedAt?.toUtc(), DateTime.utc(2026, 10, 21));
      final city = env.store.box<CityEntity>().getAll().single;
      expect(city.remoteId, 71);
      expect(city.name, 'Fixture city');
      final event = env.store.box<EventEntity>().getAll().single;
      expect(event.remoteId, 72);
      expect(event.name, 'Fixture event');
      expect(event.allDay, isTrue);
      expect(event.city.targetId, city.remoteId);
      final place = env.store.box<PlaceEntity>().getAll().single;
      expect(place.remoteId, 73);
      expect(place.name, 'Fixture place');
      expect(place.city.targetId, city.remoteId);
      final publicDraft = env.store.box<ContentSubmissionDraftEntity>().get(1)!;
      expect(publicDraft.name, 'Fixture public draft');
      expect(publicDraft.allDay, isTrue);
      final publicAsset = env.store
          .box<ContentSubmissionStagedAssetEntity>()
          .getAll()
          .single;
      expect(publicAsset.clientSubmissionId, publicDraft.clientSubmissionId);
      expect(publicAsset.digest, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(
        publicAsset.relativePath,
        '${publicDraft.clientSubmissionId}/${publicAsset.digest}',
      );
      final owner = AdminDraftOwner(
        accountId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      final draft = AdminSubmissionDraft(
        owner: owner,
        snapshot: AdminDraftSnapshot(name: 'Admin'),
      );
      final box = env.store.box<AdminSubmissionDraftEntity>();
      final id = box.put(draft.toEntity());
      expect(box.get(id)!.toModel(), draft);
      final assets = env.store.box<AdminSubmissionStagedAssetEntity>();
      final descriptorId = assets.put(
        AdminSubmissionStagedAssetEntity(
          accountId: owner.accountId,
          sessionId: owner.sessionId,
          submissionId: null,
          digest: publicAsset.digest,
          relativePath:
              '${owner.accountId}/${owner.sessionId}/${publicAsset.digest}',
        ),
      );
      expect(assets.get(descriptorId)!.sessionId, owner.sessionId);
      expect(
        env.store.box<ContentSubmissionDraftEntity>().get(1)!.name,
        publicDraft.name,
      );
      expect(env.store.box<ContentSubmissionStagedAssetEntity>().count(), 1);
    },
  );
}
