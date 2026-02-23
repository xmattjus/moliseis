import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class MenuItem {
  final Widget title;
  final Widget icon;
  final String? tooltip;
  final void Function() onPressed;

  MenuItem({
    required this.title,
    required this.icon,
    this.tooltip,
    required this.onPressed,
  });
}

class ResponsiveOverflowMenu extends StatelessWidget {
  final List<MenuItem> items;
  const ResponsiveOverflowMenu({super.key, required this.items});

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
