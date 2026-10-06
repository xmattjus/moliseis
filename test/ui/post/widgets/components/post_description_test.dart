import 'dart:async';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/post/widgets/components/post_description.dart';
import 'package:provider/provider.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/typography_assertions.dart';

void main() {
  group('PostDescription', () {
    testWidgets(
      'rich inline attributes preserve axes and paragraph/list styling',
      (tester) async {
        const base = TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 16,
          fontVariations: [FontVariation('SOFT', 50)],
        );
        await _pumpDescription(
          tester,
          makePlace(
            descriptionDelta: [
              {
                'insert': 'Formatted',
                'attributes': {
                  'bold': true,
                  'italic': true,
                  'underline': true,
                  'link': 'https://example.com',
                },
              },
              {'insert': '\nListed'},
              {
                'insert': '\n',
                'attributes': {'list': 'bullet'},
              },
            ],
          ),
          theme: ThemeData(textTheme: const TextTheme(bodyLarge: base)),
        );
        final rich = tester.widget<RichText>(_richTextContaining('Formatted'));
        final style = effectiveSpanStyle(rich.text, 'Formatted')!;
        expect(style.fontWeight, FontWeight.bold);
        expect(style.fontStyle, FontStyle.italic);
        expect(style.decoration, TextDecoration.underline);
        expect(
          style.color,
          Theme.of(
            tester.element(_richTextContaining('Formatted')),
          ).colorScheme.secondary,
        );
        expect(style.fontVariations, base.fontVariations);
        final listed = tester.widget<RichText>(_richTextContaining('Listed'));
        expect(
          effectiveSpanStyle(listed.text, 'Listed')!.fontVariations,
          base.fontVariations,
        );
        final styles = tester
            .widget<QuillEditor>(find.byType(QuillEditor))
            .config
            .customStyles!;
        expect(styles.paragraph!.verticalSpacing, VerticalSpacing.zero);
        expect(styles.paragraph!.lineSpacing, VerticalSpacing.zero);
        expect(styles.lists!.verticalSpacing, VerticalSpacing.zero);
      },
    );

    testWidgets('legacy Markdown retains heading and link metrics', (
      tester,
    ) async {
      await _pumpDescription(
        tester,
        makePlace(
          description:
              '# H1\n\n## H2\n\n### H3\n\n#### H4\n\n##### H5\n\n###### H6\n\n[Link](https://example.com)',
        ),
      );
      final expected = [
        (48.0, 1.0),
        (36.0, 1.0),
        (24.0, 1.0),
        (16.0, 1.25),
        (14.0, 1.0),
        (13.0, 1.0),
      ];
      for (var i = 0; i < expected.length; i++) {
        final span = tester
            .widget<RichText>(_richTextContaining('H${i + 1}'))
            .text;
        final style = effectiveSpanStyle(span, 'H${i + 1}')!;
        expect(style.fontSize, expected[i].$1);
        expect(style.height, expected[i].$2);
      }
      final style = effectiveSpanStyle(
        tester.widget<RichText>(_richTextContaining('Link')).text,
        'Link',
      )!;
      expect(style.fontSize, 14);
      expect(style.height, 1);
      expect(style.decoration, TextDecoration.underline);
    });

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
                'attributes': <String, dynamic>{'link': 'javascript:alert(1)'},
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
      (tester) async {
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

    testWidgets('does not show an error after disposal', (tester) async {
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
  ThemeData? theme,
}) async {
  final app = MaterialApp(
    scaffoldMessengerKey: $scaffoldMessengerKey,
    theme: theme,
    locale: locale,
    localizationsDelegates: const [
      FlutterQuillLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
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
        : Provider<UrlLaunchService>.value(value: urlLaunchService, child: app),
  );
  await tester.pump();
}

class _MockUrlLaunchService extends Mock implements UrlLaunchService {}

Finder _richTextContaining(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(text),
);
