import 'package:flutter/material.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CardSkeletonGridItem extends StatelessWidget {
  const CardSkeletonGridItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      effect: const PulseEffect(),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardCornerRadius),
        ),
        margin: EdgeInsets.zero,
        child: const Column(
          spacing: 8.0,
          children: [
            Expanded(child: Bone.square(uniRadius: kCardCornerRadius)),
            Padding(padding: EdgeInsets.all(8.0), child: Bone.text(words: 3)),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: 8.0,
                end: 8.0,
                bottom: 8.0,
              ),
              child: Bone.text(words: 2),
            ),
          ],
        ),
      ),
    );
  }
}
