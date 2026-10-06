import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/text_theme.dart';
import 'package:moliseis/utils/extensions/build_context_extensions.dart';

import '../../../support/typography_harness.dart';

void main() {
  test('raw configuration owns only seven brand families and SOFT', () {
    final roles = typographyRoles(appTextTheme);
    for (var index = 0; index < roles.length; index++) {
      final style = roles[index];
      if (index >= 7) {
        expect(style, isNull);
        continue;
      }
      expect(style!.inherit, isTrue);
      expect(style.fontFamily, 'Fraunces');
      expect(style.fontVariations, const [FontVariation('SOFT', 50)]);
      expect(style.fontSize, isNull);
      expect(style.height, isNull);
      expect(style.fontWeight, isNull);
      expect(style.letterSpacing, isNull);
      expect(style.color, isNull);
    }
  });

  for (final photoViewer in [false, true]) {
    for (final brightness in Brightness.values) {
      for (final locale in [
        const Locale('en'),
        const Locale('it'),
        const Locale('ja'),
      ]) {
        testWidgets('resolved families, geometry and emphasis '
            '$photoViewer $brightness $locale', (tester) async {
          await tester.pumpWidget(
            typographyHarness(
              photoViewer: photoViewer,
              brightness: brightness,
              locale: locale,
              child: Builder(
                builder: (context) {
                  final theme = context.theme;
                  final baseline = typographyRoles(context.textTheme);
                  final emphasized = typographyRoles(
                    context.appTypography.emphasized,
                  );
                  final geometry = typographyRoles(
                    theme.typography.geometryThemeFor(
                      MaterialLocalizations.of(context).scriptCategory,
                    ),
                  );
                  for (var index = 0; index < baseline.length; index++) {
                    final style = baseline[index]!;
                    expect(style.fontFamily, index < 7 ? 'Fraunces' : 'Lexend');
                    expect(
                      style.fontVariations,
                      index < 7 ? const [FontVariation('SOFT', 50)] : isNull,
                    );
                    expect(style.fontSize, geometry[index]!.fontSize);
                    expect(style.height, geometry[index]!.height);
                    expect(style.fontWeight, geometry[index]!.fontWeight);
                    expect(style.letterSpacing, geometry[index]!.letterSpacing);
                    expect(
                      style.textBaseline,
                      locale.languageCode == 'ja'
                          ? TextBaseline.ideographic
                          : TextBaseline.alphabetic,
                    );
                    final weight = [7, 8, 12, 13, 14].contains(index)
                        ? FontWeight.w700
                        : FontWeight.w500;
                    expect(
                      emphasized[index],
                      style.copyWith(
                        fontWeight: weight,
                        letterSpacing: index == 0
                            ? 0
                            : index == 9
                            ? 0.15
                            : null,
                      ),
                    );
                  }
                  final color = theme.colorScheme.secondary.withValues(
                    alpha: 0.7,
                  );
                  expect(
                    context.appTypography.section,
                    theme.textTheme.titleMedium!.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  );
                  expect(
                    context.appTypography.link,
                    theme.textTheme.bodySmall!.copyWith(
                      color: color,
                      decoration: TextDecoration.underline,
                      decorationColor: color,
                    ),
                  );
                  return const SizedBox();
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
        });
      }
    }
  }

  testWidgets(
    'custom properties survive and theme updates recompute public styles',
    (tester) async {
      const custom = TextStyle(
        fontFamilyFallback: ['serif'],
        locale: Locale('it'),
        decoration: TextDecoration.overline,
        decorationColor: Colors.green,
        fontFeatures: [FontFeature.tabularFigures()],
        fontVariations: [FontVariation('SOFT', 30)],
        wordSpacing: 2,
        leadingDistribution: TextLeadingDistribution.even,
      );
      TextStyle? previousSection;
      TextStyle? previousEmphasis;
      for (final brightness in Brightness.values) {
        TextStyle? currentSection;
        TextStyle? currentEmphasis;
        await tester.pumpWidget(
          typographyHarness(
            brightness: brightness,
            overrides: const TextTheme(headlineLarge: custom),
            child: Builder(
              builder: (context) {
                final style = context.textTheme.headlineLarge!;
                final emphasis = context.appTypography.emphasized.headlineLarge;
                expect(emphasis, style.copyWith(fontWeight: FontWeight.w500));
                expect(emphasis!.fontFamilyFallback, custom.fontFamilyFallback);
                expect(emphasis.locale, custom.locale);
                expect(emphasis.decoration, custom.decoration);
                expect(emphasis.fontFeatures, custom.fontFeatures);
                expect(emphasis.fontVariations, custom.fontVariations);
                final section = context.appTypography.section;
                currentSection = section;
                currentEmphasis = emphasis;
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (previousSection != null) {
          expect(currentSection!.color, isNot(previousSection.color));
          expect(currentEmphasis!.color, isNot(previousEmphasis!.color));
        }
        previousSection = currentSection;
        previousEmphasis = currentEmphasis;
      }
    },
  );
}
