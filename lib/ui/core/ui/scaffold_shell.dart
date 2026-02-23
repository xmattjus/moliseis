// Stateful nested navigation based on:
// https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/ui/core/ui/app_navigation_rail.dart';
import 'package:moliseis/ui/core/ui/responsive_navigation_bar.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class ScaffoldShell extends StatelessWidget {
  const ScaffoldShell({
    Key? key,
    required StatefulNavigationShell navigationShell,
  }) : _navigationShell = navigationShell,
       super(key: key ?? const ValueKey('ScaffoldShell'));

  final StatefulNavigationShell _navigationShell;

  @override
  Widget build(BuildContext context) {
    final windowSizeClass = context.windowSizeClass;
    return AnnotatedRegion(
      value: SystemUiOverlayStyles(context).scaffoldShell,
      child: Scaffold(
        body: Row(
          children: <Widget>[
            if (windowSizeClass.isAtLeast(WindowSizeClass.expanded))
              AppNavigationRail(
                selectedIndex: _navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: _buildDestinations,
              ),
            Expanded(child: _navigationShell),
          ],
        ),
        bottomNavigationBar: windowSizeClass.isAtMost(WindowSizeClass.medium)
            ? ResponsiveNavigationBar(
                selectedIndex: _navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: _buildDestinations,
              )
            : null,
        resizeToAvoidBottomInset: false,
        extendBody: true,
      ),
    );
  }

  List<NavigationDestination> get _buildDestinations => const [
    NavigationDestination(
      icon: Icon(Symbols.home),
      selectedIcon: Icon(Symbols.home, fill: 1.0),
      label: 'Esplora',
    ),
    NavigationDestination(
      icon: Icon(Symbols.favorite_rounded),
      selectedIcon: Icon(Symbols.favorite_rounded, fill: 1.0),
      label: 'Preferiti',
    ),
    NavigationDestination(
      icon: Icon(Symbols.event),
      selectedIcon: Icon(Symbols.event, fill: 1.0),
      label: 'Eventi',
    ),
    NavigationDestination(
      icon: Icon(Symbols.map),
      selectedIcon: Icon(Symbols.map, fill: 1.0),
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
