import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/utils/content_submission_asset_size.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Circular button to trigger the device image picker.
///
/// Tapping opens the platform image picker; the parent asset list observes
/// the resulting command to update its state.
class ContentSubmissionAddAssetButton extends StatelessWidget {
  /// Creates the add-asset button.
  ///
  /// `onPressed` is invoked when the button is tapped.
  const ContentSubmissionAddAssetButton({super.key, required this.onPressed});

  /// Called when the user taps the button.
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tight(
        contentSubmissionAssetSize,
      ),
      child: Material(
        color: context.colorScheme.primaryFixed,
        shape: RoundedRectangleBorder(
          borderRadius: context.appShapes.circular.cornerFull,
        ),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onPressed,
          child: Icon(
            Symbols.add_a_photo,
            size: 24,
            color: context.colorScheme.onPrimaryFixed,
          ),
        ),
      ),
    );
  }
}
