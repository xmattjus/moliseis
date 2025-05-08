import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';

class AttractionCardTitleSubtitle extends StatelessWidget {
  /// Creates a Column composed of two [CustomRichText]s each with the
  /// appropriate styling to be used in an Attraction card.
  const AttractionCardTitleSubtitle(
    this.title,
    this.subtitle, {
    super.key,
    this.color,
  });

  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4.0,
      children: [
        CustomRichText(
          Text(title),
          labelTextStyle: CustomTextStyles.titleSmaller(
            context,
          )?.copyWith(color: color),
        ),
        CustomRichText(
          Text(subtitle),
          labelTextStyle: CustomTextStyles.subtitle(
            context,
          )?.copyWith(color: color),
          icon: const Icon(Icons.place_outlined),
        ),
      ],
    );
  }
}
