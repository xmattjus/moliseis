import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';

class BottomSheetAdaptiveTitle extends StatelessWidget {
  const BottomSheetAdaptiveTitle(this.data, {super.key, this.padding});

  final String data;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;

    return Align(
      alignment: isIOS ? Alignment.center : Alignment.topLeft,
      child: Padding(
        padding:
            padding ??
            EdgeInsetsDirectional.fromSTEB(
              isIOS ? 72.0 : 16.0,
              0,
              isIOS ? 72.0 : 16.0,
              16.0,
            ),
        child: Text(
          data,
          style: CustomTextStyles.title(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
