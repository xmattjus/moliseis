import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_close_button.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class AppBottomSheetTitle extends StatelessWidget {
  final String title;
  final String tooltipMessage;
  final IconData? icon;
  final Function()? onClose;
  final int maxLines;

  const AppBottomSheetTitle({
    super.key,
    required this.title,
    this.tooltipMessage = 'Chiudi',
    this.icon = Symbols.close,
    this.onClose,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    spacing: 8.0,
    children: <Widget>[
      Expanded(
        child: Text(
          title,
          style: context.textTheme.bodyLarge,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (icon != null)
        AppBottomSheetCloseButton(
          tooltipMessage: tooltipMessage,
          icon: icon,
          onClose: onClose,
        ),
    ],
  );
}
