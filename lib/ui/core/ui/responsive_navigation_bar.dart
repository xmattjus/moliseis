import 'dart:collection' show UnmodifiableListView;

import 'package:expressive_navigation_bar/expressive_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';
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
    // TODO(xmattjus): Remove the bridge when
    //  expressive_navigation_bar migrates to package:material_ui.
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      child: ExpressiveNavigationBar(
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
      ),
    );
  }
}
