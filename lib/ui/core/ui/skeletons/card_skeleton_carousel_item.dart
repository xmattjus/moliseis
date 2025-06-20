import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CardSkeletonCarouselItem extends StatelessWidget {
  const CardSkeletonCarouselItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      effect: CustomPulseEffect(context: context),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Shape.extraLarge),
        ),
        margin: EdgeInsets.zero,
        child: const Padding(
          padding: EdgeInsetsDirectional.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8.0,
            children: [Bone.text(words: 3), Bone.text(words: 2)],
          ),
        ),
      ),
    );
  }
}
