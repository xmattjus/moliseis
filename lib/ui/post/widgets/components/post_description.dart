import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';

MarkdownConfig _appMarkdownConfig(BuildContext context) =>
    MarkdownConfig.defaultConfig.copy(
      configs: <WidgetConfig>[
        const H1Config(style: TextStyle(fontSize: 48, height: 1.0)),
        const H2Config(style: TextStyle(fontSize: 36, height: 1.0)),
        const H3Config(style: TextStyle(fontSize: 24, height: 1.0)),
        const H4Config(style: TextStyle(fontSize: 16, height: 20 / 16)),
        const H5Config(style: TextStyle(fontSize: 14, height: 1.0)),
        const H6Config(style: TextStyle(fontSize: 13, height: 1.0)),
        LinkConfig(
          style:
              AppTextStyles.link(
                context,
              )?.copyWith(fontSize: 14, height: 1.0) ??
              const TextStyle(
                color: Color(0xff0969da),
                decoration: TextDecoration.underline,
              ),
        ),
      ],
    );

class PostDescription extends StatefulWidget {
  const PostDescription({super.key, required this.content});

  final ContentBase content;

  @override
  State<PostDescription> createState() => _PostDescriptionState();
}

class _PostDescriptionState extends State<PostDescription> {
  final _markdownGenerator = MarkdownGenerator();

  List<Widget> _markdownWidgets = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _buildMarkdownWidgets();
  }

  @override
  void didUpdateWidget(covariant PostDescription oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.content.description != oldWidget.content.description) {
      _buildMarkdownWidgets();
    }
  }

  void _buildMarkdownWidgets() {
    _markdownWidgets = _markdownGenerator.buildWidgets(
      widget.content.description,
      config: _appMarkdownConfig(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_markdownWidgets.isEmpty) {
      return const SliverToBoxAdapter(child: EmptyBox());
    }

    final children = <Widget>[
      Text('Descrizione', style: AppTextStyles.section(context)),
      ..._markdownWidgets,
    ];

    return SliverList.list(children: children);
  }
}
