import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AppBottomSheetCloseButton extends StatelessWidget {
  final String? tooltipMessage;
  final IconData? icon;
  final Function()? onClose;

  const AppBottomSheetCloseButton({
    super.key,
    this.tooltipMessage = 'Chiudi',
    this.icon = Symbols.close,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return const EmptyBox();
    }

    return IconButton(
      iconSize: 16.0,
      visualDensity: VisualDensity.compact,
      onPressed: onClose,
      tooltip: tooltipMessage,
      color: context.colorScheme.onSecondaryContainer,
      style: IconButton.styleFrom(
        backgroundColor: context.colorScheme.surfaceContainerHighest,
      ),
      icon: Icon(icon),
    );
  }
}
