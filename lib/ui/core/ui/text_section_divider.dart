import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';

class TextSectionDivider extends StatelessWidget {
  /// Creates a text widget.
  const TextSectionDivider(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: CustomTextStyles.section(context),
      overflow: TextOverflow.visible,
    );
  }
}
