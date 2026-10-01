import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/data-sources/event_entity.dart';
import 'package:moliseis/data/dtos/event_dto.dart';
import 'package:moliseis/data/mappers/content_submission_wire_mapper.dart';
import 'package:moliseis/data/mappers/event_dto_mapper.dart';
import 'package:moliseis/data/mappers/event_entity_mapper.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';

import '../support/fake_image_picker.dart';
import '../support/fake_repositories.dart';
import '../support/mock_logger.dart';
import '../support/objectbox_test_store.dart';

void main() {
  testWidgets(
    'edited requests survive local publication, cache and Rome rendering',
    (tester) async {
      late TestObjectBoxEnvironment environment;
      final requests = <Map<String, dynamic>>[];
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final cases = [
        (
          allDay: true,
          date: EventCalendarDate(2026, 3, 29),
          end: null,
          clock: null,
        ),
        (
          allDay: true,
          date: EventCalendarDate(2026, 10, 24),
          end: EventCalendarDate(2026, 10, 25),
          clock: null,
        ),
        (
          allDay: false,
          date: EventCalendarDate(2026, 3, 29),
          end: null,
          clock: EventClockTime(18, 30),
        ),
      ];
      final rows = (await tester.runAsync(() async {
        await initializeDateFormatting('en');
        environment = await TestObjectBoxEnvironment.create();
        addTearDown(environment.dispose);
        for (final fixture in cases) {
          final repository = FakeContentSubmissionRepository();
          final vm = ContentSubmissionViewModel(
            logger: MockLogger(),
            contentSubmissionRepository: repository,
            draftRepository: FakeContentSubmissionDraftRepository(),
            stagedAssetRepository: FakeContentSubmissionStagedAssetRepository(),
            imagePicker: FakeImagePicker(),
          );
          addTearDown(vm.dispose);
          vm
            ..setCity('All-day E2E $nonce')
            ..setName('Event ${requests.length}')
            ..setUserName('Local E2E')
            ..setUserEmail('all-day-e2e-$nonce@example.test')
            ..setCategory(ContentCategory.history)
            ..setEventEnabled(true)
            ..setAllDay(allDay: fixture.allDay)
            ..setStartCalendarDate(fixture.date);
          if (fixture.clock != null) vm.setStartClockTime(fixture.clock!);
          if (fixture.end != null) vm.setEndCalendarDate(fixture.end!);
          await vm.submit.execute();
          expect(vm.submit.completed, isTrue);
          final captured = repository.submittedContentSubmissions.single;
          final request = contentSubmissionToWireMap(
            clientSubmissionId: repository.submittedClientSubmissionIds.single,
            contentSubmission: captured,
            submissionAssets: const [],
          );
          vm.setName('Later unsent edit');
          expect(request['name'], captured.name);
          requests.add(request);
        }

        final process = await Process.start('bash', [
          'supabase/tests/run_all_day_e2e_fixture.sh',
        ]);
        final stdout = process.stdout.transform(utf8.decoder).join();
        final stderr = process.stderr.transform(utf8.decoder).join();
        process.stdin.write(jsonEncode(requests));
        await process.stdin.close();
        final exitCode = await process.exitCode;
        final errors = await stderr;
        expect(exitCode, 0, reason: errors);
        return (jsonDecode(await stdout) as List).cast<Map<String, dynamic>>();
      }))!;
      expect(rows, hasLength(3));
      final starts = [
        DateTime.utc(2026, 3, 28, 23),
        DateTime.utc(2026, 10, 23, 22),
        DateTime.utc(2026, 3, 29, 16, 30),
      ];
      final labels = ['29 March', '24 - 25 October', '29 March'];
      final box = environment.store.box<EventEntity>();
      for (var index = 0; index < rows.length; index++) {
        final dto = EventDtoMapper.fromMap(rows[index]);
        expect(dto.allDay, cases[index].allDay);
        expect(dto.startDate.toUtc(), starts[index]);
        expect(
          dto.endDate?.toUtc(),
          index == 1 ? DateTime.utc(2026, 10, 25, 22, 59, 59, 999, 999) : null,
        );
        final entity = dto.toEntity();
        final id = box.put(entity);
        final event = box.get(id)!.toModel();
        expect(event.allDay, cases[index].allDay);
        expect(event.startDate.toUtc(), starts[index]);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            home: MediaQuery(
              data: const MediaQueryData(alwaysUse24HourFormat: true),
              child: Scaffold(body: EventFormattedDateTime(event: event)),
            ),
          ),
        );
        expect(find.text(labels[index]), findsOneWidget);
        expect(find.text('00:00'), findsNothing);
        expect(find.text('24 ore'), findsNothing);
        expect(find.text('Tutto il giorno'), findsNothing);
        expect(find.text('18:30'), index == 2 ? findsOneWidget : findsNothing);
      }
    },
    // Opt in against the running local Supabase verification stack.
    skip: Platform.environment['MOLISE_ALL_DAY_LOCAL_E2E'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
