import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A skeleton loading widget that mimics the layout of [InformationCard].
///
/// This widget displays animated skeleton placeholders while the actual
/// information card content is being loaded. It maintains the same visual
/// structure as the real card to provide a smooth loading experience.
///
/// The skeleton includes:
/// - A placeholder text at the top (header section)
/// - An icon placeholder and multi-line text placeholder in the middle
/// - A single line text placeholder at the bottom (footer section)
///
/// The widget uses the app's secondary container color scheme and applies
/// a custom pulse animation effect for visual feedback during loading states.
///
/// Example usage:
/// ```dart
/// // Display while loading information card data
/// isLoading
///   ? InformationCardSkeleton()
///   : InformationCard(...)
/// ```
class InformationCardSkeleton extends StatelessWidget {
  /// Creates a skeleton placeholder for information card content.
  const InformationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondaryContainer;
    return Skeletonizer(
      effect: CustomPulseEffect(context: context, customColor: color),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Shapes.medium),
        ),
        constraints: const BoxConstraints.expand(),
        padding: const EdgeInsets.all(8.0),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Loading...'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4.0,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: 4.0,
                  children: <Widget>[
                    Padding(padding: EdgeInsets.all(4.0), child: Bone.icon()),
                    Expanded(child: Bone.multiText()),
                  ],
                ),
                Bone.text(fontSize: 12.0, words: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
