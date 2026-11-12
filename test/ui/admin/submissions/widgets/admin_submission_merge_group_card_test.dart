import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_merge_group_card.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../../support/typography_harness.dart';

void main() {
  for (final scenario in [
    (
      group: 'name',
      label: 'Nome',
      values: <String, dynamic>{'name': 'Festa dei Misteri'},
      expected: 'Festa dei Misteri',
    ),
    (
      group: 'category',
      label: 'Categoria',
      values: <String, dynamic>{'category': 'history'},
      expected: 'Storia',
    ),
    (
      group: 'schedule',
      label: 'Date e orari',
      values: <String, dynamic>{
        'start_date': '2026-11-21T16:30:00.123456Z',
        'end_date': null,
        'all_day': false,
      },
      expected: 'Inizio: 21/11/2026 · 17:30 (ora italiana)\nFine: Non indicato',
    ),
    (
      group: 'location',
      label: 'Posizione',
      values: <String, dynamic>{
        'city': 'Campobasso',
        'latitude': 41.5619,
        'longitude': 14.6601,
      },
      expected: 'Comune: Campobasso\nLatitudine: 41,5619\nLongitudine: 14,6601',
    ),
  ]) {
    testWidgets(
      '${scenario.group} has readable complete values and exact data',
      (tester) async {
        var kept = 0;
        final group = AdminEventMergeGroup(
          name: scenario.group,
          providerChanged: true,
          moderatorChanged: true,
          apply: true,
          overwrite: true,
          base: scenario.values,
          source: scenario.values,
          moderated: scenario.values,
          current: scenario.values,
        );
        await tester.binding.setSurfaceSize(const Size(600, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          typographyHarness(
            child: Scaffold(
              body: SingleChildScrollView(
                child: AdminSubmissionMergeGroupCard(
                  group: group,
                  onKeepCurrent: () => kept++,
                ),
              ),
            ),
          ),
        );
        expect(find.text(scenario.label), findsOneWidget);
        expect(find.text('Da applicare'), findsOneWidget);
        expect(
          find.text('Sovrascrive modifiche del moderatore nell’evento attuale'),
          findsOneWidget,
        );
        final readable = find.text(scenario.expected);
        expect(readable, findsNWidgets(2));
        expect(
          find.ancestor(of: readable.first, matching: find.byType(SentryMask)),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: readable.last, matching: find.byType(SentryMask)),
          findsNothing,
        );
        expect(kept, 0);
        await tester.tap(find.text('Dati originali completi'));
        await tester.pumpAndSettle();
        final exact = find.text(
          const JsonEncoder.withIndent('  ').convert(scenario.values),
        );
        expect(exact, findsNWidgets(4));
        expect(
          find.ancestor(of: exact.first, matching: find.byType(SentryMask)),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: exact.at(1), matching: find.byType(SentryMask)),
          findsNothing,
        );
        for (final index in [2, 3]) {
          expect(
            find.ancestor(
              of: exact.at(index),
              matching: find.byType(SentryMask),
            ),
            findsOneWidget,
          );
        }
        await tester.ensureVisible(find.text('Base e fonte complete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Base e fonte complete'));
        await tester.pumpAndSettle();
        expect(find.text(scenario.expected), findsNWidgets(4));
        expect(kept, 0);
        await tester.ensureVisible(find.text('Mantieni valore attuale'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mantieni valore attuale'));
        await tester.pump();
        expect(kept, 1);
        expect(
          tester
              .widget<AdminSubmissionMergeGroupCard>(
                find.byType(AdminSubmissionMergeGroupCard),
              )
              .group,
          same(group),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('null, absent and empty values stay distinguishable', (
    tester,
  ) async {
    final group = AdminEventMergeGroup(
      name: 'name',
      providerChanged: false,
      moderatorChanged: false,
      apply: false,
      overwrite: false,
      moderated: const {'name': null},
      current: const {},
      base: const {'name': ''},
      source: const {'name': 'Nome originale'},
    );
    await tester.pumpWidget(
      typographyHarness(
        child: Scaffold(
          body: SingleChildScrollView(
            child: AdminSubmissionMergeGroupCard(group: group),
          ),
        ),
      ),
    );
    expect(find.text('Resta invariato'), findsOneWidget);
    expect(find.text('Non indicato'), findsOneWidget);
    expect(find.text('Non disponibile'), findsOneWidget);
    expect(find.textContaining('Sovrascrive modifiche'), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Mantieni valore attuale'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Base e fonte complete'));
    await tester.pumpAndSettle();
    expect(find.text('Vuoto'), findsOneWidget);
    expect(find.text('Nome originale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-day Rome dates retain calendar days and omit bound clocks', (
    tester,
  ) async {
    final group = AdminEventMergeGroup(
      name: 'schedule',
      providerChanged: true,
      moderatorChanged: false,
      apply: true,
      overwrite: false,
      moderated: const {
        'all_day': true,
        'start_date': '2026-03-28T23:00:00Z',
        'end_date': '2026-03-30T21:59:59.999999Z',
      },
      current: const {'all_day': false, 'start_date': 'not-a-date'},
      base: const {},
      source: const {},
    );
    await tester.pumpWidget(
      typographyHarness(
        child: Scaffold(
          body: SingleChildScrollView(
            child: AdminSubmissionMergeGroupCard(group: group),
          ),
        ),
      ),
    );
    expect(
      find.text('Tutto il giorno\nInizio: 29/03/2026\nFine: 30/03/2026'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Inizio: Data da verificare: not-a-date\nFine: Non disponibile',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rich descriptions wrap, stay read-only and replace by identity',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final longText =
          'Una descrizione completa con dettagli per le famiglie. ' * 25;
      final values = <String, dynamic>{
        'description': longText,
        'description_delta': [
          {
            'insert': longText,
            'attributes': {'bold': true},
          },
          {'insert': '\nIngresso libero'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
        ],
      };
      final group = AdminEventMergeGroup(
        name: 'description',
        providerChanged: true,
        moderatorChanged: true,
        apply: true,
        overwrite: true,
        moderated: values,
        current: const {
          'description': 'Descrizione pubblica attuale',
          'description_delta': [
            {'insert': 'Descrizione pubblica attuale\n'},
          ],
        },
        base: const {},
        source: const {},
      );
      for (final value in [
        group,
        AdminEventMergeGroup(
          name: 'description',
          providerChanged: true,
          moderatorChanged: false,
          apply: true,
          overwrite: false,
          moderated: const {'description': 'Nuova proposta'},
          current: const {'description': 'Nuovo evento attuale'},
          base: const {},
          source: const {},
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              FlutterQuillLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AdminSubmissionMergeGroupCard(group: value),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (identical(value, group)) {
          final editors = tester.widgetList<QuillEditor>(
            find.byType(QuillEditor),
          );
          expect(editors, hasLength(2));
          expect(find.text('Descrizione pubblica attuale'), findsNothing);
          expect(editors.every((editor) => editor.controller.readOnly), isTrue);
          expect(
            editors.first.controller.document.toPlainText(),
            '$longText\nIngresso libero\n',
          );
          expect(
            editors.first.controller.document.toDelta().toJson(),
            values['description_delta'],
          );
          expect(
            find.ancestor(
              of: find.byType(QuillEditor).first,
              matching: find.byType(SentryMask),
            ),
            findsOneWidget,
          );
          expect(
            find.ancestor(
              of: find.byType(QuillEditor).last,
              matching: find.byType(SentryMask),
            ),
            findsNothing,
          );
        } else {
          expect(find.byType(QuillEditor), findsNothing);
          expect(find.text('Nuova proposta'), findsOneWidget);
          expect(find.text('Nuovo evento attuale'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unsupported rich structure stays accessible with plain fallback',
    (tester) async {
      final values = <String, dynamic>{
        'description': 'Testo da verificare',
        'description_delta': [
          {
            'insert': {'image': 'https://example.com/private-image'},
          },
          {'insert': '\n'},
        ],
        'additional_field': 'Valore originale aggiuntivo',
      };
      final group = AdminEventMergeGroup(
        name: 'description',
        providerChanged: true,
        moderatorChanged: false,
        apply: true,
        overwrite: false,
        moderated: values,
        current: const {'description': 'Descrizione pubblica'},
        base: const {},
        source: const {},
      );
      await tester.pumpWidget(
        typographyHarness(
          child: Scaffold(
            body: SingleChildScrollView(
              child: AdminSubmissionMergeGroupCard(group: group),
            ),
          ),
        ),
      );
      expect(find.byType(QuillEditor), findsNothing);
      expect(find.text('Testo da verificare'), findsOneWidget);
      expect(
        find.text(
          'Formattazione non visualizzabile. '
          'Consulta i dati originali completi.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Dati originali completi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dati originali completi'));
      await tester.pumpAndSettle();
      final exact = find.text(
        const JsonEncoder.withIndent('  ').convert(values),
      );
      expect(exact, findsOneWidget);
      expect(
        find.ancestor(of: exact, matching: find.byType(SentryMask)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('disagreeing plain projection remains readable and selective', (
    tester,
  ) async {
    final group = AdminEventMergeGroup(
      name: 'description',
      providerChanged: true,
      moderatorChanged: true,
      apply: true,
      overwrite: true,
      moderated: const {
        'description': 'Proiezione semplice privata differente',
        'description_delta': [
          {
            'insert': 'Testo formattato privato',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ],
      },
      current: const {
        'description': 'Proiezione semplice pubblica differente',
        'description_delta': [
          {'insert': 'Testo formattato pubblico\n'},
        ],
      },
      base: const {},
      source: const {},
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminSubmissionMergeGroupCard(group: group),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuillEditor), findsNWidgets(2));
    expect(
      find.text(
        'Il testo semplice salvato è diverso dal contenuto formattato:',
      ),
      findsNWidgets(2),
    );
    final privatePlain = find.text('Proiezione semplice privata differente');
    final publicPlain = find.text('Proiezione semplice pubblica differente');
    expect(privatePlain, findsOneWidget);
    expect(publicPlain, findsOneWidget);
    expect(
      find.ancestor(of: privatePlain, matching: find.byType(SentryMask)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: publicPlain, matching: find.byType(SentryMask)),
      findsNothing,
    );
    final editors = tester.widgetList<QuillEditor>(find.byType(QuillEditor));
    expect(
      editors.first.controller.document.toDelta().toJson(),
      group.moderated['description_delta'],
    );
    expect(
      editors.last.controller.document.toDelta().toJson(),
      group.current['description_delta'],
    );
    expect(tester.takeException(), isNull);
  });
}
