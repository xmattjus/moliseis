import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AppBottomSheetDragHandle extends StatelessWidget {
  const AppBottomSheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kMinInteractiveDimension,
      height: kMinInteractiveDimension,
      child: Center(
        child: Container(
          width: 32.0,
          height: 4.0,
          decoration: BoxDecoration(
            color: context.colorScheme.onSurfaceVariant.withAlpha(51),
            borderRadius: context.appShapes.circular.cornerSmall,
          ),
        ),
      ),
    );
  }
}
