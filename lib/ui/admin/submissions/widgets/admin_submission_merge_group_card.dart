import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/core/ui/description_delta_styles.dart';
import 'package:moliseis/ui/core/utils/quill_document_codec.dart';
import 'package:moliseis/utils/extensions/content_category_extensions.dart';
import 'package:moliseis/utils/extensions/date_time_extensions.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Presents one server-owned merge group without deciding which values to use.
class AdminSubmissionMergeGroupCard extends StatelessWidget {
  /// Keeps [group] intact and delegates [onKeepCurrent] to the editor owner.
  const AdminSubmissionMergeGroupCard({
    required this.group,
    this.onKeepCurrent,
    super.key,
  });

  /// Original atomic group and complete values returned by the server.
  final AdminEventMergeGroup group;

  /// Existing copy/save/preview action, or null when its guard refuses it.
  final VoidCallback? onKeepCurrent;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            _groupLabel(group.name),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(group.apply ? 'Da applicare' : 'Resta invariato'),
          if (group.overwrite)
            const Text(
              'Sovrascrive modifiche del moderatore nell’evento attuale',
            ),
          _GroupValue(
            label: 'Proposta',
            groupName: group.name,
            values: group.moderated,
            private: true,
          ),
          _GroupValue(
            label: 'Evento attuale',
            groupName: group.name,
            values: group.current,
            private: false,
          ),
          ExpansionTile(
            title: const Text('Base e fonte complete'),
            children: [
              _GroupValue(
                label: 'Base',
                groupName: group.name,
                values: group.base,
                private: true,
              ),
              const SizedBox(height: 12),
              _GroupValue(
                label: 'Fonte',
                groupName: group.name,
                values: group.source,
                private: true,
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Dati originali completi'),
            children: [
              for (final side in [
                (label: 'Proposta', values: group.moderated, private: true),
                (
                  label: 'Evento attuale',
                  values: group.current,
                  private: false,
                ),
                (label: 'Base', values: group.base, private: true),
                (label: 'Fonte', values: group.source, private: true),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        side.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      if (side.private)
                        SentryMask(
                          SelectableText(
                            const JsonEncoder.withIndent(
                              '  ',
                            ).convert(side.values),
                          ),
                        )
                      else
                        SelectableText(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(side.values),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onKeepCurrent,
              child: const Text('Mantieni valore attuale'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Labels remain public while private value subtrees retain Replay protection.
class _GroupValue extends StatelessWidget {
  const _GroupValue({
    required this.label,
    required this.groupName,
    required this.values,
    required this.private,
  });

  final String label;
  final String groupName;
  final Map<String, dynamic> values;
  final bool private;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (groupName == 'description') {
      content = _GroupDescription(key: ObjectKey(values), values: values);
    } else {
      content = SelectableText(_readableValues(groupName, values));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        if (private) SentryMask(content) else content,
      ],
    );
  }
}

/// Immutable value identity owns the read-only document and its resources.
class _GroupDescription extends StatefulWidget {
  const _GroupDescription({required this.values, super.key});

  final Map<String, dynamic> values;

  @override
  State<_GroupDescription> createState() => _GroupDescriptionState();
}

class _GroupDescriptionState extends State<_GroupDescription> {
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  QuillController? _controller;
  var _plainDescriptionDiffers = false;

  @override
  void initState() {
    super.initState();
    final document = QuillDocumentCodec.documentFromDelta(
      widget.values['description_delta'],
    );
    if (document != null) {
      _plainDescriptionDiffers =
          widget.values['description'] !=
          QuillDocumentCodec.serialize(document).description;
      _controller = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          SelectableText(_value(widget.values, 'description')),
          if (widget.values['description_delta'] != null)
            const Text(
              'Formattazione non visualizzabile. '
              'Consulta i dati originali completi.',
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        QuillEditor(
          controller: controller,
          focusNode: _focusNode,
          scrollController: _scrollController,
          config: QuillEditorConfig(
            customStyles: descriptionDeltaStyles(context),
            scrollable: false,
            showCursor: false,
            // Exact link destinations remain accessible in the original data.
            onLaunchUrl: (_) {},
          ),
        ),
        if (_plainDescriptionDiffers) ...[
          const Text(
            'Il testo semplice salvato è diverso dal contenuto formattato:',
          ),
          SelectableText(_value(widget.values, 'description')),
        ],
      ],
    );
  }
}

String _groupLabel(String name) => switch (name) {
  'name' => 'Nome',
  'category' => 'Categoria',
  'description' => 'Descrizione',
  'schedule' => 'Date e orari',
  'location' => 'Posizione',
  _ => 'Altri dati',
};

/// Absence, explicit null and an empty string remain distinguishable.
String _value(Map<String, dynamic> values, String key) {
  if (!values.containsKey(key)) return 'Non disponibile';
  final value = values[key];
  if (value == null) return 'Non indicato';
  if (value == '') return 'Vuoto';
  return value.toString();
}

String _readableValues(String groupName, Map<String, dynamic> values) =>
    switch (groupName) {
      'name' => _value(values, 'name'),
      'category' => _category(values),
      'schedule' => _schedule(values),
      'location' =>
        'Comune: ${_value(values, 'city')}\n'
            'Latitudine: ${_coordinate(values, 'latitude')}\n'
            'Longitudine: ${_coordinate(values, 'longitude')}',
      _ => 'Consulta i dati originali completi.',
    };

String _schedule(Map<String, dynamic> values) {
  final mode = values['all_day'];
  final modeText = mode == true
      ? 'Tutto il giorno\n'
      : mode == false
      ? ''
      : 'Modalità oraria: ${_value(values, 'all_day')}\n';
  return '${modeText}Inizio: ${_date(values, 'start_date')}\n'
      'Fine: ${_date(values, 'end_date')}';
}

String _category(Map<String, dynamic> values) {
  final value = values['category'];
  for (final category in ContentCategory.values) {
    if (category != ContentCategory.unknown && category.name == value) {
      return category.label;
    }
  }
  if (value == ContentCategory.unknown.name) return 'Da classificare';
  return value == null || value == ''
      ? _value(values, 'category')
      : 'Categoria non riconosciuta: $value';
}

String _coordinate(Map<String, dynamic> values, String key) {
  final value = values[key];
  return value is num
      ? value.toString().replaceFirst('.', ',')
      : _value(values, key);
}

/// Converts instants for display; original precision stays accessible.
String _date(Map<String, dynamic> values, String key) {
  final raw = values[key];
  if (raw is! String || raw.isEmpty) return _value(values, key);
  final instant = DateTime.tryParse(raw);
  if (instant == null || !instant.isUtc) return 'Data da verificare: $raw';
  final policy = EventTimePolicy();
  final day = policy.calendarDateForUtc(instant);
  final date = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).formatDate(const Locale('it'));
  if (values['all_day'] == true) return date;
  final clock = policy.clockTimeForUtc(instant);
  return '$date · $clock (ora italiana)';
}
