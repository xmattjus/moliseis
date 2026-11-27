import 'package:material_ui/material_ui.dart';
import 'package:moliseis/routing/explicit_back.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({
    this.padding,
    this.onPressed,
    this.backgroundColor,
    super.key,
  });

  final EdgeInsetsGeometry? padding;

  /// Handles activation in place of the ordinary app Back action.
  final VoidCallback? onPressed;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = switch (theme.platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      _ => false,
    };
    return Padding(
      padding: padding ?? (mobile ? EdgeInsets.zero : const EdgeInsets.all(8)),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: BackButton(
          onPressed: onPressed ?? () => requestExplicitBack(context),
          style: IconButton.styleFrom(
            backgroundColor: backgroundColor ?? theme.colorScheme.surface,
            visualDensity: mobile ? VisualDensity.standard : null,
            tapTargetSize: mobile ? MaterialTapTargetSize.padded : null,
          ),
        ),
      ),
    );
  }
}
