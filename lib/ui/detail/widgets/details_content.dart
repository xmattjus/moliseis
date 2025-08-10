import 'package:flutter/material.dart';
import 'package:markdown_widget/config/markdown_generator.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';

class DetailsContent extends StatefulWidget {
  const DetailsContent({super.key, required this.content}) : isSliver = false;

  const DetailsContent.sliver({super.key, required this.content})
    : isSliver = true;

  final ContentBase content;
  final bool isSliver;

  @override
  State<DetailsContent> createState() => _DetailsContentState();
}

class _DetailsContentState extends State<DetailsContent> {
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
  void didUpdateWidget(covariant DetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.content.description != oldWidget.content.description) {
      _markdownWidgets = _markdownGenerator.buildWidgets(
        widget.content.description,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Text('Descrizione', style: CustomTextStyles.section(context)),
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
