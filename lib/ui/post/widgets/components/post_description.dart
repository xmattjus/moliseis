import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/utils/quill_document_codec.dart';
import 'package:provider/provider.dart';

MarkdownConfig _appMarkdownConfig(BuildContext context) =>
    MarkdownConfig.defaultConfig.copy(
      configs: <WidgetConfig>[
        const H1Config(style: TextStyle(fontSize: 48, height: 1)),
        const H2Config(style: TextStyle(fontSize: 36, height: 1)),
        const H3Config(style: TextStyle(fontSize: 24, height: 1)),
        const H4Config(style: TextStyle(fontSize: 16, height: 20 / 16)),
        const H5Config(style: TextStyle(fontSize: 14, height: 1)),
        const H6Config(style: TextStyle(fontSize: 13, height: 1)),
        LinkConfig(
          style:
              AppTextStyles.link(
                context,
              )?.copyWith(fontSize: 14, height: 1) ??
              const TextStyle(
                color: Color(0xff0969da),
                decoration: TextDecoration.underline,
              ),
        ),
      ],
    );

/// Renders a post description from supported rich content or legacy Markdown.
///
/// A valid, non-empty Delta takes precedence so new content retains its
/// formatting while existing Markdown descriptions continue to render as-is.
class PostDescription extends StatefulWidget {
  const PostDescription({super.key, required this.content});

  final ContentBase content;

  @override
  State<PostDescription> createState() => _PostDescriptionState();
}

class _PostDescriptionState extends State<PostDescription> {
  static const _deltaEquality = DeepCollectionEquality();

  final _markdownGenerator = MarkdownGenerator();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  List<Widget> _markdownWidgets = const [];
  List<Map<String, dynamic>>? _renderedDescriptionDelta;
  QuillController? _quillController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _synchronizeDescription();
  }

  @override
  void didUpdateWidget(covariant PostDescription oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.content.description != oldWidget.content.description ||
        !_deltaEquality.equals(
          widget.content.descriptionDelta,
          oldWidget.content.descriptionDelta,
        )) {
      _synchronizeDescription();
    }
  }

  @override
  void dispose() {
    _quillController?.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _synchronizeDescription() {
    if (_quillController != null &&
        _deltaEquality.equals(
          widget.content.descriptionDelta,
          _renderedDescriptionDelta,
        )) {
      return;
    }

    final document = QuillDocumentCodec.documentFromDelta(
      widget.content.descriptionDelta,
    );
    if (document != null && !document.isEmpty()) {
      final descriptionDelta = QuillDocumentCodec.serialize(
        document,
      ).descriptionDelta;
      if (_quillController != null &&
          _deltaEquality.equals(
            _renderedDescriptionDelta,
            descriptionDelta,
          )) {
        document.close();
        return;
      }

      _quillController?.dispose();
      _quillController = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      _renderedDescriptionDelta = descriptionDelta;
      _markdownWidgets = const [];
      return;
    }

    _quillController?.dispose();
    _quillController = null;
    _renderedDescriptionDelta = null;
    _buildMarkdownWidgets();
  }

  void _buildMarkdownWidgets() {
    if (widget.content.description.isEmpty) {
      _markdownWidgets = const [];
      return;
    }

    _markdownWidgets = _markdownGenerator.buildWidgets(
      widget.content.description,
      config: _appMarkdownConfig(context),
    );
  }

  DefaultStyles _readOnlyStyles(BuildContext context) {
    final bodyStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14);

    return DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        bodyStyle.copyWith(decoration: TextDecoration.none),
        HorizontalSpacing.zero,
        VerticalSpacing.zero,
        VerticalSpacing.zero,
        null,
      ),
      link: AppTextStyles.link(context),
    );
  }

  void _launchUrl(String url) {
    if (!QuillDocumentCodec.isValidLink(url)) return;

    unawaited(
      context.read<UrlLaunchService>().launchGenericUrl(url).then((launched) {
        if (mounted && !launched) {
          showSnackBarGenericError(context: context);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quillController = _quillController;
    if (quillController != null) {
      return SliverList.list(
        children: <Widget>[
          Text('Descrizione', style: AppTextStyles.section(context)),
          QuillEditor(
            controller: quillController,
            focusNode: _focusNode,
            scrollController: _scrollController,
            config: QuillEditorConfig(
              customStyles: _readOnlyStyles(context),
              onLaunchUrl: _launchUrl,
              scrollable: false,
              showCursor: false,
            ),
          ),
        ],
      );
    }

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
