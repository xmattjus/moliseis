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

    return Tooltip(
      message: tooltipMessage,
      child: RawMaterialButton(
        onPressed: onClose,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        constraints: const BoxConstraints.expand(width: 32, height: 32),
        shape: RoundedRectangleBorder(
          borderRadius: context.appShapes.circular.cornerFull,
          side: BorderSide(
            color: context.appColors.modalBorderColor,
            width: context.appSizes.borderSide.medium,
          ),
        ),
        fillColor: context.appEffects.containerColor(
          context.colorScheme.primary,
          context.colorScheme.surfaceContainer,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        child: Icon(icon, size: 16),
      ),
    );
  }
}
