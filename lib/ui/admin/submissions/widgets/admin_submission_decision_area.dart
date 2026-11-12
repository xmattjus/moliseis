import 'package:material_ui/material_ui.dart';

/// Pins the decision and its risks while alternatives scroll independently.
class AdminSubmissionDecisionArea extends StatefulWidget {
  /// Receives already-admitted actions; only disclosure state is local.
  const AdminSubmissionDecisionArea({
    required this.expanded,
    required this.primaryAction,
    required this.secondaryActions,
    this.scrollAll = false,
    this.guidance = const [],
    this.feedback,
    this.status,
    this.linkIdentity,
    this.overwriteCount = 0,
    this.sourceStale = false,
    this.onReviewOverwrites,
    this.onReviewSource,
    super.key,
  });

  /// Whether available width supports the moderation side panel.
  final bool expanded;

  /// Scrolls the complete decision surface when fixed controls cannot fit.
  final bool scrollAll;

  /// Current workflow decision, including its existing disabled state.
  final Widget? primaryAction;

  /// Screen-owned alternatives in decision-precedence order.
  final List<Widget> secondaryActions;

  /// Contextual explanations and correction links for the alternatives.
  final List<Widget> guidance;

  /// Current actionable validation feedback, replacing routine status.
  final Widget? feedback;

  /// Concise operation, recovery, finalized or blocker summary.
  final Widget? status;

  /// Authorized selected target identity when Link is primary.
  final Widget? linkIdentity;

  /// Count from the current server-provided preview groups.
  final int overwriteCount;

  /// Whether the current authorized source detail reports a newer revision.
  final bool sourceStale;

  /// Reveals the current conflict under Screen-owned identity guards.
  final VoidCallback? onReviewOverwrites;

  /// Reveals current source evidence without acknowledging it.
  final VoidCallback? onReviewSource;

  @override
  State<AdminSubmissionDecisionArea> createState() => _DecisionAreaState();
}

class _DecisionAreaState extends State<AdminSubmissionDecisionArea> {
  late bool _actionsExpanded;

  @override
  void initState() {
    super.initState();
    _actionsExpanded = widget.expanded;
  }

  @override
  void didUpdateWidget(AdminSubmissionDecisionArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      _actionsExpanded = widget.expanded;
    }
  }

  void _toggleActions() {
    setState(() => _actionsExpanded = !_actionsExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.overwriteCount;
    final stale = widget.sourceStale;
    final overwriteText = count == 1
        ? '1 sovrascrittura'
        : '$count sovrascritture';
    final reviewOverwrites = widget.onReviewOverwrites;
    final reviewSource = widget.onReviewSource;
    final hasRisks = count > 0 || stale;
    final riskSummary = [
      if (count > 0) overwriteText,
      if (stale) 'Fonte aggiornata',
    ].join(' · ');
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: widget.scrollAll ? 0 : 8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final compactRisk =
                  constraints.maxHeight <
                  (count > 0 && stale ? 360 : 260) * scale;
              final alternatives = [
                ...widget.guidance,
                ...widget.secondaryActions,
              ];
              final scrollAll = widget.scrollAll;
              final panel = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.feedback == null) ?widget.status,
                  ?widget.feedback,
                  ?widget.linkIdentity,
                  ?widget.primaryAction,
                  if (hasRisks && compactRisk)
                    Semantics(
                      liveRegion: true,
                      child: PopupMenuButton<VoidCallback>(
                        key: const ValueKey('admin_decision_risks'),
                        tooltip: 'Esamina i rischi della decisione',
                        onSelected: (action) {
                          if (!mounted) return;
                          action();
                        },
                        itemBuilder: (_) => [
                          if (count > 0)
                            PopupMenuItem(
                              value: reviewOverwrites,
                              enabled: reviewOverwrites != null,
                              child: const Text('Esamina sovrascritture'),
                            ),
                          if (stale)
                            PopupMenuItem(
                              value: reviewSource,
                              enabled: reviewSource != null,
                              child: const Text('Esamina fonte aggiornata'),
                            ),
                        ],
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    riskSummary,
                                    key: ValueKey(
                                      count > 0
                                          ? 'admin_overwrite_warning'
                                          : 'admin_source_warning',
                                    ),
                                  ),
                                ),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (hasRisks) ...[
                    if (count > 0) ...[
                      Text(
                        '$overwriteText nell’evento',
                        key: const ValueKey('admin_overwrite_warning'),
                      ),
                      TextButton(
                        onPressed: reviewOverwrites,
                        child: const Text('Esamina sovrascritture'),
                      ),
                    ],
                    if (stale) ...[
                      const Text('È disponibile una fonte aggiornata'),
                      TextButton(
                        onPressed: reviewSource,
                        child: const Text('Esamina fonte aggiornata'),
                      ),
                    ],
                  ],
                  if (alternatives.isNotEmpty) ...[
                    Semantics(
                      key: const ValueKey('admin_secondary_toggle'),
                      container: true,
                      button: true,
                      expanded: _actionsExpanded,
                      label: 'Altre azioni',
                      onTap: _toggleActions,
                      child: ExcludeSemantics(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _toggleActions,
                          icon: Icon(
                            _actionsExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: const Text('Altre azioni'),
                        ),
                      ),
                    ),
                    if (_actionsExpanded && !scrollAll)
                      Flexible(
                        child: SingleChildScrollView(
                          key: const ValueKey(
                            'admin_decision_secondary_scroll',
                          ),
                          primary: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: alternatives
                                .map(
                                  (action) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: action,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    if (_actionsExpanded && scrollAll)
                      ...alternatives.map(
                        (action) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: action,
                          ),
                        ),
                      ),
                  ],
                ],
              );
              return scrollAll
                  ? SingleChildScrollView(
                      key: const ValueKey('admin_decision_complete_scroll'),
                      primary: false,
                      child: panel,
                    )
                  : panel;
            },
          ),
        ),
      ),
    );
  }
}
