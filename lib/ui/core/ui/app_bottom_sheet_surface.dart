import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AppBottomSheetSurface extends StatelessWidget {
  const AppBottomSheetSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = context.appShapes.circular.cornerExtraLarge;
    return Material(
      color: context.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: borderRadius.topLeft,
          topRight: borderRadius.topRight,
        ),
        side: BorderSide(
          color: context.appColors.modalBorderColor,
          width: context.appSizes.borderSide.medium,
        ),
      ),
      elevation: 1,
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}
