import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/material.dart';

class _BorderSideTokens {
  /// Defaults to `0`.
  final double none;

  /// Defaults to `0.6`.
  final double small;

  /// Defaults to `1.2`.
  final double medium;

  /// Defaults to `2.0`.
  final double large;

  /// Defaults to `2.6`.
  final double extraLarge;

  const _BorderSideTokens({
    this.none = 0,
    this.small = 0.6,
    this.medium = 1.2,
    this.large = 2.0,
    this.extraLarge = 2.6,
  });
}

class AppSizesThemeExtension extends ThemeExtension<AppSizesThemeExtension> {
  final _BorderSideTokens borderSide;

  /// The minimum snap size all bottom sheets should have.
  final double bottomSheetMinSnapSize;

  /// The initial snap size all bottom sheets should have.
  final double bottomSheetInitialSnapSize;

  /// The snap sizes, e.g. the screen percentages, at which all bottom sheets
  /// should "snap" in place.
  final List<double> bottomSheetSnapSizes;

  final double bottomSheetMaxWidth;

  final double searchBarMinWidth;

  final double searchBarMaxWidth;

  factory AppSizesThemeExtension() {
    return const AppSizesThemeExtension._(
      borderSide: _BorderSideTokens(),
      bottomSheetMinSnapSize: 0.20,
      bottomSheetInitialSnapSize: 0.35,
      bottomSheetSnapSizes: [0.20, 0.35, 0.50],
      bottomSheetMaxWidth: 720.0,
      searchBarMinWidth: 360.0,
      searchBarMaxWidth: 720.0,
    );
  }

  const AppSizesThemeExtension._({
    required this.borderSide,
    required this.bottomSheetMinSnapSize,
    required this.bottomSheetInitialSnapSize,
    required this.bottomSheetSnapSizes,
    required this.bottomSheetMaxWidth,
    required this.searchBarMinWidth,
    required this.searchBarMaxWidth,
  });

  @override
  ThemeExtension<AppSizesThemeExtension> copyWith({
    _BorderSideTokens? borderSide,
    double? bottomSheetMinSnapSize,
    double? bottomSheetInitialSnapSize,
    List<double>? bottomSheetSnapSizes,
    double? bottomSheetMaxWidth,
    double? searchBarMinWidth,
    double? searchBarMaxWidth,
  }) {
    return AppSizesThemeExtension._(
      borderSide: borderSide ?? this.borderSide,
      bottomSheetMinSnapSize:
          bottomSheetMinSnapSize ?? this.bottomSheetMinSnapSize,
      bottomSheetInitialSnapSize:
          bottomSheetInitialSnapSize ?? this.bottomSheetInitialSnapSize,
      bottomSheetSnapSizes: bottomSheetSnapSizes ?? this.bottomSheetSnapSizes,
      bottomSheetMaxWidth: bottomSheetMaxWidth ?? this.bottomSheetMaxWidth,
      searchBarMinWidth: searchBarMinWidth ?? this.searchBarMinWidth,
      searchBarMaxWidth: searchBarMaxWidth ?? this.searchBarMaxWidth,
    );
  }

  @override
  AppSizesThemeExtension lerp(
    ThemeExtension<AppSizesThemeExtension>? other,
    double t,
  ) {
    if (other is! AppSizesThemeExtension) {
      return this;
    }
    return AppSizesThemeExtension._(
      borderSide: _BorderSideTokens(
        none: ui.lerpDouble(borderSide.none, other.borderSide.none, t)!,
        small: ui.lerpDouble(borderSide.small, other.borderSide.small, t)!,
        medium: ui.lerpDouble(borderSide.medium, other.borderSide.medium, t)!,
        large: ui.lerpDouble(borderSide.large, other.borderSide.large, t)!,
        extraLarge: ui.lerpDouble(
          borderSide.extraLarge,
          other.borderSide.extraLarge,
          t,
        )!,
      ),
      bottomSheetMinSnapSize: ui.lerpDouble(
        bottomSheetMinSnapSize,
        other.bottomSheetMinSnapSize,
        t,
      )!,
      bottomSheetInitialSnapSize: ui.lerpDouble(
        bottomSheetInitialSnapSize,
        other.bottomSheetInitialSnapSize,
        t,
      )!,
      bottomSheetSnapSizes: List<double>.generate(
        bottomSheetSnapSizes.length,
        (index) => ui.lerpDouble(
          bottomSheetSnapSizes[index],
          other.bottomSheetSnapSizes[index],
          t,
        )!,
      ),
      bottomSheetMaxWidth: ui.lerpDouble(
        bottomSheetMaxWidth,
        other.bottomSheetMaxWidth,
        t,
      )!,
      searchBarMinWidth: ui.lerpDouble(
        searchBarMinWidth,
        other.searchBarMinWidth,
        t,
      )!,
      searchBarMaxWidth: ui.lerpDouble(
        searchBarMaxWidth,
        other.searchBarMaxWidth,
        t,
      )!,
    );
  }
}
