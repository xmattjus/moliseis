// Stateful nested navigation based on:
// https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart

import 'package:flutter/material.dart' hide kBottomNavigationBarHeight;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/utils/constants.dart';

class ScaffoldShell extends StatelessWidget {
  const ScaffoldShell({
    Key? key,
    required StatefulNavigationShell navigationShell,
  }) : _navigationShell = navigationShell,
       super(key: key ?? const ValueKey('ScaffoldShell'));

  final StatefulNavigationShell _navigationShell;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(
          context,
        ).colorScheme.surfaceContainer,
        systemNavigationBarDividerColor: Theme.of(
          context,
        ).colorScheme.surfaceContainer,
        systemNavigationBarIconBrightness: switch (Theme.of(
          context,
        ).brightness) {
          Brightness.dark => Brightness.light,
          Brightness.light => Brightness.dark,
        },
      ),
      child: Scaffold(
        body: _navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _navigationShell.currentIndex,
          destinations: _buildDestinations,
          onDestinationSelected: _onDestinationSelected,
          height: kNavigationBarHeight,
        ),
        resizeToAvoidBottomInset: false,
        extendBody: true,
      ),
    );
  }

  List<NavigationDestination> get _buildDestinations {
    return List.generate(4, (index) {
      final icon = switch (index) {
        0 => Icon(
          _navigationShell.currentIndex == index
              ? Icons.home
              : Icons.home_outlined,
        ),
        1 => Icon(
          _navigationShell.currentIndex == index
              ? Icons.favorite
              : Icons.favorite_outline,
        ),
        2 => Icon(
          _navigationShell.currentIndex == index
              ? Icons.event
              : Icons.event_outlined,
        ),
        3 => Icon(
          _navigationShell.currentIndex == index
              ? Icons.explore
              : Icons.explore_outlined,
        ),
        int() => throw RangeError(
          '$index out of range, expected range >= 0 && <= 3',
        ),
      };
      final label = switch (index) {
        0 => 'Esplora',
        1 => 'Preferiti',
        2 => 'Eventi',
        3 => 'Mappa',
        int() => throw RangeError(
          '$index out of range, expected range >= 0 && <= 3',
        ),
      };
      return NavigationDestination(icon: icon, label: label);
    }, growable: false);
  }

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
