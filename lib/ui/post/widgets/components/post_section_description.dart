import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/post/widgets/components/post_description.dart';

/// Displays post description with consistent padding.
///
/// Provides a reusable section for displaying content description wrapped in
/// a sliver with standard horizontal padding.
class PostSectionDescription extends StatelessWidget {
  const PostSectionDescription({super.key, required this.content});

  final ContentBase content;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: PostDescription(content: content),
    );
  }
}
