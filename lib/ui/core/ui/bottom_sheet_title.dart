import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/app_colors_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_sizes_theme_extension.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BottomSheetTitle extends StatelessWidget {
  final String title;
  final String tooltipMessage;
  final PhosphorIconData? icon;
  final Function()? onClose;
  final int maxLines;

  const BottomSheetTitle({
    super.key,
    required this.title,
    this.tooltipMessage = 'Chiudi',
    this.icon = PhosphorIconsBold.x,
    this.onClose,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsThemeExtension>()!;
    final appSizes = Theme.of(context).extension<AppSizesThemeExtension>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 8.0,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (icon != null)
          Tooltip(
            message: tooltipMessage,
            child: RawMaterialButton(
              onPressed: onClose,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              constraints: const BoxConstraints.expand(width: 32, height: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
                side: BorderSide(
                  color: appColors.modalBorderColor,
                  width: appSizes.borderSize,
                ),
              ),
              fillColor: appColors.modalBackgroundColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              child: PhosphorIcon(icon!, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
