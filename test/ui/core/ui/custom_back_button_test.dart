import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';

void main() {
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets('uses the $platform Back glyph and native localization', (
      tester,
    ) async {
      final italian = platform != TargetPlatform.android;
      var backs = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: platform,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          locale: Locale(italian ? 'it' : 'en'),
          supportedLocales: const [Locale('en'), Locale('it')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            appBar: AppBar(leading: CustomBackButton(onPressed: () => backs++)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final glyph = platform == TargetPlatform.android
          ? Icons.arrow_back
          : Icons.arrow_back_ios_new_rounded;
      final tooltip = italian ? 'Indietro' : 'Back';
      expect(find.byIcon(glyph), findsOneWidget);
      expect(glyph.matchTextDirection, isTrue);
      expect(find.byTooltip(tooltip), findsOneWidget);
      final node = tester.getSemantics(find.byType(BackButton));
      expect(node.getSemanticsData().tooltip, tooltip);
      expect(
        node.rect.size,
        Size.square(platform == TargetPlatform.macOS ? 40 : 48),
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      expect(backs, 1);
    });
  }

  for (final width in [56.0, 44.0]) {
    testWidgets('mobile AppBar Back hit and semantic bounds in a $width slot', (
      tester,
    ) async {
      const background = Colors.purple;
      var backs = 0;
      var adjacent = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.android,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: Scaffold(
            appBar: AppBar(
              leadingWidth: width,
              leading: CustomBackButton(
                backgroundColor: background,
                onPressed: () => backs++,
              ),
              title: TextButton(
                onPressed: () => adjacent++,
                child: const Text('Adjacent'),
              ),
            ),
          ),
        ),
      );
      final back = find.byType(BackButton);
      final target = tester.getRect(back);
      expect(target.size, Size(width < 48 ? width : 48, 48));
      expect(tester.getSemantics(back).rect.size, target.size);
      final face = find.descendant(
        of: back,
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == background,
        ),
      );
      expect(tester.getSize(face), const Size(40, 40));
      expect(tester.getCenter(face), target.center);
      for (final point in [
        target.topLeft + const Offset(1, 1),
        target.topRight + const Offset(-1, 1),
        target.bottomLeft + const Offset(1, -1),
        target.bottomRight - const Offset(1, 1),
      ]) {
        await tester.tapAt(point);
      }
      expect(backs, 4);
      expect(adjacent, 0);
      await tester.tap(find.text('Adjacent'));
      expect(adjacent, 1);
      expect(backs, 4);
    });
  }

  testWidgets('RTL SearchBar honors action-icon theme and explicit padding', (
    tester,
  ) async {
    const padding = EdgeInsetsDirectional.only(start: 2, end: 6);
    const customIcon = ValueKey('custom back icon');
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: TargetPlatform.iOS,
          actionIconTheme: ActionIconThemeData(
            backButtonIconBuilder: (context) => Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_right
                  : Icons.chevron_left,
              key: customIcon,
            ),
          ),
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SearchBar(
                leading: CustomBackButton(
                  padding: padding,
                  backgroundColor: Colors.transparent,
                  onPressed: () => activations++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final wrapper = find.byType(CustomBackButton);
    final button = find.byType(BackButton);
    expect(find.byKey(customIcon), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    final box = tester.getRect(wrapper);
    final target = tester.getRect(button);
    expect(target.left - box.left, 6);
    expect(box.right - target.right, 2);
    expect(target.size, const Size.square(48));
    await tester.tapAt(target.centerLeft + const Offset(1, 0));
    expect(activations, 1);
  });
}
