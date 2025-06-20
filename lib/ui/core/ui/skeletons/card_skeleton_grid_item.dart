import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CardSkeletonGridItem extends StatelessWidget {
  const CardSkeletonGridItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      effect: CustomPulseEffect(context: context),
      child: const Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(8.0),
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
