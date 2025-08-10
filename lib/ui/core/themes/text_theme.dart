import 'package:flutter/material.dart';

/// Source: https://github.com/rydmike/flex_color_scheme/discussions/160#discussioncomment-5999257
const TextTheme appTextTheme = TextTheme(
  titleLarge: TextStyle(
    fontFamily: 'Fraunces',
    fontVariations: [
      FontVariation.weight(400),
      // FontVariation('WONK', 0), // Not supported by Flutter?
      FontVariation('SOFT', 50),
    ],
  ),
  titleMedium: TextStyle(
    fontFamily: 'Lexend',
    fontVariations: [FontVariation.weight(500)],
  ),
  titleSmall: TextStyle(
    fontFamily: 'Fraunces',
    fontVariations: [FontVariation.weight(500)],
  ),
  bodyLarge: TextStyle(
    fontFamily: 'Lexend',
    fontVariations: [FontVariation.weight(400)],
  ),
  bodyMedium: TextStyle(
    fontFamily: 'Lexend',
    fontVariations: [FontVariation.weight(400)],
  ),
  bodySmall: TextStyle(
    fontFamily: 'Lexend',
    fontVariations: [FontVariation.weight(400)],
  ),
  labelLarge: TextStyle(
    fontFamily: 'Lexend',
    fontVariations: [FontVariation.weight(500)],
  ),
  labelMedium: TextStyle(
    fontFamily: 'Lexend',
    fontVariations: [FontVariation.weight(500)],
  ),
  labelSmall: TextStyle(
    fontFamily: 'Lexend',
    fontVariations: [FontVariation.weight(500)],
  ),
);
