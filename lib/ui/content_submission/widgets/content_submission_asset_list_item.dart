import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// An item in a horizontal asset selection list with a remove button.
///
/// Displays an image with a semi-transparent remove overlay that becomes
/// visible on hover. Tapping the remove overlay invokes [onPressed] to
/// delete the asset.
class ContentSubmissionAssetListItem extends StatelessWidget {
  /// Creates an asset list item.
  ///
  /// [image] is the visual representation of the asset (usually a file image).
  /// [onPressed] is called when the user taps the remove icon to delete this
  /// specific asset.
  const ContentSubmissionAssetListItem({
    super.key,
    this.onPressed,
    required this.image,
  });

  /// Callback triggered when the remove icon is pressed.
  final void Function()? onPressed;

  /// Visual representation of the asset to display inside the item.
  final Widget image;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: key,
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: context.appShapes.circular.cornerMedium,
          ),
          child: image,
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Tooltip(
            message: 'Rimuovi',
            child: ConstrainedBox(
              constraints: BoxConstraints.tight(const Size.square(24)),
              child: Material(
                color: context.colorScheme.primaryContainer,
                borderRadius: context.appShapes.circular.cornerSmall,
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: onPressed,
                  child: Icon(
                    Symbols.remove,
                    color: context.colorScheme.onPrimaryContainer,
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
