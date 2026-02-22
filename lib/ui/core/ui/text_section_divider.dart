import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';

class TextSectionDivider extends StatelessWidget {
  final String data;
  final EdgeInsetsGeometry padding;

  const TextSectionDivider(
    this.data, {
    super.key,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        data,
        style: AppTextStyles.section(context),
        overflow: TextOverflow.visible,
      ),
    );
  }
}
