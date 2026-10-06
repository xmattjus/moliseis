import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_header.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/mock_logger.dart';
import '../../../../support/weather_harness.dart';

void main() {
  testWidgets('post heading uses emphasis and city retains plain title', (
    tester,
  ) async {
    final weather = buildWeatherViewModel(MockLogger());
    addTearDown(weather.dispose);
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppThemeData.light(context: context),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                PostSectionHeader(
                  content: makePlace(
                    name: 'Castello',
                    city: testCity(name: 'Termoli'),
                  ),
                  weatherViewModel: weather,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final nameContext = tester.element(find.text('Castello'));
    final name = DefaultTextStyle.of(nameContext).style;
    expect(name.fontFamily, 'Fraunces');
    expect(name.fontWeight, FontWeight.w500);
    expect(name.fontVariations, const [FontVariation('SOFT', 50)]);
    expect(
      name.fontSize,
      Theme.of(nameContext).textTheme.headlineLarge!.fontSize,
    );
    final cityContext = tester.element(find.text('Termoli'));
    expect(
      DefaultTextStyle.of(cityContext).style,
      Theme.of(cityContext).textTheme.titleMedium,
    );
    expect(DefaultTextStyle.of(cityContext).style.fontFamily, 'Lexend');
  });
}
