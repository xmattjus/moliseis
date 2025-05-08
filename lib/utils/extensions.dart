import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/ui/core/themes/color.dart';

extension AttractionTypeExtensions on AttractionType {
  /// Returns the [AttractionType] icon.
  IconData getIcon({bool outlined = true}) {
    switch (this) {
      case AttractionType.unknown:
        return Icons.question_mark;
      case AttractionType.nature:
        return outlined ? Icons.forest_outlined : Icons.forest;
      case AttractionType.history:
        return outlined ? Icons.school_outlined : Icons.school;
      case AttractionType.folklore:
        return outlined ? Icons.groups_3_outlined : Icons.groups_3;
      case AttractionType.food:
        return outlined ? Icons.fastfood_outlined : Icons.fastfood;
      case AttractionType.allure:
        return outlined ? Icons.attractions_outlined : Icons.attractions;
      case AttractionType.experience:
        return outlined ? Icons.signpost_outlined : Icons.signpost;
    }
  }

  String get readableName {
    switch (this) {
      case AttractionType.unknown:
        return 'unknown';
      case AttractionType.nature:
        return 'Natura';
      case AttractionType.history:
        return 'Storia';
      case AttractionType.folklore:
        return 'Folklore';
      case AttractionType.food:
        return 'Cibo';
      case AttractionType.allure:
        return 'Attrazioni';
      case AttractionType.experience:
        return 'Esperienze';
    }
  }
}

extension BuildContextExtensions on BuildContext {
  /// Whether the [MediaQueryData.orientation] reported for the nearest
  /// [MediaQuery] ancestor equals [Orientation.landscape] or false, if no such
  /// ancestor exists.
  bool get isLandscape {
    final inherited = InheritedModel.inheritFrom<MediaQuery>(this)?.data;
    return inherited?.orientation == Orientation.landscape;
  }

  bool get isDarkTheme {
    return Theme.of(this).brightness == Brightness.dark;
  }
}

extension ButtonStyleExtensions on ButtonStyle {
  /// Returns a copy of the button style with some of its properties replaced
  /// by appropriate values based on the attraction [type].
  ButtonStyle byAttractionType(
    AttractionType type, {
    required Color primary,
    required Brightness brightness,
  }) {
    /// The list of the button's background colors to select from based on the
    /// attraction type.
    final surfaceContainerLowColors = [
      null,
      CustomColorSchemes.nature(primary, brightness).surfaceContainerLow,
      CustomColorSchemes.history(primary, brightness).surfaceContainerLow,
      CustomColorSchemes.folklore(primary, brightness).surfaceContainerLow,
      CustomColorSchemes.food(primary, brightness).surfaceContainerLow,
      CustomColorSchemes.allure(primary, brightness).surfaceContainerLow,
      CustomColorSchemes.experience(primary, brightness).surfaceContainerLow,
    ];

    /// The list of the button's foreground, overlay and icon colors to select
    /// from, based on the attraction type.
    final primaryColors = [
      null,
      CustomColorSchemes.nature(primary, brightness).primary,
      CustomColorSchemes.history(primary, brightness).primary,
      CustomColorSchemes.folklore(primary, brightness).primary,
      CustomColorSchemes.food(primary, brightness).primary,
      CustomColorSchemes.allure(primary, brightness).primary,
      CustomColorSchemes.experience(primary, brightness).primary,
    ];

    assert(surfaceContainerLowColors.length == AttractionType.values.length);
    assert(primaryColors.length == AttractionType.values.length);

    return copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        Color? bgColor;
        if (!states.contains(WidgetState.disabled)) {
          bgColor = surfaceContainerLowColors[type.index];
        }
        return bgColor ?? backgroundColor?.resolve(states);
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        Color? fgColor;
        if (!states.contains(WidgetState.disabled)) {
          fgColor = primaryColors[type.index];
        }
        return fgColor ?? foregroundColor?.resolve(states);
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        Color? color;
        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          color = primaryColors[type.index]?.withValues(alpha: 0.10);
        } else if (states.contains(WidgetState.hovered)) {
          color = primaryColors[type.index]?.withValues(alpha: 0.08);
        }

        return color ?? overlayColor?.resolve(states);
      }),
      iconColor: WidgetStateProperty.resolveWith<Color?>((states) {
        Color? color;
        if (!states.contains(WidgetState.disabled)) {
          color = primaryColors[type.index];
        }
        return color ?? iconColor?.resolve(states);
      }),
    );
  }
}

extension DateTimeExtensions on DateTime {
  String get intlMonth {
    final month = this.month;
    switch (month) {
      case 1:
        return 'Gennaio';
      case 2:
        return 'Febbraio';
      case 3:
        return 'Marzo';
      case 4:
        return 'Aprile';
      case 5:
        return 'Maggio';
      case 6:
        return 'Giugno';
      case 7:
        return 'Luglio';
      case 8:
        return 'Agosto';
      case 9:
        return 'Settembre';
      case 10:
        return 'Ottobre';
      case 11:
        return 'Novembre';
      case 12:
        return 'Dicembre';
      default:
        return 'intlMonth';
    }
  }
}

extension StringExtensions on String {
  bool get isValidUrl {
    final regExp = RegExp(
      r'(http|ftp|https):\/\/([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:\/~+#-]*[\w@?^=%&\/~+#-])',
      caseSensitive: false,
    );

    if (regExp.hasMatch(this)) {
      return true;
    }

    return false;
  }
}

extension TextExtensions on Text {
  /// Changes the Text textAlign property to [TextAlign.justify].
  Text get justify {
    return Text(
      data!,
      key: key,
      style: style,
      strutStyle: strutStyle,
      textAlign: TextAlign.justify,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      // ignore: deprecated_member_use
      textScaleFactor: textScaleFactor,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
