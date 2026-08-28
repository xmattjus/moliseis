import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// Style toolbar for `ContentSubmissionDescriptionFormField`.
///
/// Provides bold, italic, underline, ordered list, and unordered list
/// toggles rendered in a rounded surface container.
class ContentSubmissionDescriptionFormFieldToolbox extends StatelessWidget {
  /// Creates the rich-text style toolbar.
  ///
  /// `controller` is the Quill controller whose document the toolbar
  /// modifies.
  const ContentSubmissionDescriptionFormFieldToolbox({
    required this.controller,
    super.key,
  });

  /// Quill controller used to toggle text attributes.
  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: context.appShapes.circular.cornerFull,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            _ConstrainedBox(
              child: QuillToolbarToggleStyleButton(
                controller: controller,
                attribute: Attribute.bold,
              ),
            ),
            _ConstrainedBox(
              child: QuillToolbarToggleStyleButton(
                controller: controller,
                attribute: Attribute.italic,
              ),
            ),
            _ConstrainedBox(
              child: QuillToolbarToggleStyleButton(
                controller: controller,
                attribute: Attribute.underline,
              ),
            ),
            _ConstrainedBox(
              child: QuillToolbarToggleStyleButton(
                controller: controller,
                attribute: Attribute.ol, // Ordered/numbered list
              ),
            ),
            _ConstrainedBox(
              child: QuillToolbarToggleStyleButton(
                controller: controller,
                attribute: Attribute.ul, // Unordered/bulleted list
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConstrainedBox extends StatelessWidget {
  const _ConstrainedBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tight(const Size.square(48)),
      child: child,
    );
  }
}
