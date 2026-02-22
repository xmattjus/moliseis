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
  /// The minimum snap size all modals should have.
  final double modalMinSnapSize;

  /// The snap sizes, e.g. the screen percentages at which all modals should
  /// "snap" in place.
  final List<double> modalSnapSizes;

  final _BorderSideTokens borderSide;

  final double bottomSheetMaxWidth;

  final double searchBarMinWidth;

  final double searchBarMaxWidth;

  factory AppSizesThemeExtension() {
    return const AppSizesThemeExtension._(
      modalMinSnapSize: 0.20,
      modalSnapSizes: [0.20, 0.35, 0.50],
      borderSide: _BorderSideTokens(),
      bottomSheetMaxWidth: 720.0,
      searchBarMinWidth: 360.0,
      searchBarMaxWidth: 720.0,
    );
  }

  const AppSizesThemeExtension._({
    required this.modalMinSnapSize,
    required this.modalSnapSizes,
    required this.borderSide,
    required this.bottomSheetMaxWidth,
    required this.searchBarMinWidth,
    required this.searchBarMaxWidth,
  });

  @override
  ThemeExtension<AppSizesThemeExtension> copyWith({
    double? modalMinSnapSize,
    List<double>? modalSnapSizes,
    _BorderSideTokens? borderSide,
    double? bottomSheetMaxWidth,
    double? searchBarMinWidth,
    double? searchBarMaxWidth,
  }) {
    return AppSizesThemeExtension._(
      modalMinSnapSize: modalMinSnapSize ?? this.modalMinSnapSize,
      modalSnapSizes: modalSnapSizes ?? this.modalSnapSizes,
      borderSide: borderSide ?? this.borderSide,
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
      modalMinSnapSize: ui.lerpDouble(
        modalMinSnapSize,
        other.modalMinSnapSize,
        t,
      )!,
      modalSnapSizes: List<double>.generate(
        modalSnapSizes.length,
        (index) => ui.lerpDouble(
          modalSnapSizes[index],
          other.modalSnapSizes[index],
          t,
        )!,
      ),
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
