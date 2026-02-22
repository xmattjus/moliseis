import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/app_navigation_bar.dart' as app_nav;
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AdaptiveNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final void Function(int)? onDestinationSelected;

  const AdaptiveNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) => switch (context.windowSizeClass) {
    WindowSizeClass.medium => app_nav.AppNavigationBar(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      fixedDestinationWidth: true,
      destinations: UnmodifiableListView<Widget>(
        destinations.map((destination) {
          final isSelected =
              destination.icon == destinations[selectedIndex].icon;
          return app_nav.NavigationDestination(
            icon: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4.0,
              children: [
                if (isSelected)
                  destination.selectedIcon ?? destination.icon
                else
                  destination.icon,
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
            label: '',
            indicatorWidth: 104.0,
            indicatorHeight: 40.0,
          );
        }),
      ),
      height: 64.0,
    ),
    _ => NavigationBar(
      destinations: destinations,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      height: 64.0,
    ),
  };
}
