import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CardSkeletonListItem extends StatelessWidget {
  const CardSkeletonListItem();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      effect: const PulseEffect(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          spacing: 16.0,
          children: [
            Bone.square(size: 72.0, borderRadius: BorderRadius.circular(12.0)),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8.0,
              children: [Bone.text(words: 3), Bone.text(words: 2)],
            ),
          ],
        ),
      ),
    );
  }
}
