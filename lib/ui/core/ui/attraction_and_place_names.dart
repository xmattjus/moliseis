import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';

class AttractionAndPlaceNames extends StatelessWidget {
  /// Creates a vertical array composed of two [CustomRichText]s, one for [name]
  /// and one for [placeName].
  const AttractionAndPlaceNames({
    super.key,
    required this.name,
    required this.placeName,
    this.nameStyle,
    this.placeNameStyle,
    this.color,
    this.overflow,
  }) : assert(color == null || nameStyle == null && placeNameStyle == null);

  final String name;
  final String placeName;
  final TextStyle? nameStyle;
  final TextStyle? placeNameStyle;
  final Color? color;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4.0,
      children: [
        CustomRichText(
          Text(name),
          labelTextStyle:
              nameStyle ??
              CustomTextStyles.titleSmaller(context)?.copyWith(color: color),
          overflow: overflow,
        ),
        CustomRichText(
          Text(placeName),
          labelTextStyle:
              placeNameStyle ??
              CustomTextStyles.subtitle(context)?.copyWith(color: color),
          icon: const Icon(Icons.place_outlined),
          overflow: overflow,
        ),
      ],
    );
  }
}
