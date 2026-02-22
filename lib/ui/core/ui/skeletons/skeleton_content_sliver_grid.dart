import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/skeletons/app_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A skeleton loading widget that displays a grid of placeholder items.
///
/// This widget creates a shimmer effect using skeleton items arranged in a
/// grid layout.
///
/// Example usage:
/// ```dart
/// // Sliver usage in CustomScrollView
/// CustomScrollView(
///   slivers: [
///     SkeletonContentSliverGrid(),
///   ],
/// )
/// ```
class SkeletonContentSliverGrid extends StatelessWidget {
  const SkeletonContentSliverGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    final isCompact = context.windowSizeClass.isCompact;

    var itemWidth = kGridViewCardWidth;
    var itemHeight = kGridViewCardHeight;

    if (isCompact) {
      itemWidth = kListViewCardWidth;
      itemHeight = kListViewCardHeight;
    }

    final padding = isCompact
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 16.0);

    final childrenDelegate = SliverChildBuilderDelegate((_, _) {
      if (isCompact) {
        return Container(
          color: Colors.black,
          width: itemWidth,
          height: itemHeight,
        );
      }

      return SkeletonContentGridItem(
        width: itemWidth,
        height: itemHeight,
        elevation: 0,
      );
    });

    final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: itemWidth,
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
      mainAxisExtent: itemHeight,
    );

    return SliverSkeletonizer(
      effect: AppPulseEffect(
        from: colorScheme.surfaceContainerHigh,
        to: colorScheme.surfaceContainerLow,
      ),
      child: SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          delegate: childrenDelegate,
          gridDelegate: gridDelegate,
        ),
      ),
    );
  }
}
