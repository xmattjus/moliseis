import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_description_form_field.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';

import 'support/sync_harness.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    for (final language in ['en', 'it']) {
      testWidgets('FLUTTER-7A: Quill selection menu works in $language '
          'on ${platform.name}', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.binding.platformDispatcher.localesTestValue = [Locale(language)];
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

        await tester.pumpWidget(buildRealSyncApp(SyncHarness()));
        await tester.pumpAndSettle();

        // Keep the production app's delegates and navigator overlay. Mount
        // the real description field without requiring the full draft flow.
        final context = tester.element(find.byType(ExploreScreen));
        Navigator.of(context, rootNavigator: true).push<void>(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => Scaffold(
              body: ContentSubmissionDescriptionFormField(
                initialDescription: 'Sample description',
                initialDescriptionDelta: null,
                onChanged:
                    ({required description, required descriptionDelta}) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
        editor.focusNode.requestFocus();
        editor.controller.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 6),
          ChangeSource.local,
        );
        await tester.pump();
        final state = tester.state<QuillRawEditorState>(
          find.byType(QuillRawEditor),
        );
        expect(state.showToolbar(), isTrue);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byType(flutter.AdaptiveTextSelectionToolbar),
          findsOneWidget,
        );
        expect(find.text(language == 'it' ? 'Copia' : 'Copy'), findsOneWidget);
        expect(find.text(language == 'it' ? 'Taglia' : 'Cut'), findsOneWidget);

        // The fork's Material labels must still use the selected locale.
        final editorContext = tester.element(find.byType(QuillEditor));
        expect(Localizations.localeOf(editorContext).languageCode, language);
        expect(
          MaterialLocalizations.of(editorContext).copyButtonLabel,
          language == 'it' ? 'Copia' : 'Copy',
        );
        state.hideToolbar();
        editor.focusNode.unfocus();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
