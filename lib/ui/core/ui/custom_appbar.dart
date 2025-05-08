import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/ui/core/ui/custom_appbar_type.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.systemOverlayStyle,
    this.showBackButton = false,
    this.backButtonBackground,
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
      backButtonBackground = Colors.transparent;

  final CustomAppBarType _type;
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool showBackButton;
  final Color? backButtonBackground;

  @override
  Size get preferredSize {
    final isStandardSize = _type == CustomAppBarType.standard;
    return Size.fromHeight(isStandardSize ? kToolbarHeight : 0);
  }

  @override
  Widget build(BuildContext context) {
    final leadingWidget =
        showBackButton
            ? IconButton(
              onPressed: () {
                GoRouter.of(context).pop();
              },
              style: IconButton.styleFrom(
                backgroundColor:
                    backButtonBackground ?? Theme.of(context).canvasColor,
              ),
              icon: ButtonTheme(child: const Icon(Icons.arrow_back)),
            )
            : leading;
    // final isStandardSize = _type == _AppToolbarType.standard;
    return AppBar(
      title: title,
      leading: leadingWidget,
      actions: actions,
      toolbarHeight: preferredSize.height,
      systemOverlayStyle: systemOverlayStyle,
      forceMaterialTransparency: true, // isStandardSize ? true : true,
    );
  }
}
