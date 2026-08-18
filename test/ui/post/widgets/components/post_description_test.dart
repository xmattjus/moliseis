import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/post/widgets/components/post_description.dart';
import 'package:provider/provider.dart';

import '../../../../support/fixtures.dart';

void main() {
  group('PostDescription', () {
    testWidgets('prefers a valid Delta over the Markdown fallback', (
      tester,
    ) async {
      await _pumpDescription(
        tester,
        makePlace(
          description: '**Markdown fallback**',
          descriptionDelta: <Map<String, dynamic>>[
            {'insert': 'Rich Delta description\n'},
          ],
        ),
      );

      expect(find.byType(QuillEditor), findsOneWidget);
      expect(_richTextContaining('Rich Delta description'), findsOneWidget);
      expect(find.text('Markdown fallback'), findsNothing);
    });

    testWidgets('uses Markdown for a legacy description without Delta', (
      tester,
    ) async {
      await _pumpDescription(
        tester,
        makePlace(description: '**Legacy Markdown**'),
      );

      expect(find.byType(QuillEditor), findsNothing);
      expect(find.text('Legacy Markdown'), findsOneWidget);
    });

    for (final testCase
        in <({String name, List<Map<String, dynamic>> descriptionDelta})>[
          (
            name: 'malformed',
            descriptionDelta: <Map<String, dynamic>>[
              {'retain': 1},
            ],
          ),
          (
            name: 'unsupported',
            descriptionDelta: <Map<String, dynamic>>[
              {
                'insert': 'Heading\n',
                'attributes': <String, dynamic>{'header': 1},
              },
            ],
          ),
          (
            name: 'unsafe-link',
            descriptionDelta: <Map<String, dynamic>>[
              {
                'insert': 'Unsafe link',
                'attributes': <String, dynamic>{
                  'link': 'javascript:alert(1)',
                },
              },
              {'insert': '\n'},
            ],
          ),
          (
            name: 'empty',
            descriptionDelta: <Map<String, dynamic>>[
              {'insert': '\n'},
            ],
          ),
        ]) {
      testWidgets('$testCase Delta uses the Markdown fallback', (tester) async {
        await _pumpDescription(
          tester,
          makePlace(
            description: '**Markdown fallback**',
            descriptionDelta: testCase.descriptionDelta,
          ),
        );

        expect(find.byType(QuillEditor), findsNothing);
        expect(find.text('Markdown fallback'), findsOneWidget);
      });
    }

    testWidgets('uses EmptyBox when neither representation is visible', (
      tester,
    ) async {
      await _pumpDescription(tester, makePlace());

      expect(find.byType(QuillEditor), findsNothing);
      expect(find.byType(EmptyBox, skipOffstage: false), findsOneWidget);
    });

    testWidgets(
      'configures a selectable read-only Quill editor without toolbar',
      (
        tester,
      ) async {
        await _pumpDescription(
          tester,
          makePlace(
            descriptionDelta: <Map<String, dynamic>>[
              {'insert': 'Read-only description\n'},
            ],
          ),
        );

        final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));

        expect(editor.controller.readOnly, isTrue);
        expect(editor.config.autoFocus, isFalse);
        expect(editor.config.enableInteractiveSelection, isTrue);
        expect(editor.config.enableSelectionToolbar, isTrue);
        expect(editor.config.scrollable, isFalse);
        expect(editor.config.showCursor, isFalse);
        expect(find.byType(QuillSimpleToolbar), findsNothing);
      },
    );

    testWidgets('launches only a safe link through UrlLaunchService', (
      tester,
    ) async {
      final urlLaunchService = _MockUrlLaunchService();
      when(
        () => urlLaunchService.launchGenericUrl('https://example.com'),
      ).thenAnswer((_) async => true);

      await _pumpDescription(
        tester,
        makePlace(
          descriptionDelta: <Map<String, dynamic>>[
            {
              'insert': 'Safe link',
              'attributes': <String, dynamic>{'link': 'https://example.com'},
            },
            {'insert': '\n'},
          ],
        ),
        urlLaunchService: urlLaunchService,
      );

      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      editor.config.onLaunchUrl!('https://example.com');
      editor.config.onLaunchUrl!('javascript:alert(1)');
      await tester.pump();

      verify(
        () => urlLaunchService.launchGenericUrl('https://example.com'),
      ).called(1);
      verifyNever(
        () => urlLaunchService.launchGenericUrl('javascript:alert(1)'),
      );
    });

    testWidgets('shows a generic error when a safe link cannot be launched', (
      tester,
    ) async {
      final urlLaunchService = _MockUrlLaunchService();
      when(
        () => urlLaunchService.launchGenericUrl('https://example.com'),
      ).thenAnswer((_) async => false);

      await _pumpDescription(
        tester,
        makePlace(
          descriptionDelta: <Map<String, dynamic>>[
            {
              'insert': 'Safe link',
              'attributes': <String, dynamic>{'link': 'https://example.com'},
            },
            {'insert': '\n'},
          ],
        ),
        urlLaunchService: urlLaunchService,
      );

      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      editor.config.onLaunchUrl!('https://example.com');
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsOneWidget,
      );
      verify(
        () => urlLaunchService.launchGenericUrl('https://example.com'),
      ).called(1);
    });

    testWidgets('does not show an error after disposal', (
      tester,
    ) async {
      final urlLaunchService = _MockUrlLaunchService();
      final launchCompleter = Completer<bool>();
      when(
        () => urlLaunchService.launchGenericUrl('https://example.com'),
      ).thenAnswer((_) => launchCompleter.future);

      await _pumpDescription(
        tester,
        makePlace(
          descriptionDelta: <Map<String, dynamic>>[
            {
              'insert': 'Safe link',
              'attributes': <String, dynamic>{'link': 'https://example.com'},
            },
            {'insert': '\n'},
          ],
        ),
        urlLaunchService: urlLaunchService,
      );

      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      editor.config.onLaunchUrl!('https://example.com');
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: $scaffoldMessengerKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      launchCompleter.complete(false);
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Si è verificato un errore, riprova più tardi'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('replaces the owned controller when rich content changes', (
      tester,
    ) async {
      await _pumpDescription(
        tester,
        makePlace(
          descriptionDelta: <Map<String, dynamic>>[
            {'insert': 'First description\n'},
          ],
        ),
      );
      final firstController = tester
          .widget<QuillEditor>(find.byType(QuillEditor))
          .controller;

      await _pumpDescription(
        tester,
        makePlace(
          descriptionDelta: <Map<String, dynamic>>[
            {'insert': 'Updated description\n'},
          ],
        ),
      );
      final updatedController = tester
          .widget<QuillEditor>(find.byType(QuillEditor))
          .controller;

      expect(updatedController, isNot(same(firstController)));
      expect(updatedController.document.toPlainText(), 'Updated description\n');
      expect(tester.takeException(), isNull);
    });

    testWidgets('resolves Quill localizations for English and Italian', (
      tester,
    ) async {
      for (final locale in <Locale>[const Locale('en'), const Locale('it')]) {
        await _pumpDescription(
          tester,
          makePlace(
            descriptionDelta: <Map<String, dynamic>>[
              {'insert': 'Localized description\n'},
            ],
          ),
          locale: locale,
        );

        final context = tester.element(find.byType(QuillEditor));
        expect(FlutterQuillLocalizations.of(context), isNotNull);
      }
    });
  });
}

Future<void> _pumpDescription(
  WidgetTester tester,
  ContentBase content, {
  Locale locale = const Locale('en'),
  UrlLaunchService? urlLaunchService,
}) async {
  final app = MaterialApp(
    scaffoldMessengerKey: $scaffoldMessengerKey,
    locale: locale,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      FlutterQuillLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const <Locale>[Locale('en'), Locale('it')],
    home: Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[PostDescription(content: content)],
      ),
    ),
  );

  await tester.pumpWidget(
    urlLaunchService == null
        ? app
        : Provider<UrlLaunchService>.value(
            value: urlLaunchService,
            child: app,
          ),
  );
  await tester.pump();
}

class _MockUrlLaunchService extends Mock implements UrlLaunchService {}

Finder _richTextContaining(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(text),
);
