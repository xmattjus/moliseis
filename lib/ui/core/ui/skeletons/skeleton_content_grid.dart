import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A skeleton loading widget that displays a grid of placeholder items.
///
/// This widget creates a shimmer effect using skeleton items arranged in a grid layout.
/// It supports both regular widget usage and sliver usage for integration with
/// CustomScrollView or other sliver-based widgets.
///
/// The grid uses a fixed 2-column layout with configurable item count and applies
/// a custom pulse effect for the loading animation.
///
/// Example usage:
/// ```dart
/// // Regular usage
/// CardSkeletonGrid(itemCount: 6)
///
/// // Sliver usage in CustomScrollView
/// CustomScrollView(
///   slivers: [
///     CardSkeletonGrid.sliver(itemCount: 8),
///   ],
/// )
/// ```
class SkeletonContentGrid extends StatelessWidget {
  /// Creates a regular CardSkeletonGrid widget.
  ///
  /// The [itemCount] parameter specifies the number of skeleton items to display.
  const SkeletonContentGrid({super.key, required this.itemCount})
    : _isSliver = false;

  /// Creates a CardSkeletonGrid as a sliver widget.
  ///
  /// This constructor creates a sliver version that can be used within
  /// CustomScrollView or other sliver-based widgets.
  ///
  /// The [itemCount] parameter specifies the number of skeleton items to display.
  const SkeletonContentGrid.sliver({super.key, required this.itemCount})
    : _isSliver = true;

  /// Whether this widget should be rendered as a sliver.
  ///
  /// When true, the widget returns a SliverSkeletonizer wrapped around
  /// a SliverGrid. When false, it returns a regular Skeletonizer with GridView.
  final bool _isSliver;

  /// The number of skeleton items to display in the grid.
  ///
  /// This determines how many [SkeletonContentGridItem] widgets will be
  /// rendered in the grid layout.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final skeletonEffect = CustomPulseEffect(context: context);
    const insets = EdgeInsets.symmetric(horizontal: 16.0);
    final childrenDelegate = SliverChildBuilderDelegate(
      (_, _) => const SkeletonContentGridItem(
        width: double.maxFinite,
        height: kGridViewCardHeight,
        elevation: 0,
      ),
      childCount: itemCount,
    );
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: context.gridViewColumnCount,
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
      mainAxisExtent: kGridViewCardHeight,
    );

    return _isSliver
        ? SliverSkeletonizer(
            effect: skeletonEffect,
            child: SliverPadding(
              padding: insets,
              sliver: SliverGrid(
                delegate: childrenDelegate,
                gridDelegate: gridDelegate,
              ),
            ),
          )
        : Skeletonizer(
            effect: skeletonEffect,
            child: Padding(
              padding: insets,
              child: GridView.custom(
                childrenDelegate: childrenDelegate,
                gridDelegate: gridDelegate,
              ),
            ),
          );
  }
}
