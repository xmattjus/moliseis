import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/data/data-sources/city_entity.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/data/data-sources/place_entity.dart';
import 'package:moliseis/domain/core/sync_entity.dart';
import 'package:moliseis/domain/models/content_sort.dart';
import 'package:moliseis/domain/models/theme_brightness.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/generated/objectbox.g.dart';

import '../support/objectbox_test_store.dart';

void main() {
  test(
    'reopens genuine prior cursor-less settings and canonical cache',
    () async {
      final env = await TestObjectBoxEnvironment.create(
        previousStoreGzipPath:
            'test/fixtures/objectbox/pre_content_sync_cursor/data.mdb.gz',
      );
      addTearDown(env.dispose);
      final settingsBox = env.store.box<AppSettings>();
      final settings = settingsBox.get(AppSettings.singletonId)!;
      expect(settings.id, 1);
      expect(settings.type, ThemeType.app);
      expect(settings.brightness, ThemeBrightness.dark);
      expect(settings.contentSort, ContentSort.byDate);
      expect(settings.crashReporting, isFalse);
      expect(settings.lastSyncedAt?.toUtc(), DateTime.utc(2026, 10, 12, 8, 30));
      expect(settings.contentSyncCursorAt, isNull);

      final city = env.store.box<CityEntity>().get(101)!;
      final event = env.store.box<EventEntity>().get(102)!;
      final place = env.store.box<PlaceEntity>().get(103)!;
      final media = env.store.box<MediaEntity>().get(104)!;
      expect(city.name, 'Previous city');
      expect(event.name, 'Previous event');
      expect(event.isSaved, isTrue);
      expect(event.allDay, isTrue);
      expect(event.startDate?.toUtc(), DateTime.utc(2026, 10, 15));
      expect(event.descriptionDelta, [
        {'insert': 'Previous event description\n'},
      ]);
      expect(event.city.targetId, city.remoteId);
      expect(event.city.target?.name, city.name);
      expect(place.name, 'Previous place');
      expect(place.isSaved, isTrue);
      expect(place.city.targetId, city.remoteId);
      expect(media.title, 'Previous media');
      expect(media.event.targetId, event.remoteId);
      expect(media.event.target?.name, event.name);
      expect(media.url, 'https://cdn.example.com/img.jpg');
      expect(media.width, 800);
      expect(media.height, 600);
      for (final createdAt in [
        city.createdAt,
        event.createdAt,
        place.createdAt,
        media.createdAt,
      ]) {
        expect(createdAt.toUtc(), DateTime.utc(2026, 10, 1, 10));
      }
      for (final entity in <SyncEntity>[city, event, place, media]) {
        expect(entity.modifiedAt.toUtc(), DateTime.utc(2026, 10, 2, 11));
        expect(entity.isDeleted, isFalse);
      }

      final completion = DateTime.utc(2026, 10, 12, 12, 1, 2, 3, 4);
      final cursor = DateTime.utc(2026, 10, 12, 12, 0, 1, 2, 3);
      settingsBox.put(
        settings.copyWith(
          lastSyncedAt: completion,
          contentSyncCursorAt: cursor,
        ),
      );
      env.close();
      final reopened = await openStore(directory: env.directory.path);
      try {
        final persisted = reopened.box<AppSettings>().get(1)!;
        expect(persisted.lastSyncedAt?.toUtc(), completion);
        expect(persisted.contentSyncCursorAt?.toUtc(), cursor);
        expect(persisted.type, ThemeType.app);
        expect(persisted.brightness, ThemeBrightness.dark);
        expect(persisted.contentSort, ContentSort.byDate);
        expect(persisted.crashReporting, isFalse);
        expect(reopened.box<EventEntity>().get(102)!.isSaved, isTrue);
        expect(reopened.box<PlaceEntity>().get(103)!.isSaved, isTrue);
      } finally {
        reopened.close();
      }
    },
  );

  test('previous model UIDs survive later additive entities', () {
    final previous =
        jsonDecode(
              File(
                'test/fixtures/objectbox/pre_content_sync_cursor/objectbox-model.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final current =
        jsonDecode(
              File('lib/generated/objectbox-model.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final oldEntities = (previous['entities'] as List)
        .cast<Map<String, dynamic>>();
    final newEntities = (current['entities'] as List)
        .cast<Map<String, dynamic>>();
    // Later additive capabilities may introduce entities; this regression
    // protects the identities and properties of every pre-cursor entity.
    expect(newEntities.length, greaterThanOrEqualTo(oldEntities.length));
    for (final oldEntity in oldEntities) {
      final newEntity = newEntities.singleWhere(
        (value) => value['id'] == oldEntity['id'],
      );
      expect(newEntity['name'], oldEntity['name']);
      final oldProperties = (oldEntity['properties'] as List)
          .cast<Map<String, dynamic>>();
      final newProperties = (newEntity['properties'] as List)
          .cast<Map<String, dynamic>>();
      for (final property in oldProperties) {
        expect(
          newProperties.singleWhere((value) => value['id'] == property['id']),
          property,
        );
      }
      expect(
        newProperties.length,
        oldProperties.length + (oldEntity['name'] == 'AppSettings' ? 1 : 0),
      );
    }
    final settings = newEntities.singleWhere(
      (value) => value['name'] == 'AppSettings',
    );
    expect(settings['id'], '6:8898619296747710534');
    final cursor = (settings['properties'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((value) => value['name'] == 'contentSyncCursorAt');
    expect(cursor['type'], 12); // ObjectBox dateNano.
  });
}
