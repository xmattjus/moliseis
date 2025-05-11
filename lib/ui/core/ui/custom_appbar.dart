import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moliseis/ui/core/ui/custom_appbar_type.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.systemOverlayStyle,
    this.showBackButton = false,
    this.backButtonBgColor,
  }) : _type = CustomAppBarType.standard,
       assert(
         showBackButton == true && leading == null ||
             showBackButton == false && leading != null ||
             showBackButton == false && leading == null,
       );

  /// Creates an app bar whose height is equal to 0.
  ///
  /// Useful when an app bar is not needed but there is no need to manage
  /// manually the status bar icons color (e.g. with a brightness change).
  const CustomAppBar.hidden({super.key, this.systemOverlayStyle})
    : _type = CustomAppBarType.hidden,
      title = null,
      leading = null,
      actions = null,
      showBackButton = false,
      backButtonBgColor = Colors.transparent;

  final CustomAppBarType _type;
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool showBackButton;
  final Color? backButtonBgColor;

  @override
  Size get preferredSize {
    final isStandardSize = _type == CustomAppBarType.standard;
    return Size.fromHeight(isStandardSize ? kToolbarHeight : 0);
  }

  @override
  Widget build(BuildContext context) {
    final leadingWidget =
        showBackButton
            ? CustomBackButton(backgroundColor: backButtonBgColor)
            : leading;

    return AppBar(
      title: title,
      leading: leadingWidget,
      actions: actions,
      toolbarHeight: preferredSize.height,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: true,
    );
  }
}
