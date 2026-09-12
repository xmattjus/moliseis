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
import 'package:moliseis/ui/explore/widgets/responsive_overflow_menu.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

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
  static const _filters = <AdminSubmissionStatus?>[
    null,
    AdminSubmissionStatus.pending,
    AdminSubmissionStatus.accepted,
    AdminSubmissionStatus.rejected,
  ];

  Future<void> _openEditor({int? submissionId}) async {
    final router = GoRouter.of(context);
    final changed = submissionId == null
        ? await router.pushNamed<bool>(RouteNames.adminSubmissionNew)
        : await router.pushNamed<bool>(
            RouteNames.adminSubmissionEditor,
            pathParameters: <String, String>{'id': submissionId.toString()},
          );
    if (!mounted || changed != true) return;
    await widget.viewModel.load.execute();
  }

  void _logout() {
    // Sign-out emits an auth event synchronously, which can
    // unmount this screen while the anonymous-session
    // restoration is awaited. Navigating first keeps the
    // later redirect on a public route.
    context.go(RoutePaths.home);
    unawaited(widget.authViewModel.logout.execute());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return Scaffold(
      body: RefreshIndicator(
        displacement: 64,
        edgeOffset: 106,
        onRefresh: () => viewModel.load.execute(),
        notificationPredicate: (notification) {
          return notification.depth == 1;
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, _) {
            return [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: SliverAppBar(
                  title: const Text('Area redazione'),
                  actions: <Widget>[
                    ResponsiveOverflowMenu(
                      items: [
                        MenuItem(
                          title: const Text('Aggiorna'),
                          icon: const Icon(Symbols.sync, weight: 500),
                          tooltip: 'Aggiorna i contenuti',
                          onPressed: viewModel.load.execute,
                        ),
                        MenuItem(
                          title: const Text('Logout'),
                          icon: const Icon(Symbols.logout),
                          tooltip: 'Esegui il logout',
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ],
                  floating: true,
                  snap: true,
                  forceMaterialTransparency: true,
                ),
              ),
              SliverAppBar(
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ListenableBuilder(
                        listenable: viewModel,
                        builder: (context, _) {
                          return ToggleButtons(
                            borderRadius: context.appShapes.circular.cornerFull,
                            constraints: const BoxConstraints(
                              minHeight: 40,
                              maxHeight: 40,
                            ),
                            isSelected: _filters
                                .map((status) => viewModel.filter == status)
                                .toList(growable: false),
                            onPressed: (index) =>
                                viewModel.setFilter(_filters[index]),
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Tutti'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Da revisionare'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Accettati'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Rifiutati'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                automaticallyImplyLeading: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                pinned: true,
              ),
            ];
          },
          body: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  viewModel,
                  viewModel.load,
                ]),
                builder: (context, _) {
                  if (viewModel.loading && !viewModel.hasData) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView.loading(
                        text: Text('Caricamento in corso...'),
                      ),
                    );
                  }
                  if (viewModel.error && !viewModel.hasData) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView.error(
                        text: const Text('Impossibile caricare i contributi'),
                        action: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: FilledButton(
                            onPressed: viewModel.load.execute,
                            child: const Text('Riprova'),
                          ),
                        ),
                      ),
                    );
                  }
                  if (!viewModel.hasData) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        icon: Icon(Symbols.inbox),
                        text: Text('Nessun contributo da mostrare'),
                      ),
                    );
                  }

                  final filteredItems = viewModel.filteredItems;
                  if (filteredItems.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        icon: Icon(Symbols.filter_alt_off),
                        text: Text(
                          'Nessun contributo corrisponde al filtro '
                          'selezionato',
                        ),
                      ),
                    );
                  }

                  return SliverList.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          index == 0 ? 16 : 0,
                          16,
                          index == filteredItems.length - 1 ? 16 : 8,
                        ),
                        child: AdminSubmissionListItem(
                          summary: item,
                          onTap: () => _openEditor(submissionId: item.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        foregroundColor: context.colorScheme.onTertiaryContainer,
        backgroundColor: context.colorScheme.tertiaryContainer,
        icon: const Icon(Symbols.add),
        label: const Text('Nuovo contributo'),
      ),
    );
  }
}
