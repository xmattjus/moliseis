import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';

class ContentNameAndCity extends StatelessWidget {
  /// Creates a vertical array composed of two [CustomRichText]s, one for [name]
  /// and one for [cityName].
  const ContentNameAndCity({
    super.key,
    required this.name,
    this.cityName,
    this.nameStyle,
    this.cityNameStyle,
    this.color,
    this.overflow,
  }) : assert(color == null || nameStyle == null && cityNameStyle == null);

  final String name;
  final String? cityName;
  final TextStyle? nameStyle;
  final TextStyle? cityNameStyle;
  final Color? color;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4.0,
      children: <Widget>[
        CustomRichText(
          Text(name),
          labelTextStyle:
              nameStyle ??
              AppTextStyles.titleSmaller(context)?.copyWith(color: color),
          overflow: overflow,
        ),
        CustomRichText(
          Text(cityName ?? 'Molise'),
          labelTextStyle:
              cityNameStyle ??
              AppTextStyles.subtitle(context)?.copyWith(color: color),
          icon: const Icon(Symbols.place),
          overflow: overflow,
        ),
      ],
    );
  }
}
