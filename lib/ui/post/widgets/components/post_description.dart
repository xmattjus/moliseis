import 'package:flutter/material.dart';
import 'package:markdown_widget/config/markdown_generator.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';

class PostDescription extends StatefulWidget {
  const PostDescription({super.key, required this.content}) : isSliver = false;

  const PostDescription.sliver({super.key, required this.content})
    : isSliver = true;

  final ContentBase content;
  final bool isSliver;

  @override
  State<PostDescription> createState() => _PostDescriptionState();
}

class _PostDescriptionState extends State<PostDescription> {
  final _markdownGenerator = MarkdownGenerator();

  List<Widget>? _markdownWidgets;

  @override
  void initState() {
    super.initState();
    _markdownWidgets = _markdownGenerator.buildWidgets(
      widget.content.description,
    );
  }

  @override
  void didUpdateWidget(covariant PostDescription oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.content.description != oldWidget.content.description) {
      _markdownWidgets = _markdownGenerator.buildWidgets(
        widget.content.description,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_markdownWidgets?.isEmpty ?? true) {
      return widget.isSliver
          ? const SliverToBoxAdapter(child: EmptyBox())
          : const EmptyBox();
    }

    final children = <Widget>[
      Text('Descrizione', style: AppTextStyles.section(context)),
      ...?_markdownWidgets,
    ];

    return widget.isSliver
        ? SliverList.list(children: children)
        : ListView(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: children,
          );
  }
}
