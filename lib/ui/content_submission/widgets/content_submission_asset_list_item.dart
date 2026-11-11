import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// An item in a horizontal asset selection list with a remove button.
///
/// Displays an image with a semi-transparent remove overlay that becomes
/// visible on hover. Tapping the remove overlay invokes [onRemove] to
/// delete the asset.
class ContentSubmissionAssetListItem extends StatelessWidget {
  /// Creates an asset list item.
  ///
  /// [image] is the visual representation of the asset (usually a file image).
  /// [onRemove] is called when the user taps the remove icon to delete this
  /// specific asset.
  const ContentSubmissionAssetListItem({
    required this.image,
    this.showRemoveIcon = true,
    this.removeButtonSize = 24,
    this.onRemove,
    super.key,
  });

  /// Visual representation of the asset to display inside the item.
  final Widget image;

  /// Whether the remove icon is shown or not.
  final bool showRemoveIcon;

  /// Square removal target; larger targets stay within the thumbnail.
  ///
  /// Defaults to the existing public editor presentation.
  final double removeButtonSize;

  /// Callback triggered when the remove icon is pressed.
  final void Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: context.appShapes.circular.cornerMedium,
          child: SentryMask(image),
        ),
        if (showRemoveIcon)
          Positioned(
            top: removeButtonSize > 24 ? 0 : -4,
            right: removeButtonSize > 24 ? 0 : -4,
            child: Semantics(
              label: 'Rimuovi foto',
              button: true,
              enabled: onRemove != null,
              child: Tooltip(
                message: 'Rimuovi foto',
                excludeFromSemantics: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints.tight(
                    Size.square(removeButtonSize),
                  ),
                  child: Material(
                    color: context.colorScheme.primaryContainer,
                    borderRadius: context.appShapes.circular.cornerSmall,
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: onRemove,
                      child: Icon(
                        Symbols.remove,
                        color: context.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
