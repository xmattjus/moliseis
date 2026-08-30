import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_list_item.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';

/// Moderation dashboard for loading, filtering, and opening submissions.
class AdminDashboardScreen extends StatefulWidget {
  /// Creates the staff dashboard with its submissions and authentication state.
  const AdminDashboardScreen({
    required this.viewModel,
    required this.authViewModel,
    super.key,
  });

  /// The dashboard list state.
  final AdminSubmissionsViewModel viewModel;

  /// The staff session state used to log out.
  final AdminAuthViewModel authViewModel;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<void> _openEditor({int? submissionId}) async {
    final router = GoRouter.of(context);
    final viewModel = widget.viewModel;
    if (submissionId == null) {
      await router.pushNamed<bool>(RouteNames.adminSubmissionNew);
    } else {
      await router.pushNamed<bool>(
        RouteNames.adminSubmissionEditor,
        pathParameters: <String, String>{'id': submissionId.toString()},
      );
    }
    if (!mounted) return;
    await viewModel.reloadAfterEditor();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redazione'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Symbols.logout),
            tooltip: 'Esci',
            onPressed: () {
              // Sign-out emits an auth event synchronously, which can unmount
              // this screen while the anonymous-session restoration is awaited.
              // Navigating first keeps the later redirect on a public route.
              context.go(RoutePaths.home);
              unawaited(widget.authViewModel.logout.execute());
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _openEditor,
                icon: const Icon(Symbols.add),
                label: const Text('Nuovo contributo'),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                viewModel,
                viewModel.load,
              ]),
              builder: (context, _) {
                if (viewModel.loading && !viewModel.hasData) {
                  return const EmptyView.loading(
                    text: Text('Caricamento in corso...'),
                  );
                }
                if (viewModel.error && !viewModel.hasData) {
                  return EmptyView.error(
                    text: const Text('Impossibile caricare i contributi'),
                    action: FilledButton(
                      onPressed: viewModel.load.execute,
                      child: const Text('Riprova'),
                    ),
                  );
                }
                if (!viewModel.hasData) {
                  return const EmptyView(
                    icon: Icon(Symbols.inbox),
                    text: Text('Nessun contributo da mostrare'),
                  );
                }

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilterChip(
                            label: const Text('Tutti'),
                            selected: viewModel.filter == null,
                            onSelected: (_) => viewModel.setFilter(null),
                          ),
                          FilterChip(
                            label: const Text('Da revisionare'),
                            selected:
                                viewModel.filter ==
                                AdminSubmissionStatus.pending,
                            onSelected: (_) => viewModel.setFilter(
                              AdminSubmissionStatus.pending,
                            ),
                          ),
                          FilterChip(
                            label: const Text('Accettati'),
                            selected:
                                viewModel.filter ==
                                AdminSubmissionStatus.accepted,
                            onSelected: (_) => viewModel.setFilter(
                              AdminSubmissionStatus.accepted,
                            ),
                          ),
                          FilterChip(
                            label: const Text('Rifiutati'),
                            selected:
                                viewModel.filter ==
                                AdminSubmissionStatus.rejected,
                            onSelected: (_) => viewModel.setFilter(
                              AdminSubmissionStatus.rejected,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: viewModel.filteredItems.isEmpty
                          ? const EmptyView(
                              icon: Icon(Symbols.filter_alt_off),
                              text: Text(
                                'Nessun contributo corrisponde al filtro '
                                'selezionato',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: viewModel.load.execute,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: viewModel.filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = viewModel.filteredItems[index];
                                  return AdminSubmissionListItem(
                                    summary: item,
                                    onTap: () =>
                                        _openEditor(submissionId: item.id),
                                  );
                                },
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
