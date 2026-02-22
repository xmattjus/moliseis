import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class SkeletonContentGridItem extends StatelessWidget {
  const SkeletonContentGridItem({
    super.key,
    required this.width,
    required this.height,
    this.elevation,
  });

  final double width;
  final double height;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation ?? 1.0,
      borderRadius: context.appShapes.circular.cornerMedium,
      clipBehavior: Clip.hardEdge,
      child: Container(color: Colors.black, width: width, height: height),
    );
  }
}
