import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';

class BottomSheetDragHandle extends StatelessWidget {
  const BottomSheetDragHandle();

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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            borderRadius: BorderRadius.circular(Shapes.small),
          ),
        ),
      ),
    );
  }
}
