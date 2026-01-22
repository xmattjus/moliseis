// Stateful nested navigation based on:
// https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart

import 'package:flutter/material.dart' hide kBottomNavigationBarHeight;
import 'package:go_router/go_router.dart';
import 'package:moliseis/ui/core/themes/system_ui_overlay_styles.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
      value: SystemUiOverlayStyles(context).scaffoldShell,
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
        0 => PhosphorIcon(
          _navigationShell.currentIndex == index
              ? PhosphorIconsDuotone.house
              : PhosphorIconsRegular.house,
          duotoneSecondaryColor: Colors.green,
        ),
        1 => PhosphorIcon(
          _navigationShell.currentIndex == index
              ? PhosphorIconsDuotone.heartStraight
              : PhosphorIconsRegular.heartStraight,
          duotoneSecondaryColor: Colors.green,
        ),
        2 => PhosphorIcon(
          _navigationShell.currentIndex == index
              ? PhosphorIconsDuotone.calendarStar
              : PhosphorIconsRegular.calendarStar,
          duotoneSecondaryColor: Colors.green,
        ),
        3 => PhosphorIcon(
          _navigationShell.currentIndex == index
              ? PhosphorIconsDuotone.globeStand
              : PhosphorIconsRegular.globeStand,
          duotoneSecondaryColor: Colors.green,
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
