import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Provides a familiar visual affordance for draggable bottom sheets.
///
/// This helps users quickly understand that the sheet can be swiped,
/// improving discoverability without adding extra interaction hints.
class AppBottomSheetDragHandle extends StatelessWidget {
  const AppBottomSheetDragHandle({super.key, this.color});

  final Color? color;

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
            color: color ?? context.colorScheme.onSurfaceVariant.withAlpha(51),
            borderRadius: context.appShapes.circular.cornerSmall,
          ),
        ),
      ),
    );
  }
}
