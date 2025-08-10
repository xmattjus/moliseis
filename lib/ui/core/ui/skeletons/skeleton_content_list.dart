import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A skeleton loading widget that displays a vertical list of placeholder items.
///
/// This widget creates a shimmer effect using skeleton items arranged in a vertical list layout.
/// It supports both regular widget usage and sliver usage for integration with
/// CustomScrollView or other sliver-based widgets.
///
/// Each list item is a rectangular placeholder with a fixed height of 88.0 pixels,
/// separated by dividers. The widget applies a custom pulse effect for the loading animation.
///
/// Example usage:
/// ```dart
/// // Regular usage
/// SkeletonContentList(itemCount: 5)
///
/// // Sliver usage in CustomScrollView
/// CustomScrollView(
///   slivers: [
///     SkeletonContentList.sliver(itemCount: 10),
///   ],
/// )
/// ```
class SkeletonContentList extends StatelessWidget {
  /// Creates a regular SkeletonContentList widget.
  ///
  /// The [itemCount] parameter specifies the number of skeleton items to display.
  const SkeletonContentList({super.key, required this.itemCount})
    : _isSliver = false;

  /// Creates a SkeletonContentList as a sliver widget.
  ///
  /// This constructor creates a sliver version that can be used within
  /// CustomScrollView or other sliver-based widgets.
  ///
  /// The [itemCount] parameter specifies the number of skeleton items to display.
  const SkeletonContentList.sliver({super.key, required this.itemCount})
    : _isSliver = true;

  /// Whether this widget should be rendered as a sliver.
  ///
  /// When true, the widget returns a SliverSkeletonizer wrapped around
  /// a SliverList. When false, it returns a regular Skeletonizer with Column.
  final bool _isSliver;

  /// The number of skeleton items to display in the list.
  ///
  /// This determines how many rectangular placeholder items will be
  /// rendered in the vertical list layout, separated by dividers.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final item = Container(
      color: Colors.black,
      width: double.maxFinite,
      height: 88.0,
    );

    const separator = Divider();

    if (_isSliver) {
      return SliverSkeletonizer(
        effect: CustomPulseEffect(context: context),
        child: SliverList.separated(
          itemBuilder: (_, _) => item,
          separatorBuilder: (_, _) => separator,
          itemCount: itemCount,
        ),
      );
    } else {
      final length = math.max(0, itemCount * 2 - 1);
      return Skeletonizer(
        effect: CustomPulseEffect(context: context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(length, (index) {
            if (index.isEven) {
              return item;
            } else {
              return separator;
            }
          }),
        ),
      );
    }
  }
}
