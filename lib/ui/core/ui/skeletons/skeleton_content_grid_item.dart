import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';

class SkeletonContentGridItem extends StatelessWidget {
  const SkeletonContentGridItem({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1.0,
      borderRadius: BorderRadius.circular(Shapes.medium),
      clipBehavior: Clip.hardEdge,
      child: Container(color: Colors.black, width: width, height: height),
    );
  }
}
