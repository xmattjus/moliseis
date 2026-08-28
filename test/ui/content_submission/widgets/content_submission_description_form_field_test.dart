import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_description_form_field.dart';
import 'package:moliseis/ui/core/utils/quill_document_codec.dart';

void main() {
  Widget buildApp({
    String? initialDescription,
    List<Map<String, dynamic>>? initialDescriptionDelta,
    void Function({
      required String? description,
      required List<Map<String, dynamic>>? descriptionDelta,
    })?
    onChanged,
    Locale locale = const Locale('en'),
    ThemeData? theme,
  }) {
    return _buildShell(
      locale: locale,
      theme: theme,
      child: Form(
        child: ContentSubmissionDescriptionFormField(
          initialDescription: initialDescription,
          initialDescriptionDelta: initialDescriptionDelta,
          onChanged:
              onChanged ??
              ({required description, required descriptionDelta}) {},
        ),
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  QuillController controllerOf(WidgetTester tester) {
    return tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;
  }

  group('ContentSubmissionDescriptionFormField', () {
    testWidgets('initializes from a valid Delta', (tester) async {
      final delta = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': 'Testo ricco',
          'attributes': <String, dynamic>{'bold': true},
        },
        <String, dynamic>{'insert': '\n'},
      ];

      await pumpApp(tester, buildApp(initialDescriptionDelta: delta));

      final controller = controllerOf(tester);
      expect(controller.document.toPlainText(), 'Testo ricco\n');
      expect(controller.document.toDelta().toJson(), delta);
    });

    testWidgets('falls back to legacy plain text for absent or invalid Delta', (
      tester,
    ) async {
      await pumpApp(
        tester,
        buildApp(initialDescription: 'Descrizione precedente'),
      );

      expect(
        controllerOf(tester).document.toPlainText(),
        'Descrizione precedente\n',
      );

      await pumpApp(
        tester,
        buildApp(
          initialDescription: 'Fallback valido',
          initialDescriptionDelta: <Map<String, dynamic>>[
            <String, dynamic>{'insert': 42},
          ],
        ),
      );

      expect(controllerOf(tester).document.toPlainText(), 'Fallback valido\n');
    });

    testWidgets('edits emit matching plain-text and Delta projections', (
      tester,
    ) async {
      ({String? description, List<Map<String, dynamic>>? descriptionDelta})?
      emitted;

      await pumpApp(
        tester,
        buildApp(
          onChanged: ({required description, required descriptionDelta}) {
            emitted = (
              description: description,
              descriptionDelta: descriptionDelta,
            );
          },
        ),
      );

      controllerOf(tester).replaceText(
        0,
        0,
        'Nuovo testo',
        const TextSelection.collapsed(offset: 11),
      );
      await tester.pump();

      expect(emitted?.description, 'Nuovo testo');
      expect(
        QuillDocumentCodec.documentFromDelta(
          emitted?.descriptionDelta,
        )?.toPlainText(),
        'Nuovo testo\n',
      );
    });

    testWidgets('selection-only changes do not emit a document update', (
      tester,
    ) async {
      var emissionCount = 0;
      await pumpApp(
        tester,
        buildApp(
          initialDescription: 'Testo',
          onChanged: ({required description, required descriptionDelta}) {
            emissionCount++;
          },
        ),
      );

      controllerOf(tester).updateSelection(
        const TextSelection.collapsed(offset: 2),
        ChangeSource.local,
      );
      await tester.pump();

      expect(emissionCount, 0);
    });

    testWidgets('toolbar formatting emits a document update', (tester) async {
      var emissionCount = 0;
      await pumpApp(
        tester,
        buildApp(
          initialDescription: 'Testo',
          onChanged: ({required description, required descriptionDelta}) {
            emissionCount++;
          },
        ),
      );

      final controller = controllerOf(tester)
        ..updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 5),
          ChangeSource.local,
        );
      await tester.pump();
      expect(emissionCount, 0);

      await tester.tap(find.byTooltip('Bold'));
      await tester.pump();

      expect(emissionCount, 1);
      expect(
        controller.document.toDelta().toJson().first['attributes'],
        <String, dynamic>{'bold': true},
      );
    });

    testWidgets('clearing the editor emits null projections', (tester) async {
      ({String? description, List<Map<String, dynamic>>? descriptionDelta})?
      emitted;
      await pumpApp(
        tester,
        buildApp(
          initialDescription: 'Da cancellare',
          onChanged: ({required description, required descriptionDelta}) {
            emitted = (
              description: description,
              descriptionDelta: descriptionDelta,
            );
          },
        ),
      );

      controllerOf(tester).clear();
      await tester.pump();

      expect(emitted, (description: null, descriptionDelta: null));
    });

    testWidgets(
      'preserves an unbroken 5,000-character description and validates it',
      (tester) async {
        final description = 'a' * 5000;
        ({String? description, List<Map<String, dynamic>>? descriptionDelta})?
        emitted;

        await pumpApp(
          tester,
          buildApp(
            onChanged: ({required description, required descriptionDelta}) {
              emitted = (
                description: description,
                descriptionDelta: descriptionDelta,
              );
            },
          ),
        );

        controllerOf(tester).replaceText(
          0,
          0,
          description,
          const TextSelection.collapsed(offset: 5000),
        );
        await tester.pump();

        expect(controllerOf(tester).document.toPlainText(), '$description\n');
        expect(emitted?.description, description);
        expect(
          QuillDocumentCodec.documentFromDelta(
            emitted?.descriptionDelta,
          )?.toPlainText(),
          '$description\n',
        );

        final form = tester.state<FormState>(find.byType(Form));
        expect(form.validate(), isTrue);
        await tester.pump();
        expect(
          find.text('La descrizione inserita è troppo lunga'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('rejects but preserves a 5,001-character description', (
      tester,
    ) async {
      final description = 'a' * 5001;
      ({String? description, List<Map<String, dynamic>>? descriptionDelta})?
      emitted;

      await pumpApp(
        tester,
        buildApp(
          onChanged: ({required description, required descriptionDelta}) {
            emitted = (
              description: description,
              descriptionDelta: descriptionDelta,
            );
          },
        ),
      );

      controllerOf(tester).replaceText(
        0,
        0,
        description,
        const TextSelection.collapsed(offset: 5001),
      );
      await tester.pump();

      expect(controllerOf(tester).document.toPlainText(), '$description\n');
      expect(emitted?.description, description);
      expect(
        QuillDocumentCodec.documentFromDelta(
          emitted?.descriptionDelta,
        )?.toPlainText(),
        '$description\n',
      );

      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(
        find.text('La descrizione inserita è troppo lunga'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('external resets replace the editor without feedback', (
      tester,
    ) async {
      var emissions = 0;
      String? description = 'a' * 5001;
      List<Map<String, dynamic>>? descriptionDelta;
      late StateSetter setHostState;

      await pumpApp(
        tester,
        _buildShell(
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return Form(
                child: ContentSubmissionDescriptionFormField(
                  initialDescription: description,
                  initialDescriptionDelta: descriptionDelta,
                  onChanged:
                      ({
                        required description,
                        required descriptionDelta,
                      }) {
                        emissions++;
                      },
                ),
              );
            },
          ),
        ),
      );
      final initialController = controllerOf(tester);
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(
        find.text('La descrizione inserita è troppo lunga'),
        findsOneWidget,
      );

      setHostState(() {
        description = null;
        descriptionDelta = null;
      });
      await tester.pumpAndSettle();

      final resetController = controllerOf(tester);
      expect(identical(resetController, initialController), isFalse);
      expect(resetController.document.toPlainText(), '\n');
      expect(emissions, 0);
      expect(form.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(
        find.text('La descrizione inserita è troppo lunga'),
        findsNothing,
      );
    });

    testWidgets('parent reflection preserves the editor controller', (
      tester,
    ) async {
      String? currentDescription;
      List<Map<String, dynamic>>? currentDescriptionDelta;
      late StateSetter setHostState;

      await pumpApp(
        tester,
        _buildShell(
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return Form(
                child: ContentSubmissionDescriptionFormField(
                  initialDescription: currentDescription,
                  initialDescriptionDelta: currentDescriptionDelta,
                  onChanged:
                      ({
                        required description,
                        required descriptionDelta,
                      }) {
                        setHostState(() {
                          currentDescription = description;
                          currentDescriptionDelta = descriptionDelta;
                        });
                      },
                ),
              );
            },
          ),
        ),
      );
      final controller = controllerOf(tester)
        ..replaceText(
          0,
          0,
          'Testo',
          const TextSelection.collapsed(offset: 5),
        );
      await tester.pump();

      expect(identical(controllerOf(tester), controller), isTrue);
      expect(controller.selection.extentOffset, 5);
    });

    testWidgets('exposes multiline description field semantics', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await pumpApp(tester, buildApp());

        final descriptionField = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Descrizione',
        );
        final semantics = tester.getSemantics(descriptionField);

        expect(semantics.flagsCollection.isTextField, isTrue);
        expect(semantics.flagsCollection.isMultiline, isTrue);
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('disposes Quill resources without pending exceptions', (
      tester,
    ) async {
      await pumpApp(tester, buildApp());
      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
    });
  });
}

Widget _buildShell({
  required Widget child,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    theme: theme,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      FlutterQuillLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('it')],
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}
