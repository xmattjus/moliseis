import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class MenuItem {
  MenuItem({
    required this.title,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final Widget title;
  final Widget icon;
  final void Function() onPressed;
  final String? tooltip;
}

class ResponsiveOverflowMenu extends StatelessWidget {
  const ResponsiveOverflowMenu({required this.items, super.key});

  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final showMenuAnchor = context.windowSizeClass.isCompact;

    if (showMenuAnchor) {
      return MenuAnchor(
        menuChildren: UnmodifiableListView<Widget>(
          items.map((item) {
            return MenuItemButton(
              onPressed: item.onPressed,
              leadingIcon: item.icon,
              child: item.title,
            );
          }),
        ),
        builder: (context, controller, child) => IconButton(
          onPressed: () {
            controller.isOpen ? controller.close() : controller.open();
          },
          tooltip: 'Altro',
          icon: const Icon(Symbols.more_vert, weight: 900),
        ),
      );
    }
    return Row(
      children: UnmodifiableListView<Widget>(
        items.map((item) {
          return IconButton(
            onPressed: item.onPressed,
            tooltip: item.tooltip,
            icon: item.icon,
          );
        }),
      ),
    );
  }
}
