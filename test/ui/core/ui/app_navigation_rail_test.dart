import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/ui/app_navigation_rail.dart';

void main() {
  testWidgets('rail labels preserve role and selected hierarchy', (
    tester,
  ) async {
    var selected = 0;
    late StateSetter update;
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppThemeData.light(context: context),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return AppNavigationRail(
                  selectedIndex: selected,
                  onDestinationSelected: (value) =>
                      update(() => selected = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.event),
                      label: 'Events',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    for (var index = 0; index < 2; index++) {
      final label = tester.widget<Text>(
        find.text(index == 0 ? 'Home' : 'Events'),
      );
      final baseline = Theme.of(
        tester.element(find.text(label.data!)),
      ).textTheme.labelMedium!;
      expect(
        label.style,
        baseline.copyWith(
          fontWeight: index == selected ? FontWeight.w700 : FontWeight.normal,
        ),
      );
      expect(label.style!.fontFamily, 'Lexend');
    }
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(
      tester.widget<Text>(find.text('Events')).style!.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.widget<Text>(find.text('Home')).style!.fontWeight,
      FontWeight.normal,
    );
  });
}
