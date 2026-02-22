import 'package:flutter/material.dart';

class _BorderRadiusTokens {
  final BorderRadius cornerNone;
  final BorderRadius cornerExtraSmall;
  final BorderRadius cornerSmall;
  final BorderRadius cornerMedium;
  final BorderRadius cornerLarge;
  final BorderRadius cornerLargeIncreased;
  final BorderRadius cornerExtraLarge;
  final BorderRadius cornerExtraLargeIncreased;
  final BorderRadius cornerExtraExtraLarge;
  final BorderRadius cornerFull;

  const _BorderRadiusTokens({
    required this.cornerNone,
    required this.cornerExtraSmall,
    required this.cornerSmall,
    required this.cornerMedium,
    required this.cornerLarge,
    required this.cornerLargeIncreased,
    required this.cornerExtraLarge,
    required this.cornerExtraLargeIncreased,
    required this.cornerExtraExtraLarge,
    required this.cornerFull,
  });
}

class AppShapesThemeExtension extends ThemeExtension<AppShapesThemeExtension> {
  final _BorderRadiusTokens circular;

  /// Creates a [AppShapesThemeExtension] with the Material 3 Expressive shape tokens.
  factory AppShapesThemeExtension() {
    return const AppShapesThemeExtension._(
      circular: _BorderRadiusTokens(
        cornerNone: BorderRadius.zero,
        cornerExtraSmall: BorderRadius.all(Radius.circular(4)),
        cornerSmall: BorderRadius.all(Radius.circular(8)),
        cornerMedium: BorderRadius.all(Radius.circular(12)),
        cornerLarge: BorderRadius.all(Radius.circular(16)),
        cornerLargeIncreased: BorderRadius.all(Radius.circular(20)),
        cornerExtraLarge: BorderRadius.all(Radius.circular(28)),
        cornerExtraLargeIncreased: BorderRadius.all(Radius.circular(32)),
        cornerExtraExtraLarge: BorderRadius.all(Radius.circular(48)),
        cornerFull: BorderRadius.all(Radius.circular(1000)),
      ),
    );
  }

  const AppShapesThemeExtension._({required this.circular});

  @override
  ThemeExtension<AppShapesThemeExtension> copyWith({
    BorderRadius? cornerNone,
    BorderRadius? cornerExtraSmall,
    BorderRadius? cornerSmall,
    BorderRadius? cornerMedium,
    BorderRadius? cornerLarge,
    BorderRadius? cornerLargeIncreased,
    BorderRadius? cornerExtraLarge,
    BorderRadius? cornerExtraLargeIncreased,
    BorderRadius? cornerExtraExtraLarge,
    BorderRadius? cornerFull,
    _BorderRadiusTokens? circular,
  }) {
    return AppShapesThemeExtension._(circular: circular ?? this.circular);
  }

  @override
  ThemeExtension<AppShapesThemeExtension> lerp(
    covariant ThemeExtension<AppShapesThemeExtension>? other,
    double t,
  ) {
    if (other is! AppShapesThemeExtension) {
      return this;
    }
    return AppShapesThemeExtension._(
      circular: _BorderRadiusTokens(
        cornerNone: BorderRadius.lerp(
          circular.cornerNone.resolve(TextDirection.ltr),
          other.circular.cornerNone.resolve(TextDirection.ltr),
          t,
        )!,
        cornerExtraSmall: BorderRadius.lerp(
          circular.cornerExtraSmall.resolve(TextDirection.ltr),
          other.circular.cornerExtraSmall.resolve(TextDirection.ltr),
          t,
        )!,
        cornerSmall: BorderRadius.lerp(
          circular.cornerSmall.resolve(TextDirection.ltr),
          other.circular.cornerSmall.resolve(TextDirection.ltr),
          t,
        )!,
        cornerMedium: BorderRadius.lerp(
          circular.cornerMedium.resolve(TextDirection.ltr),
          other.circular.cornerMedium.resolve(TextDirection.ltr),
          t,
        )!,
        cornerLarge: BorderRadius.lerp(
          circular.cornerLarge.resolve(TextDirection.ltr),
          other.circular.cornerLarge.resolve(TextDirection.ltr),
          t,
        )!,
        cornerLargeIncreased: BorderRadius.lerp(
          circular.cornerLargeIncreased.resolve(TextDirection.ltr),
          other.circular.cornerLargeIncreased.resolve(TextDirection.ltr),
          t,
        )!,
        cornerExtraLarge: BorderRadius.lerp(
          circular.cornerExtraLarge.resolve(TextDirection.ltr),
          other.circular.cornerExtraLarge.resolve(TextDirection.ltr),
          t,
        )!,
        cornerExtraLargeIncreased: BorderRadius.lerp(
          circular.cornerExtraLargeIncreased.resolve(TextDirection.ltr),
          other.circular.cornerExtraLargeIncreased.resolve(TextDirection.ltr),
          t,
        )!,
        cornerExtraExtraLarge: BorderRadius.lerp(
          circular.cornerExtraExtraLarge.resolve(TextDirection.ltr),
          other.circular.cornerExtraExtraLarge.resolve(TextDirection.ltr),
          t,
        )!,
        cornerFull: BorderRadius.lerp(
          circular.cornerFull.resolve(TextDirection.ltr),
          other.circular.cornerFull.resolve(TextDirection.ltr),
          t,
        )!,
      ),
    );
  }
}
