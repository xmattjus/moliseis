import 'dart:collection' show UnmodifiableListView;

import 'package:expressive_navigation_bar/expressive_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ResponsiveNavigationBar extends StatelessWidget {
  const ResponsiveNavigationBar({
    required this.selectedIndex,
    required this.destinations,
    this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final void Function(int)? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final showHorizontalLabel = context.windowSizeClass.isMedium;
    return ExpressiveNavigationBar(
      destinations: UnmodifiableListView<Widget>(
        destinations.map(
          (destination) => ExpressiveNavigationDestination(
            icon: destination.icon,
            selectedIcon: destination.selectedIcon,
            label: destination.label,
            horizontalLabel: showHorizontalLabel,
          ),
        ),
      ),
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      height: 64,
      fixedDestinationWidth: showHorizontalLabel,
    );
  }
}
