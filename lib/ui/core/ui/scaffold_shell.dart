// Stateful nested navigation based on:
// https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart

import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/ui/core/ui/app_navigation_rail.dart';
import 'package:moliseis/ui/core/ui/responsive_navigation_bar.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ScaffoldShell extends StatelessWidget {
  const ScaffoldShell({
    required StatefulNavigationShell navigationShell,
    required this.showNavigation,
    Key? key,
  }) : _navigationShell = navigationShell,
       super(key: key ?? const ValueKey('ScaffoldShell'));

  final StatefulNavigationShell _navigationShell;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) {
    final windowSizeClass = context.windowSizeClass;
    final destinations = _buildDestinations;
    return ShellRouteVisibility(
      isCurrent: ModalRoute.isCurrentOf(context) ?? true,
      activeBranchIndex: _navigationShell.currentIndex,
      child: AnnotatedRegion(
        value: SystemUiOverlayStyles(context).scaffoldShell,
        child: Scaffold(
          body: Row(
            children: <Widget>[
              if (showNavigation &&
                  windowSizeClass.isAtLeast(WindowSizeClass.expanded))
                AppNavigationRail(
                  selectedIndex: _navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: destinations,
                ),
              Expanded(child: _navigationShell),
            ],
          ),
          bottomNavigationBar:
              showNavigation && windowSizeClass.isAtMost(WindowSizeClass.medium)
              ? ResponsiveNavigationBar(
                  selectedIndex: _navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: destinations,
                )
              : null,
          resizeToAvoidBottomInset: false,
          extendBody: true,
        ),
      ),
    );
  }

  List<NavigationDestination> get _buildDestinations => const [
    NavigationDestination(
      icon: Icon(Symbols.home),
      selectedIcon: Icon(Symbols.home, fill: 1),
      label: 'Esplora',
    ),
    NavigationDestination(
      icon: Icon(Symbols.favorite_rounded),
      selectedIcon: Icon(Symbols.favorite_rounded, fill: 1),
      label: 'Preferiti',
    ),
    NavigationDestination(
      icon: Icon(Symbols.event),
      selectedIcon: Icon(Symbols.event, fill: 1),
      label: 'Eventi',
    ),
    NavigationDestination(
      icon: Icon(Symbols.map),
      selectedIcon: Icon(Symbols.map, fill: 1),
      label: 'Mappa',
    ),
  ];

  void _onDestinationSelected(int index) {
    _navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active. This example demonstrates how to support this behavior,
      // using the initialLocation parameter of goBranch.
      initialLocation: index == _navigationShell.currentIndex,
    );
  }
}

/// Whether the root shell page is the current route on its Navigator.
///
/// Branch details remain current on their own Navigators while another branch
/// is active or a root page covers the shell. Descendants use this to keep
/// hidden details out of predictive-back gestures.
class ShellRouteVisibility extends InheritedWidget {
  const ShellRouteVisibility({
    required this.isCurrent,
    required this.activeBranchIndex,
    required super.child,
    super.key,
  });

  final bool isCurrent;
  final int activeBranchIndex;

  static bool canPopBranchDetail(BuildContext context, int branchIndex) {
    final visibility = context
        .dependOnInheritedWidgetOfExactType<ShellRouteVisibility>();
    return visibility == null ||
        (visibility.isCurrent && visibility.activeBranchIndex == branchIndex);
  }

  @override
  bool updateShouldNotify(ShellRouteVisibility oldWidget) =>
      isCurrent != oldWidget.isCurrent ||
      activeBranchIndex != oldWidget.activeBranchIndex;
}

/// Prevents inactive or covered branch pages from handling predictive back.
class BranchDetailPopScope extends StatelessWidget {
  const BranchDetailPopScope({
    required this.branchIndex,
    required this.child,
    super.key,
  });

  final int branchIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: ShellRouteVisibility.canPopBranchDetail(context, branchIndex),
    child: child,
  );
}
