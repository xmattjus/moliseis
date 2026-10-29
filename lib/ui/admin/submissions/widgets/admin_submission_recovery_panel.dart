import 'package:collection/collection.dart';
import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/utils/extensions/content_category_extensions.dart';

/// Reviews whole-field alternatives without owning their persistence.
class AdminSubmissionRecoveryPanel extends StatelessWidget {
  /// Callbacks retain the observation and activation supplied by the owner.
  const AdminSubmissionRecoveryPanel({
    required this.local,
    required this.remote,
    required this.status,
    required this.onAccept,
    required this.onKeep,
    super.key,
  });

  /// Preserved editable snapshot, including invalid and incomplete values.
  final AdminDraftSnapshot local;

  /// Fresh observed fields; displaying these does not authorize a Save.
  final AdminDraftSnapshot remote;

  /// Status of the observed remote submission, independently of local fields.
  final AdminSubmissionStatus status;

  /// Explicitly replaces editor fields, without writing their local checkpoint.
  final VoidCallback? onAccept;

  /// Explicitly retains local fields for a later separately requested Save.
  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    final deltaChanged = !const DeepCollectionEquality().equals(
      local.descriptionDelta,
      remote.descriptionDelta,
    );
    final differences = <({String label, String local, String remote})>[
      if (local.name != remote.name)
        (label: 'Nome', local: _value(local.name), remote: _value(remote.name)),
      if (local.category != remote.category)
        (
          label: 'Categoria',
          local: _value(local.category?.label),
          remote: _value(remote.category?.label),
        ),
      if (local.description != remote.description || deltaChanged)
        (
          label: deltaChanged
              ? 'Descrizione · formattazione differente'
              : 'Descrizione',
          local: _value(local.description),
          remote: _value(remote.description),
        ),
      if (local.eventDates != remote.eventDates)
        (
          label: 'Date e orari',
          local: _schedule(local.eventDates),
          remote: _schedule(remote.eventDates),
        ),
      if (local.city != remote.city ||
          local.latitudeText != remote.latitudeText ||
          local.longitudeText != remote.longitudeText)
        (
          label: 'Posizione',
          local: _location(local),
          remote: _location(remote),
        ),
    ];
    return Card.outlined(
      key: const ValueKey('admin_recovery_comparison'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              'Confronta le versioni',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Stato remoto: ${status.label}'),
            const Text(
              'Scegli quali campi mantenere nell’editor. '
              'Le foto locali restano conservate. '
              'Nessuna scelta salva sul server.',
            ),
            if (differences.isEmpty)
              const Text('I campi visibili coincidono con la versione remota.'),
            for (final difference in differences)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    difference.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final localValue = _ComparisonValue(
                        label: 'Locale',
                        value: difference.local,
                      );
                      final remoteValue = _ComparisonValue(
                        label: 'Remoto',
                        value: difference.remote,
                      );
                      return constraints.maxWidth >= 600
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 16,
                              children: [
                                Expanded(child: localValue),
                                Expanded(child: remoteValue),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [localValue, remoteValue],
                            );
                    },
                  ),
                ],
              ),
            const Text(
              'Accettare i campi remoti cambia solo l’editor. '
              'Salva la bozza locale prima di aprire un altro contributo: '
              'fino ad allora resta su disco la copia precedente.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('admin_accept_remote'),
                  onPressed: onAccept,
                  child: const Text('Accetta campi remoti'),
                ),
                OutlinedButton(
                  key: const ValueKey('admin_keep_local'),
                  onPressed: onKeep,
                  child: const Text('Mantieni campi locali'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One side of a comparison, with wrapping text at narrow widths.
class _ComparisonValue extends StatelessWidget {
  const _ComparisonValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      SelectableText(value),
    ],
  );
}

String _value(String? value) => value == null || value.isEmpty ? '—' : value;

String _location(AdminDraftSnapshot fields) =>
    '${_value(fields.city)}\n'
    'Latitudine: ${_value(fields.latitudeText)}\n'
    'Longitudine: ${_value(fields.longitudeText)}';

/// Keeps incomplete civil dates and exact time precision visible in the review.
String _schedule(EventDateDraft dates) {
  if (!dates.enabled) return 'Non è un evento';
  if (dates.allDay) {
    return 'Tutto il giorno\n'
        'Inizio: ${dates.startCalendarDate ?? "da definire"}\n'
        'Fine: ${dates.endCalendarDate ?? "—"}';
  }
  final start = dates.startInstantUtc;
  final end = dates.endInstantUtc;
  final startText = start == null
      ? '${dates.startCalendarDate ?? "Data da definire"} · ora da definire'
      : _instant(start);
  final endText = end == null
      ? dates.endCalendarDate?.toString() ?? '—'
      : _instant(end);
  return 'Inizio: $startText\nFine: $endText';
}

String _instant(DateTime instant) {
  final policy = EventTimePolicy();
  final fraction = instant.millisecond * 1000 + instant.microsecond;
  final precision = fraction == 0
      ? ''
      : '.${fraction.toString().padLeft(6, '0')}';
  return '${policy.calendarDateForUtc(instant)} '
      '${policy.clockTimeForUtc(instant)}:'
      '${instant.second.toString().padLeft(2, '0')}$precision (Europe/Rome)';
}

/// Preview stays isolated from native editor repositories and platform plugins.
@Preview(name: 'Admin field recovery', size: Size(390, 700))
Widget adminSubmissionRecoveryPreview() => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: AdminSubmissionRecoveryPanel(
        local: AdminDraftSnapshot(name: 'Titolo locale', city: 'Campobasso'),
        remote: AdminDraftSnapshot(name: 'Titolo remoto', city: 'Isernia'),
        status: AdminSubmissionStatus.pending,
        onAccept: null,
        onKeep: null,
      ),
    ),
  ),
);
