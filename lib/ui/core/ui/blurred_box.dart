import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class BlurredBox extends StatelessWidget {
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Widget child;

  const BlurredBox({
    super.key,
    this.backgroundColor,
    this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        this.borderRadius ?? context.appShapes.circular.cornerSmall;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: context.appEffects.modalBlurEffect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                backgroundColor ?? context.appColors.blurredBoxBackgroundColor,
            border: BoxBorder.all(
              color: context.appColors.modalBorderColor,
              width: context.appSizes.borderSide.medium,
            ),
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
