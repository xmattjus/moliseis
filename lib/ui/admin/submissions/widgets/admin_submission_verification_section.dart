import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_external_event.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_merge_group_card.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Presents current evidence and delegates every interaction to the Screen.
class AdminSubmissionVerificationSection extends StatelessWidget {
  /// Leaves controllers, scroll targets and command admission with the Screen.
  const AdminSubmissionVerificationSection({
    required this.viewModel,
    required this.targetController,
    required this.sourceKey,
    required this.overwriteKey,
    required this.previewErrorMessage,
    required this.publicationLabel,
    required this.onSearchChanged,
    required this.onFindCandidates,
    required this.onTargetChanged,
    required this.onAcknowledge,
    required this.onKeepCurrent,
    super.key,
  });

  /// Existing owner snapshot; only the enclosing Screen observes it.
  final AdminSubmissionEditorViewModel viewModel;

  /// Screen-owned controller, preserved across responsive rebuilds.
  final TextEditingController targetController;

  /// Current-source navigation anchor, retired with its owning Screen.
  final GlobalKey sourceKey;

  /// Anchor attached only to the current first overwrite group.
  final GlobalKey overwriteKey;

  /// Existing error contract translated by the Screen.
  final String previewErrorMessage;

  /// Existing finalized publication linkage, when available.
  final String? publicationLabel;

  /// Changes the existing candidate query without new discovery logic.
  final ValueChanged<String> onSearchChanged;

  /// Runs the current admitted candidate command, or disables the action.
  final VoidCallback? onFindCandidates;

  /// Selects the exact existing candidate or manually entered ID.
  final ValueChanged<int?> onTargetChanged;

  /// Explicitly acknowledges the displayed source under identity guards.
  final ValueChanged<bool>? onAcknowledge;

  /// Receives the original server group unchanged.
  final ValueChanged<AdminEventMergeGroup>? onKeepCurrent;

  @override
  Widget build(BuildContext context) {
    final status = viewModel.status;
    final external = viewModel.externalEvent;
    final merge = viewModel.mergePreview;
    final groups = merge == null
        ? <AdminEventMergeGroup>[]
        : [
            ...merge.groups.where((g) => g.overwrite),
            ...merge.groups.where(
              (g) =>
                  !g.overwrite &&
                  (g.apply || g.providerChanged || g.moderatorChanged),
            ),
            ...merge.groups.where(
              (g) =>
                  !g.overwrite &&
                  !g.apply &&
                  !g.providerChanged &&
                  !g.moderatorChanged,
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TextSectionDivider('Verifica e confronto'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              if (external != null) ...[
                if (external.stale)
                  const Text(
                    'La proposta è precedente alla versione '
                    'corrente della fonte.',
                  ),
                Text('Versione corrente della fonte', key: sourceKey),
                if (external.currentSnapshot == null)
                  const Text('Dettaglio della fonte non disponibile.'),
                if (external.currentSnapshot case final source?)
                  for (final entry in source.entries)
                    SentryMask(
                      SelectableText(
                        '${switch (entry.key) {
                          'name' => 'Nome',
                          'category' => 'Categoria',
                          'description' => 'Descrizione',
                          'city' => 'Città',
                          'latitude' => 'Latitudine',
                          'longitude' => 'Longitudine',
                          'all_day' => 'Tutto il giorno',
                          'start_date' => 'Inizio',
                          'end_date' => 'Fine',
                          _ => entry.key,
                        }}: ${entry.value ?? "Non disponibile"}',
                      ),
                    ),
                if (external.stale && status == AdminSubmissionStatus.pending)
                  CheckboxListTile(
                    key: const ValueKey('admin_acknowledge_current_source'),
                    title: const Text(
                      'Considera valutata anche la versione '
                      'corrente della fonte',
                    ),
                    subtitle: const Text(
                      'La risoluzione della proposta non '
                      'considera automaticamente valutate le revisioni più '
                      'recenti.',
                    ),
                    value: viewModel.acknowledgeCurrentSource,
                    onChanged: onAcknowledge == null
                        ? null
                        : (value) => onAcknowledge!(value ?? false),
                  ),
              ],
              if (status == AdminSubmissionStatus.pending &&
                  viewModel.startDate != null) ...[
                SentryMask(
                  KeyedSubtree(
                    key: ObjectKey(viewModel),
                    child: TextFormField(
                      key: const ValueKey('admin_event_search'),
                      decoration: const InputDecoration(
                        labelText: 'Cerca evento per nome',
                      ),
                      initialValue: viewModel.candidateSearch,
                      onChanged: onSearchChanged,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onFindCandidates,
                  child: const Text('Cerca eventi'),
                ),
                if (viewModel.findCandidatesSnapshot.hasFailure)
                  const Text('Impossibile cercare gli eventi. Riprova.'),
                if (viewModel.candidates case final matches?) ...[
                  for (final warning in matches.pendingWarnings)
                    SentryMask(
                      Text(
                        'Altro contributo in attesa: '
                        '${warning.name} (#${warning.id}). '
                        'Questo avviso non blocca la moderazione.',
                      ),
                    ),
                  for (final candidate in matches.events)
                    ListTile(
                      key: ValueKey('admin_event_candidate_${candidate.id}'),
                      title: Text(candidate.name),
                      subtitle: Text(
                        '${candidate.city ?? "Città non disponibile"} '
                        '· #${candidate.id}',
                      ),
                      selected: viewModel.targetEventId == candidate.id,
                      onTap: viewModel.operationRunning || viewModel.loading
                          ? null
                          : () => onTargetChanged(candidate.id),
                    ),
                ],
                if (viewModel.targetEventId case final target?)
                  AdminSubmissionLinkTargetIdentity(
                    targetId: target,
                    candidates: viewModel.candidates,
                  ),
                TextFormField(
                  key: const ValueKey('admin_event_target'),
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'ID evento esistente',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !viewModel.operationRunning && !viewModel.loading,
                  onChanged: (value) => onTargetChanged(int.tryParse(value)),
                ),
                if (viewModel.isExternalUpdate) ...[
                  if (viewModel.previewSnapshot.hasFailure ||
                      viewModel.keepCurrentSnapshot.hasFailure)
                    SentryMask(Text(previewErrorMessage)),
                  for (final group in groups)
                    AdminSubmissionMergeGroupCard(
                      key:
                          identical(
                            group,
                            groups.where((g) => g.overwrite).firstOrNull,
                          )
                          ? overwriteKey
                          : ObjectKey(group),
                      group: group,
                      onKeepCurrent: onKeepCurrent == null
                          ? null
                          : () => onKeepCurrent!(group),
                    ),
                ],
              ],
              if (status != AdminSubmissionStatus.pending) ...[
                if (status != null) Text(status.label),
                if (publicationLabel != null) Text(publicationLabel!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Describes only a selected ID's match in the current authorized candidates.
class AdminSubmissionLinkTargetIdentity extends StatelessWidget {
  /// Uses only the current candidate list; never performs a target lookup.
  const AdminSubmissionLinkTargetIdentity({
    required this.targetId,
    required this.candidates,
    this.concise = false,
    super.key,
  });

  /// Selected command target, even when no readable identity is verified.
  final int targetId;

  /// Current authorized results, discarded by the owner when superseded.
  final AdminEventCandidates? candidates;

  /// Bounds text in the persistent panel; full values remain in verification.
  final bool concise;

  @override
  Widget build(BuildContext context) {
    final candidate = candidates?.events
        .where((event) => event.id == targetId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (candidate != null) ...[
          Text(
            candidate.name,
            maxLines: concise ? 1 : null,
            overflow: concise ? TextOverflow.ellipsis : null,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (concise)
            Row(
              children: [
                if (candidate.city != null)
                  Expanded(
                    child: Text(
                      candidate.city!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(' #$targetId'),
              ],
            )
          else ...[
            if (candidate.city != null) Text(candidate.city!),
            Text('Evento selezionato: #$targetId'),
          ],
        ] else
          Text('Evento #$targetId · identità da verificare'),
        if (!concise)
          const Text(
            'Il collegamento associa la proposta senza '
            'sovrascrivere i contenuti dell’evento.',
          ),
      ],
    );
  }
}
