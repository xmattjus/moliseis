import 'package:flutter/material.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions.dart';

/// A responsive grid widget for displaying information cards in a structured layout.
///
/// This widget provides two variants for different use cases:
/// - Standard grid view for regular scrollable content
/// - Sliver grid for integration with CustomScrollView and other sliver widgets
///
/// The grid automatically adapts its column count based on the screen size using
/// [context.gridViewColumnCount] extension and maintains consistent spacing and
/// card heights across all grid items.
///
/// Features:
/// - Responsive column count based on screen size
/// - Fixed card height using [kInformationCardHeight] constant
/// - Consistent spacing between grid items (8.0 logical pixels)
/// - Support for both regular and sliver implementations
///
/// Example usage:
/// ```dart
/// // Regular grid view
/// InformationGrid(
///   children: [
///     InformationCard(...),
///     InformationCard(...),
///   ],
/// )
///
/// // Sliver variant for CustomScrollView
/// InformationGrid.sliver(
///   children: [
///     InformationCard(...),
///     InformationCard(...),
///   ],
/// )
/// ```
class InformationGrid extends StatelessWidget {
  /// List of widgets to display in the grid layout.
  /// Typically contains [InformationCard] widgets or similar components.
  final List<Widget> children;

  /// Creates a standard grid view for displaying information cards.
  ///
  /// The [children] parameter is required and should contain the widgets
  /// to be displayed in the grid layout.
  const InformationGrid({super.key, required this.children})
    : _isSliver = false;

  /// Creates a sliver grid view for use within CustomScrollView.
  ///
  /// This constructor is useful when the grid needs to be integrated
  /// with other sliver widgets in a scrollable layout.
  const InformationGrid.sliver({super.key, required this.children})
    : _isSliver = true;

  /// Internal flag to determine whether to render as a sliver or regular grid.
  /// Set to true for sliver implementation, false for standard GridView.
  final bool _isSliver;

  @override
  Widget build(BuildContext context) {
    final itemCount = children.length;
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
      mainAxisExtent: kInformationCardHeight,
      crossAxisCount: context.gridViewColumnCount,
    );

    return _isSliver
        ? SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              return children[index];
            }, childCount: itemCount),
            gridDelegate: gridDelegate,
          )
        : GridView.builder(
            gridDelegate: gridDelegate,
            itemCount: itemCount,
            itemBuilder: (_, index) {
              return children[index];
            },
          );
  }
}
