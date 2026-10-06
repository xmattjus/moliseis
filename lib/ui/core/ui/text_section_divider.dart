import 'package:material_ui/material_ui.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class TextSectionDivider extends StatelessWidget {
  const TextSectionDivider(
    this.data, {
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
    super.key,
  });

  final String data;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        data,
        style: context.appTypography.section,
        overflow: TextOverflow.visible,
      ),
    );
  }
}
