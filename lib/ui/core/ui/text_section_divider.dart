import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';

class TextSectionDivider extends StatelessWidget {
  const TextSectionDivider(
    this.data, {
    super.key,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
  });

  final String data;
  final EdgeInsetsGeometry padding;

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
