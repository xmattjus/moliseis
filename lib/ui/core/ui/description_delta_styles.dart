import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moliseis/ui/content_submission/widgets/content_description_form_field.dart';
import 'package:moliseis/ui/post/widgets/components/post_description.dart';

/// Builds the [DefaultStyles] used by `QuillEditor` to render content
/// descriptions.
///
/// Shared by the editable editor in the content submission form
/// ([ContentDescriptionFormField]) and the read-only description in the post
/// detail ([PostDescription]), so rich-text descriptions look identical in
/// both places and follow the active app theme.
///
/// The base text style is the theme's `bodyLarge` with `fontVariations`
/// cleared, so variable-font axes from the theme cannot interfere with the
/// bold, italic, and underline emphasis Quill applies to inline styles. Block
/// styles use zero spacing because the surrounding widgets already provide
/// padding and vertical rhythm. Links use `colorScheme.secondary` and the
/// placeholder uses `onSurfaceVariant` at 60% opacity.
///
/// Falls back to a fixed 16-pixel [TextStyle] when the theme does not define
/// `bodyLarge`.
DefaultStyles descriptionDeltaStyles(BuildContext context) {
  final theme = Theme.of(context);
  final baseStyle =
      theme.textTheme.bodyLarge?.copyWith(
        fontVariations: const <FontVariation>[],
      ) ??
      const TextStyle(fontSize: 16);

  DefaultTextBlockStyle blockStyle(TextStyle style) {
    return DefaultTextBlockStyle(
      style,
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
    );
  }

  return DefaultStyles(
    paragraph: blockStyle(baseStyle),
    bold: const TextStyle(fontWeight: FontWeight.bold),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    underline: const TextStyle(decoration: TextDecoration.underline),
    link: TextStyle(
      color: theme.colorScheme.secondary,
      decoration: TextDecoration.underline,
    ),
    placeHolder: blockStyle(
      baseStyle.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    ),
    lists: DefaultListBlockStyle(
      baseStyle,
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      VerticalSpacing.zero,
      null,
      null,
    ),
    leading: blockStyle(baseStyle),
  );
}
