import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/paragraph/paragraph.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';

class ParagraphContent extends StatelessWidget {
  const ParagraphContent({super.key, required this.paragraph});

  final Paragraph paragraph;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (paragraph.heading.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              paragraph.heading,
              style: CustomTextStyles.paragraphHeading(context),
            ),
          ),
        if (paragraph.subheading.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              paragraph.subheading,
              style: CustomTextStyles.paragraphSubheading(context),
            ),
          ),
        if (paragraph.body.isNotEmpty) Text(paragraph.body),
      ],
    );
  }
}
