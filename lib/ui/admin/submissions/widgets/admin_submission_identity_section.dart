import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Leads the editor with its private content identity and public review status.
class AdminSubmissionIdentitySection extends StatelessWidget {
  /// Displays current authorized values without introducing editable copies.
  const AdminSubmissionIdentitySection({
    required this.name,
    required this.city,
    required this.isEvent,
    required this.status,
    required this.externalEvent,
    super.key,
  });

  /// Current unpublished title, protected independently of moderation status.
  final String? name;

  /// Current unpublished municipality, with an explicit missing-value label.
  final String? city;

  /// Existing content discriminator, without a separate publication choice.
  final bool isEvent;

  /// Observed moderation state; null denotes a new contribution.
  final AdminSubmissionStatus? status;

  /// Available source linkage; no provider name or URL is inferred from it.
  final AdminExternalEvent? externalEvent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        SentryMask(
          Text(
            name?.trim().isNotEmpty == true ? name! : 'Titolo da inserire',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        SentryMask(
          Text(city?.trim().isNotEmpty == true ? city! : 'Comune da indicare'),
        ),
        Text(
          '${isEvent ? 'Evento' : 'Luogo'} · '
          '${status?.label ?? 'Nuovo contributo'}',
        ),
        if (status == AdminSubmissionStatus.accepted ||
            status == AdminSubmissionStatus.rejected)
          const Text('Contributo concluso · sola lettura'),
        if (externalEvent case final external?)
          Text(
            external.eventId == null
                ? 'Proposta da fonte esterna'
                : 'Proposta da fonte esterna · evento #${external.eventId}',
          ),
      ],
    ),
  );
}

/// Keeps original contributor and technical source evidence in a disclosure.
class AdminSubmissionMetadataSection extends StatelessWidget {
  /// Contains edit-mode metadata only; administrator account context stays out.
  const AdminSubmissionMetadataSection({
    required this.contributorName,
    required this.contributorEmail,
    required this.submissionId,
    required this.createdAt,
    required this.modifiedAt,
    required this.externalEvent,
    super.key,
  });

  /// Original contributor identity remains private after finalization too.
  final String? contributorName;

  /// Original contributor contact, never the create-mode administrator account.
  final String? contributorEmail;

  /// Existing backend identifier, omitted when unavailable.
  final int? submissionId;

  /// Creation timestamp, never used to reconstruct a version token.
  final DateTime? createdAt;

  /// Modification timestamp, independent of opaque concurrency tokens.
  final DateTime? modifiedAt;

  /// Source metadata stays private even with a published destination.
  final AdminExternalEvent? externalEvent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ExpansionTile(
      title: const Text('Autore e dettagli tecnici'),
      children: [
        if (contributorName case final name?) SentryMask(Text(name)),
        if (contributorEmail case final email?) SentryMask(Text(email)),
        if (submissionId case final id?) SentryMask(Text('Contributo #$id')),
        if (createdAt case final created?)
          SentryMask(Text('Creato il ${_formatRomeTimestamp(created)}')),
        if (modifiedAt case final modified?)
          SentryMask(Text('Modificato il ${_formatRomeTimestamp(modified)}')),
        if (externalEvent case final source?)
          SentryMask(
            SelectableText(
              'Record fonte #${source.recordId} · '
              'versione ${source.snapshotVersion}\n'
              'Hash proposta: ${source.snapshotHash}\n'
              'Hash corrente: ${source.currentHash ?? 'Assente'}\n'
              'Proposta originale: ${source.snapshot}\n'
              'Fonte corrente: ${source.currentSnapshot ?? 'Assente'}',
            ),
          ),
      ],
    ),
  );
}

String _formatRomeTimestamp(DateTime instant) {
  final policy = EventTimePolicy();
  final date = policy.calendarDateForUtc(instant);
  final time = policy.clockTimeForUtc(instant);
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
      '$time (ora di Roma)';
}
