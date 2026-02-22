import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({
    super.key,
    this.padding,
    this.onPressed,
    this.backgroundColor,
  });

  final EdgeInsetsGeometry? padding;

  /// The callback that is called when the button is tapped or otherwise activated.
  ///
  /// If this is set to null, [Navigator.pop] will be called instead.
  final void Function()? onPressed;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Indietro',
      child: Padding(
        padding: padding ?? const EdgeInsets.all(8.0),
        child: IconButton(
          onPressed: onPressed ?? () => Navigator.pop(context),
          style: IconButton.styleFrom(
            padding: EdgeInsets.only(left: Platform.isIOS ? 10.0 : 0),
            backgroundColor:
                backgroundColor ?? Theme.of(context).colorScheme.surface,
          ),
          icon: Icon(
            Platform.isIOS ? Symbols.arrow_back_ios : Symbols.arrow_back,
          ),
        ),
      ),
    );
  }
}
