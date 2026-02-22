import 'dart:collection' show UnmodifiableListView;
import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AppNavigationRail extends StatefulWidget {
  final int selectedIndex;
  final void Function(int value)? onDestinationSelected;
  final List<NavigationDestination> destinations;

  /// Creates a Material Design navigation rail.
  const AppNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  State<AppNavigationRail> createState() => _AppNavigationRailState();
}

class _AppNavigationRailState extends State<AppNavigationRail> {
  // Whether the navigation rail is currently extended.
  bool _isExtended = false;
  // Whether the user has manually extended the navigation rail at least once.
  bool _hasBeenExtended = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Prevent the navigation rail from automatically collapsing/extending when
    // the window size changes after the user has manually extended it at least once.
    if (!_hasBeenExtended) {
      _isExtended = context.windowSizeClass.isAtLeast(WindowSizeClass.large);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    return NavigationRail(
      extended: _isExtended,
      leading: _AppNavigationRailMenuButton(
        onPressed: () => setState(() {
          _isExtended = !_isExtended;
          _hasBeenExtended = true;
        }),
      ),
      destinations: UnmodifiableListView<NavigationRailDestination>(
        widget.destinations.map((destination) {
          final isSelected =
              destination.icon ==
              widget.destinations[widget.selectedIndex].icon;
          return NavigationRailDestination(
            icon: destination.icon,
            selectedIcon: destination.selectedIcon,
            label: Text(
              destination.label,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
      ),
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: (value) =>
          widget.onDestinationSelected?.call(value),
      labelType: _isExtended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      minWidth: 96.0,
      minExtendedWidth: 220.0,
    );
  }
}

class _AppNavigationRailMenuButton extends StatelessWidget {
  final void Function()? onPressed;

  /// Creates a widget that animates its position when the parent navigation
  /// rail extends or collapses.
  ///
  /// Source: https://stackoverflow.com/a/73851023
  const _AppNavigationRailMenuButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final animation = NavigationRail.extendedAnimation(context);

    const iconSize = 24.0;

    // The value to insets the (right side of the) icon with when the parent
    // navigation rail is expanding.
    //
    // The first dimension must be equal to the parent 'minExtendedWidth'
    // property.
    const maxIconRightPadding = (220.0 / 2) + (iconSize / 2);

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final isExtended = animation.status.isForwardOrCompleted;
        return Container(
          padding: EdgeInsets.only(
            top: 44.0,
            right: !isExtended
                ? 0
                : ui.lerpDouble(0, maxIconRightPadding + 2.0, animation.value)!,
          ),
          child: IconButton(
            icon: Icon(isExtended ? Symbols.menu_open : Symbols.menu),
            tooltip: isExtended ? 'Chiudi menu' : 'Apri menu',
            iconSize: iconSize,
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}
