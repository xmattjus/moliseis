import 'package:material_ui/material_ui.dart';

const _brandStyle = TextStyle(
  fontFamily: 'Fraunces',
  fontVariations: [FontVariation('SOFT', 50)],
);

/// Partial brand configuration; Flutter supplies localized Material geometry.
const TextTheme appTextTheme = TextTheme(
  displayLarge: _brandStyle,
  displayMedium: _brandStyle,
  displaySmall: _brandStyle,
  headlineLarge: _brandStyle,
  headlineMedium: _brandStyle,
  headlineSmall: _brandStyle,
  titleLarge: _brandStyle,
);
