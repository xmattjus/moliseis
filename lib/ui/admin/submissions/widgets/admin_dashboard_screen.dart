import 'dart:async' show unawaited;

import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_list_item.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';

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

  bool _owns(AdminSubmissionsViewModel owner) {
    if (!mounted) return false;
    if (!identical(widget.viewModel, owner) || owner.isDisposed) return false;
    final provided = context.read<AdminSubmissionsViewModel?>();
    return provided == null || identical(provided, owner);
  }

  Future<void> _openEditor(
    AdminSubmissionsViewModel owner, {
    int? submissionId,
    bool pending = false,
  }) async {
    if (!mounted) return;
    if (!_owns(owner)) return;
    if (pending &&
        (!owner.canOpenPendingSubmission ||
            owner.unignoredPendingId != submissionId)) {
      return;
    }
    final router = GoRouter.of(context);
    final changed = submissionId == null
        ? await router.pushNamed<bool>(RouteNames.adminSubmissionNew)
        : await router.pushNamed<bool>(
            RouteNames.adminSubmissionEditor,
            pathParameters: <String, String>{'id': submissionId.toString()},
          );
    if (!mounted) return;
    if (changed != true || !_owns(owner)) return;
    await owner.refreshAfterEditorChange();
  }

  Future<void> _refreshSubmissions(AdminSubmissionsViewModel owner) {
    if (!mounted) return Future<void>.value();
    if (!_owns(owner)) return Future<void>.value();
    return owner.refreshSubmissions();
  }

  Future<void> _refreshIgnoredSources(AdminSubmissionsViewModel owner) {
    if (!mounted) return Future<void>.value();
    if (!_owns(owner)) return Future<void>.value();
    return owner.refreshIgnoredSources();
  }

  Future<void> _refreshVisible(AdminSubmissionsViewModel owner) {
    if (!mounted) return Future<void>.value();
    if (!_owns(owner)) return Future<void>.value();
    return owner.showIgnored
        ? owner.refreshIgnoredSources()
        : owner.refreshSubmissions();
  }

  void _logout(AdminAuthViewModel auth, AdminSubmissionsViewModel owner) {
    if (!mounted) return;
    if (!_owns(owner) || !identical(widget.authViewModel, auth)) return;
    final provided = context.read<AdminAuthViewModel?>();
    if (provided != null && !identical(provided, auth)) return;
    final router = GoRouter.of(context);
    final route = ModalRoute.of(context);
    if (route?.isCurrent == false) return;
    final location = router.state.uri;
    if (!auth.requestLogout()) return;
    // Admission notifications may reenter routing or replace either owner.
    if (!mounted) return;
    if (!_owns(owner) ||
        auth.isDisposed ||
        !identical(widget.authViewModel, auth) ||
        route?.isCurrent == false ||
        router.state.uri != location) {
      return;
    }
    final currentAuth = context.read<AdminAuthViewModel?>();
    if (currentAuth != null && !identical(currentAuth, auth)) return;
    router.go(RoutePaths.home);
  }

  Widget _actions(
    BuildContext context,
    AdminSubmissionsViewModel owner,
    AdminAuthViewModel auth,
  ) {
    void refresh() => unawaited(_refreshVisible(owner));
    final logout = auth.canLogout ? () => _logout(auth, owner) : null;
    if (context.windowSizeClass.isCompact) {
      return MenuAnchor(
        menuChildren: [
          MenuItemButton(
            onPressed: refresh,
            leadingIcon: const Icon(Symbols.sync, weight: 500),
            child: const Text('Aggiorna'),
          ),
          MenuItemButton(
            onPressed: logout,
            leadingIcon: const Icon(Symbols.logout),
            child: const Text('Logout'),
          ),
        ],
        builder: (_, controller, _) => IconButton(
          onPressed: () {
            if (!mounted) return;
            if (!_owns(owner)) return;
            controller.isOpen ? controller.close() : controller.open();
          },
          tooltip: 'Altro',
          icon: const Icon(Symbols.more_vert, weight: 900),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: refresh,
          tooltip: 'Aggiorna i contenuti',
          icon: const Icon(Symbols.sync, weight: 500),
        ),
        IconButton(
          onPressed: logout,
          tooltip: 'Esegui il logout',
          icon: const Icon(Symbols.logout),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return Scaffold(
      body: RefreshIndicator(
        displacement: 64,
        edgeOffset: 106,
        onRefresh: () => _refreshVisible(viewModel),
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
                    ListenableBuilder(
                      listenable: widget.authViewModel,
                      builder: (context, _) =>
                          _actions(context, viewModel, widget.authViewModel),
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
                            isSelected: [
                              ..._filters.map(
                                (status) =>
                                    !viewModel.showIgnored &&
                                    viewModel.filter == status,
                              ),
                              viewModel.showIgnored,
                            ],
                            onPressed: (index) {
                              if (!mounted) return;
                              if (!_owns(viewModel)) return;
                              if (index == _filters.length) {
                                viewModel.setIgnoredFilter();
                                unawaited(_refreshIgnoredSources(viewModel));
                              } else {
                                viewModel.setFilter(_filters[index]);
                              }
                            },
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
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Fonti ignorate'),
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
                listenable: viewModel,
                builder: (context, _) {
                  if (viewModel.showIgnored) {
                    if (viewModel.loadIgnoredSnapshot.isRunning &&
                        viewModel.ignoredSources.isEmpty) {
                      return const SliverFillRemaining(
                        child: EmptyView.loading(
                          text: Text('Caricamento fonti ignorate...'),
                        ),
                      );
                    }
                    return SliverList.list(
                      children: [
                        // Keep the action below the pinned filter.
                        const SizedBox(height: kToolbarHeight + 16),
                        if (viewModel.loadIgnoredSnapshot.hasFailure)
                          ListTile(
                            title: const Text(
                              'Impossibile caricare le fonti ignorate',
                            ),
                            trailing: TextButton(
                              onPressed: () =>
                                  _refreshIgnoredSources(viewModel),
                              child: const Text('Riprova'),
                            ),
                          ),
                        if (viewModel.unIgnoreSnapshot.hasFailure)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Impossibile riattivare la fonte. Riprova.',
                            ),
                          ),
                        if (viewModel.unIgnoreSnapshot.completed)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Fonte riattivata'),
                          ),
                        if (viewModel.unignoredPendingId case final pending?
                            when viewModel.canOpenPendingSubmission)
                          TextButton(
                            onPressed: () => _openEditor(
                              viewModel,
                              submissionId: pending,
                              pending: true,
                            ),
                            child: const Text('Apri revisione in attesa'),
                          ),
                        if (viewModel.ignoredSources.isEmpty &&
                            !viewModel.loadIgnoredSnapshot.hasFailure)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Nessuna fonte ignorata'),
                          ),
                        for (final source in viewModel.ignoredSources)
                          ListTile(
                            key: ValueKey('admin_ignored_source_${source.id}'),
                            title: Text(source.name),
                            subtitle: Text(
                              [
                                source.provider,
                                source.externalId,
                                if (source.occurrenceKey != null)
                                  source.occurrenceKey,
                                source.ignoredAt,
                              ].join(' · '),
                            ),
                            trailing: TextButton(
                              onPressed: viewModel.canUnIgnore
                                  ? () {
                                      if (!mounted) return;
                                      if (!_owns(viewModel)) return;
                                      viewModel.requestUnIgnore(source.id);
                                    }
                                  : null,
                              child: const Text('Riattiva fonte'),
                            ),
                          ),
                      ],
                    );
                  }
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
                            onPressed: () => _refreshSubmissions(viewModel),
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
                          onTap: () =>
                              _openEditor(viewModel, submissionId: item.id),
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
        onPressed: () => _openEditor(viewModel),
        foregroundColor: context.colorScheme.onTertiaryContainer,
        backgroundColor: context.colorScheme.tertiaryContainer,
        icon: const Icon(Symbols.add),
        label: const Text('Nuovo contributo'),
      ),
    );
  }
}
