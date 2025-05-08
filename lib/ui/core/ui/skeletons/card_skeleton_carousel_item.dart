import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CardSkeletonCarouselItem extends StatelessWidget {
  const CardSkeletonCarouselItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      effect: const PulseEffect(),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26.0),
        ),
        margin: EdgeInsets.zero,
        child: const Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsetsDirectional.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8.0,
              children: [Bone.text(words: 3), Bone.text(words: 2)],
            ),
          ),
        ),
      ),
    );
  }
}
