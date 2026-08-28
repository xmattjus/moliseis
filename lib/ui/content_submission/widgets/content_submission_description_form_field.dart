import 'dart:async' show StreamSubscription, unawaited;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_description_form_field_toolbox.dart';
import 'package:moliseis/ui/core/ui/description_delta_styles.dart';
import 'package:moliseis/ui/core/utils/quill_document_codec.dart';

/// An editable rich-text description field for a content submission form.
///
/// The field owns its Quill resources and converts each document change into
/// matching plain-text and Delta projections for the parent form state.
class ContentSubmissionDescriptionFormField extends StatefulWidget {
  /// Creates a description field initialized from rich content when valid, or
  /// from [initialDescription] when no supported Delta is available.
  const ContentSubmissionDescriptionFormField({
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
  State<ContentSubmissionDescriptionFormField> createState() =>
      _ContentSubmissionDescriptionFormFieldState();
}

class _ContentSubmissionDescriptionFormFieldState
    extends State<ContentSubmissionDescriptionFormField> {
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
  void didUpdateWidget(
    covariant ContentSubmissionDescriptionFormField oldWidget,
  ) {
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

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        4,
                      ),
                      child: ContentSubmissionDescriptionFormFieldToolbox(
                        controller: _controller,
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
              ),
            ],
          ),
        );
      },
    );
  }
}
