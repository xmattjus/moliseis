import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';

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
