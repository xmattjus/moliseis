import 'dart:async' show StreamSubscription, unawaited;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moliseis/ui/core/ui/description_delta_styles.dart';
import 'package:moliseis/ui/core/utils/quill_document_codec.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

/// An editable rich-text description field for a content submission form.
///
/// The field owns its Quill resources and converts each document change into
/// matching plain-text and Delta projections for the parent form state.
class ContentDescriptionFormField extends StatefulWidget {
  /// Creates a description field initialized from rich content when valid, or
  /// from [initialDescription] when no supported Delta is available.
  const ContentDescriptionFormField({
    required this.initialDescription,
    required this.initialDescriptionDelta,
    required this.onChanged,
    super.key,
  });

  /// Legacy plain-text projection used when [initialDescriptionDelta] is not
  /// a supported Quill document.
  final String? initialDescription;

  /// Rich-text projection that takes precedence over [initialDescription].
  final List<Map<String, dynamic>>? initialDescriptionDelta;

  /// Receives matching plain-text and Delta projections after document edits.
  final void Function({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
  })
  onChanged;

  @override
  State<ContentDescriptionFormField> createState() =>
      _ContentDescriptionFormFieldState();
}

class _ContentDescriptionFormFieldState
    extends State<ContentDescriptionFormField> {
  static const _minimumEditorHeight = 72.0;
  static const _maximumEditorHeight = 144.0;
  static const _maximumDescriptionLength = 5000;

  static const _deltaEquality = DeepCollectionEquality();

  final _focusNode = FocusNode();
  final _formFieldKey = GlobalKey<FormFieldState<String?>>();
  final _scrollController = ScrollController();

  var _isHovered = false;
  var _isFocused = false;

  late QuillController _controller;
  late StreamSubscription<DocChange> _documentChanges;
  String? _lastSynchronizedDescription;
  List<Map<String, dynamic>>? _lastSynchronizedDescriptionDelta;

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(_handleFocusChange);
    final document = _documentFromWidget();
    final value = QuillDocumentCodec.serialize(document);
    _updateLastSynchronizedValue(
      description: value.description,
      descriptionDelta: value.descriptionDelta,
    );
    _createController(document);
  }

  @override
  void didUpdateWidget(covariant ContentDescriptionFormField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialDescription == _lastSynchronizedDescription &&
        identical(
          widget.initialDescriptionDelta,
          _lastSynchronizedDescriptionDelta,
        )) {
      return;
    }

    final document = _documentFromWidget();
    final value = QuillDocumentCodec.serialize(document);
    if (_matchesLastSynchronizedValue(
      description: value.description,
      descriptionDelta: value.descriptionDelta,
    )) {
      return;
    }

    unawaited(_documentChanges.cancel());
    _controller.dispose();
    _updateLastSynchronizedValue(
      description: value.description,
      descriptionDelta: value.descriptionDelta,
    );
    _createController(document);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_matchesLastSynchronizedValue(
            description: value.description,
            descriptionDelta: value.descriptionDelta,
          )) {
        return;
      }
      _formFieldKey.currentState?.didChange(value.description);
    });
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _scrollController.dispose();
    unawaited(_documentChanges.cancel());
    _controller.dispose();
    super.dispose();
  }

  Document _documentFromWidget() {
    return QuillDocumentCodec.documentFromDelta(
          widget.initialDescriptionDelta,
        ) ??
        QuillDocumentCodec.documentFromPlainText(widget.initialDescription);
  }

  void _createController(Document document) {
    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      config: const QuillControllerConfig(
        clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: false),
      ),
    );
    _documentChanges = _controller.changes.listen(_handleDocumentChange);
  }

  void _handleDocumentChange(DocChange _) {
    final value = QuillDocumentCodec.serialize(_controller.document);
    _updateLastSynchronizedValue(
      description: value.description,
      descriptionDelta: value.descriptionDelta,
    );
    _formFieldKey.currentState?.didChange(value.description);
    widget.onChanged(
      description: value.description,
      descriptionDelta: value.descriptionDelta,
    );
  }

  void _updateLastSynchronizedValue({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
  }) {
    _lastSynchronizedDescription = description;
    _lastSynchronizedDescriptionDelta = descriptionDelta;
  }

  bool _matchesLastSynchronizedValue({
    required String? description,
    required List<Map<String, dynamic>>? descriptionDelta,
  }) {
    return description == _lastSynchronizedDescription &&
        _deltaEquality.equals(
          descriptionDelta,
          _lastSynchronizedDescriptionDelta,
        );
  }

  String? _validateDescription(String? description) {
    if (description != null && description.length > _maximumDescriptionLength) {
      return 'La descrizione inserita è troppo lunga';
    }
    return null;
  }

  final _fontSizes = const {
    '11px': '11',
    '12px': '12',
    '13px': '13',
    '14px': '14',
    '15px': '15',
    '16px': '16',
    '18px': '18',
    '20px': '20',
    '22px': '22',
    '24px': '24',
    '26px': '26',
    '28px': '28',
    '30px': '30',
    '32px': '32',
    '36px': '36',
  };

  @override
  Widget build(BuildContext context) {
    final dividerTheme = context.theme.dividerTheme;

    return FormField<String?>(
      key: _formFieldKey,
      initialValue: _lastSynchronizedDescription,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validateDescription,
      builder: (state) {
        return MouseRegion(
          onEnter: (_) => _isHovered = true,
          onExit: (_) => _isHovered = false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputDecorator(
                isHovering: _isHovered,
                isFocused: _isFocused,
                decoration: InputDecoration(
                  errorText: state.errorText,
                  label: const Text('Descrizione'),
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: 12,
                    bottom: 8,
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(
                          height: 12,
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            QuillToolbarFontSizeButton(
                              controller: _controller,
                              options: QuillToolbarFontSizeButtonOptions(
                                items: _fontSizes,
                                initialValue: '16px',
                                defaultDisplayText: '16px',
                              ),
                            ),
                            Container(
                              color: dividerTheme.color,
                              width: 1,
                              height: 36,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            QuillToolbarToggleStyleButton(
                              controller: _controller,
                              attribute: Attribute.bold,
                            ),
                            QuillToolbarToggleStyleButton(
                              controller: _controller,
                              attribute: Attribute.italic,
                            ),
                            QuillToolbarToggleStyleButton(
                              controller: _controller,
                              attribute: Attribute.underline,
                            ),
                            QuillToolbarToggleStyleButton(
                              controller: _controller,
                              attribute: Attribute.leftAlignment,
                            ),
                            QuillToolbarToggleStyleButton(
                              controller: _controller,
                              attribute: Attribute.centerAlignment,
                            ),
                            QuillToolbarToggleStyleButton(
                              controller: _controller,
                              attribute: Attribute.rightAlignment,
                            ),
                            QuillToolbarToggleStyleButton(
                              controller: _controller,
                              attribute: Attribute.ol, // Ordered/numbered list
                            ),
                            QuillToolbarToggleStyleButton(
                              controller: _controller,
                              attribute:
                                  Attribute.ul, // Unordered/bulleted list
                            ),
                            Container(
                              color: dividerTheme.color,
                              width: 1,
                              height: 36,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            QuillToolbarHistoryButton(
                              controller: _controller,
                              isUndo: true,
                            ),
                            QuillToolbarHistoryButton(
                              controller: _controller,
                              isUndo: false,
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Container(
                          color: dividerTheme.color,
                          height: 1,
                          margin: const EdgeInsetsDirectional.only(
                            end: 12,
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: _minimumEditorHeight,
                            maxHeight: _maximumEditorHeight,
                          ),
                          child: Semantics(
                            label: 'Descrizione',
                            textField: true,
                            multiline: true,
                            child: QuillEditor(
                              controller: _controller,
                              focusNode: _focusNode,
                              scrollController: _scrollController,
                              config: QuillEditorConfig(
                                minHeight: _minimumEditorHeight,
                                maxHeight: _maximumEditorHeight,
                                customStyles: descriptionDeltaStyles(context),
                                placeholder:
                                    'Raccontaci qualcosa di questo luogo o '
                                    'evento',
                                padding: const EdgeInsetsDirectional.only(
                                  top: 8,
                                  end: 16,
                                  bottom: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
