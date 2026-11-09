import 'dart:async' show unawaited;

import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_status.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submissions_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_list_item.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';

/// Moderation dashboard for loading, filtering, and opening submissions.
class AdminDashboardScreen extends StatefulWidget {
  /// Creates the staff dashboard with its submissions and authentication state.
  const AdminDashboardScreen({
    required this.viewModel,
    required this.authViewModel,
    this.draftRepository,
    super.key,
  });

  /// The dashboard list state.
  final AdminSubmissionsViewModel viewModel;

  /// The staff session state used to log out.
  final AdminAuthViewModel authViewModel;

  /// Private, account-checked Android editor navigation resume lookup.
  final AdminSubmissionDraftRepository? draftRepository;

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

  GoRouter? _router;
  ModalRoute<dynamic>? _route;
  AdminAuthViewModel? _auth;
  AdminSubmissionsViewModel? _owner;
  Object? _providedOwner;
  Object? _providedAuth;
  Object? _providedEditor;
  String? _account;
  bool _admin = false;
  bool _current = false;
  Uri? _location;
  bool _backRequested = false;
  int _visit = 0;
  int _presentation = 0;
  int _routeGeneration = 0;
  int _lookup = 0;
  bool _lookupScheduled = false;
  (bool, AdminSubmissionStatus?)? _selection;
  Object? _toolbarRefresh;
  Object? _manualRefresh;
  Object? _recoveryAttempt;
  Object? _editorAttempt;
  VoidCallback? _cancelRecovery;
  _RecoveryIdentity? _candidate;
  final _suppressed = <_RecoveryIdentity>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    final route = ModalRoute.of(context);
    final providedOwner = Provider.of<AdminSubmissionsViewModel?>(context);
    final providedAuth = Provider.of<AdminAuthViewModel?>(context);
    final providedEditor = Provider.of<AdminSubmissionEditorViewModel?>(
      context,
    );
    final changed =
        !identical(_owner, widget.viewModel) ||
        !identical(_auth, widget.authViewModel) ||
        !identical(_router, router) ||
        !identical(_route, route) ||
        !identical(_providedOwner, providedOwner) ||
        !identical(_providedAuth, providedAuth) ||
        !identical(_providedEditor, providedEditor);
    if (changed) {
      _unbind();
      _owner = widget.viewModel;
      _auth = widget.authViewModel;
      _providedOwner = providedOwner;
      _providedAuth = providedAuth;
      _providedEditor = providedEditor;
      _router = router;
      _route = route;
      _owner!.addListener(_onSelection);
      _auth!.addListener(_onAuth);
      router.routerDelegate.addListener(_onRoute);
      _resetVisit();
    }
    _onRoute();
  }

  @override
  void didUpdateWidget(AdminDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.draftRepository, widget.draftRepository) ||
        !identical(oldWidget.viewModel, widget.viewModel) ||
        !identical(oldWidget.authViewModel, widget.authViewModel)) {
      _unbind();
      _owner = widget.viewModel;
      _auth = widget.authViewModel;
      _owner!.addListener(_onSelection);
      _auth!.addListener(_onAuth);
      _router?.routerDelegate.addListener(_onRoute);
      _resetVisit();
      _scheduleLookup();
    }
  }

  void _unbind() {
    _owner?.removeListener(_onSelection);
    _auth?.removeListener(_onAuth);
    _router?.routerDelegate.removeListener(_onRoute);
  }

  void _retireRecovery() {
    _cancelRecovery?.call();
    _cancelRecovery = null;
    _candidate = null;
  }

  void _revokePresentation() {
    _presentation++;
    _lookup++;
    _toolbarRefresh = null;
    _manualRefresh = null;
    _retireRecovery();
  }

  void _resetVisit() {
    _visit++;
    _revokePresentation();
    _recoveryAttempt = null;
    _editorAttempt = null;
    _suppressed.clear();
    _backRequested = false;
    _account = _auth?.currentUser?.id;
    _admin = _auth?.isAdmin ?? false;
    _selection = (_owner!.showIgnored, _owner!.filter);
  }

  void _onAuth() {
    if (!mounted) return;
    final auth = _auth!;
    if (_account == auth.currentUser?.id &&
        _admin == auth.isAdmin &&
        !auth.isDisposed) {
      return;
    }
    _resetVisit();
    _scheduleLookup();
    setState(() {});
  }

  void _onSelection() {
    if (!mounted) return;
    final selection = (_owner!.showIgnored, _owner!.filter);
    if (selection == _selection && !_owner!.isDisposed) return;
    _selection = selection;
    // Selection revokes refresh feedback independently of draft eligibility.
    _presentation++;
    _toolbarRefresh = null;
    _manualRefresh = null;
    setState(() {});
  }

  void _onRoute() {
    if (!mounted) return;
    final current = _route?.isCurrent ?? true;
    final location = _router?.routerDelegate.currentConfiguration.uri;
    if (current == _current && location == _location) return;
    _current = current;
    _location = location;
    if (!current && !identical(_editorAttempt, _recoveryAttempt)) {
      _recoveryAttempt = null;
    }
    _routeGeneration++;
    _revokePresentation();
    if (current) {
      _backRequested = false;
      if (_recoveryAttempt == null) _scheduleLookup();
    }
    // Defer rebuilds because router notifications can arrive during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  _DashboardAuthority? _capture() {
    if (!mounted) return null;
    final auth = widget.authViewModel;
    if (_router!.routerDelegate.currentConfiguration.isEmpty ||
        !_owns(widget.viewModel) ||
        auth.isDisposed ||
        !auth.isAdmin ||
        auth.currentUser?.id == null ||
        _route?.isCurrent == false ||
        !identical(_auth, auth)) {
      return null;
    }
    final provided = context.read<AdminAuthViewModel?>();
    if (provided != null && !identical(provided, auth)) return null;
    return _DashboardAuthority(
      owner: widget.viewModel,
      auth: auth,
      drafts: widget.draftRepository,
      router: _router!,
      route: _route,
      location: _router!.routerDelegate.currentConfiguration.uri,
      account: auth.currentUser!.id,
      visit: _visit,
      routeGeneration: _routeGeneration,
      snackBarClearToken: appSnackBarClearToken,
      presentation: _presentation,
    );
  }

  bool _live(_DashboardAuthority authority, {bool presentation = true}) {
    if (!mounted) return false;
    return _visit == authority.visit &&
        _routeGeneration == authority.routeGeneration &&
        (!presentation || _presentation == authority.presentation) &&
        identical(widget.authViewModel, authority.auth) &&
        identical(widget.draftRepository, authority.drafts) &&
        identical(_router, authority.router) &&
        authority.router.routerDelegate.currentConfiguration.isNotEmpty &&
        authority.router.routerDelegate.currentConfiguration.uri ==
            authority.location &&
        identical(_route, authority.route) &&
        authority.route?.isCurrent != false &&
        !authority.auth.isDisposed &&
        authority.auth.isAdmin &&
        authority.auth.currentUser?.id == authority.account &&
        _owns(authority.owner) &&
        (context.read<AdminAuthViewModel?>() == null ||
            identical(context.read<AdminAuthViewModel?>(), authority.auth));
  }

  /// Explicit root Back falls home; system Back retains platform root behavior.
  void _back(_DashboardAuthority? authority) {
    if (authority == null || !_live(authority) || _backRequested) return;
    _backRequested = true;
    _revokePresentation();
    authority.router.canPop()
        ? authority.router.pop()
        : authority.router.go(RoutePaths.home);
  }

  void _scheduleLookup() {
    if (_lookupScheduled) return;
    _lookupScheduled = true;
    final clearToken = appSnackBarClearToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lookupScheduled = false;
      if (!mounted) return;
      if (!identical(clearToken, appSnackBarClearToken)) return;
      final authority = _capture();
      if (authority != null && _recoveryAttempt == null) {
        unawaited(_lookupRecovery(authority));
      }
    });
  }

  _RecoveryIdentity? _identity(AdminSubmissionDraft? draft, String account) {
    if (draft == null ||
        draft.owner.accountId != account ||
        draft.navigationIntent == null) {
      return null;
    }
    return (owner: draft.owner, nonce: draft.navigationIntent!.requestNonce);
  }

  Future<void> _lookupRecovery(_DashboardAuthority authority) async {
    final drafts = authority.drafts;
    if (drafts == null) return;
    final revision = ++_lookup;
    final result = await drafts.loadNavigationDraft(
      accountId: authority.account,
    );
    if (!mounted) return;
    if (!_live(authority, presentation: false) ||
        revision != _lookup ||
        !identical(authority.snackBarClearToken, appSnackBarClearToken) ||
        _recoveryAttempt != null) {
      return;
    }
    final identity = result is Success<AdminSubmissionDraft?>
        ? _identity(result.value, authority.account)
        : null;
    _retireRecovery();
    _presentRecovery(authority, identity);
  }

  void _presentRecovery(
    _DashboardAuthority authority,
    _RecoveryIdentity? identity,
  ) {
    if (!identical(authority.snackBarClearToken, appSnackBarClearToken)) return;
    if (identity == null || _suppressed.contains(identity)) {
      _retireRecovery();
      return;
    }
    if (_candidate == identity && _cancelRecovery != null) return;
    _retireRecovery();
    _candidate = identity;
    _cancelRecovery = showPersistentSnackBar(
      context: context,
      textContent: 'Hai una modifica interrotta da recuperare.',
      actionLabel: 'Riprendi',
      onActionPressed: () => unawaited(_resumeCandidate(authority, identity)),
      onDismissed: () {
        if (!mounted) return;
        if (!_live(authority, presentation: false) || _candidate != identity) {
          return;
        }
        _suppressed.add(identity);
        _cancelRecovery = null;
        _candidate = null;
      },
      revalidate: () async {
        if (!_live(authority, presentation: false) ||
            _candidate != identity ||
            _recoveryAttempt != null) {
          return false;
        }
        final revision = ++_lookup;
        final result = await authority.drafts!.loadNavigationDraft(
          accountId: authority.account,
        );
        if (!mounted) return false;
        if (!_live(authority, presentation: false) ||
            revision != _lookup ||
            _candidate != identity ||
            _recoveryAttempt != null) {
          return false;
        }
        final fresh = result is Success<AdminSubmissionDraft?>
            ? _identity(result.value, authority.account)
            : null;
        if (fresh != identity) {
          _retireRecovery();
          if (fresh != null) _presentRecovery(authority, fresh);
          return false;
        }
        return !_suppressed.contains(identity);
      },
    );
  }

  Future<void> _resumeCandidate(
    _DashboardAuthority authority,
    _RecoveryIdentity identity,
  ) async {
    if (!mounted) return;
    if (!_live(authority, presentation: false) ||
        _candidate != identity ||
        _recoveryAttempt != null) {
      return;
    }
    final attempt = Object();
    _recoveryAttempt = attempt;
    _lookup++;
    _retireRecovery();
    final editor = context.read<AdminSubmissionEditorViewModel?>();
    final result = await authority.drafts!.loadNavigationDraft(
      accountId: authority.account,
    );
    if (!mounted) return;
    if (!_live(authority, presentation: false) ||
        !identical(_recoveryAttempt, attempt)) {
      return;
    }
    final fresh = result is Success<AdminSubmissionDraft?>
        ? _identity(result.value, authority.account)
        : null;
    if (fresh != identity) {
      _recoveryAttempt = null;
      showSnackBarGenericError(context: context);
      if (fresh != null) _presentRecovery(authority, fresh);
      return;
    }
    final target = identity.owner.submissionId;
    _editorAttempt = attempt;
    await authority.router.pushNamed<Object?>(
      target == null
          ? RouteNames.adminSubmissionNew
          : RouteNames.adminSubmissionEditor,
      pathParameters: target == null ? const {} : {'id': '$target'},
      queryParameters: {'session': identity.owner.sessionId},
    );
    // Push completion precedes the dashboard route becoming current.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (_visit != authority.visit || !identical(_recoveryAttempt, attempt)) {
      return;
    }
    _editorAttempt = null;
    final returned = _capture();
    if (returned == null) {
      _recoveryAttempt = null;
      return;
    }
    // Recovery eligibility must not delay the existing best-effort list read.
    unawaited(authority.owner.refreshAfterEditorChange());
    final rechecked = await authority.drafts!.loadNavigationDraft(
      accountId: authority.account,
    );
    if (!mounted) return;
    if (!_live(returned, presentation: false) ||
        !identical(_recoveryAttempt, attempt)) {
      return;
    }
    final remaining = rechecked is Success<AdminSubmissionDraft?>
        ? _identity(rechecked.value, authority.account)
        : null;
    final activation = editor?.activation;
    if (remaining == identity &&
        editor != null &&
        identical(context.read<AdminSubmissionEditorViewModel?>(), editor) &&
        activation?.owner == identity.owner &&
        editor.isActivationCurrent(activation)) {
      _suppressed.add(identity);
    }
    _recoveryAttempt = null;
    _presentRecovery(returned, remaining);
  }

  @override
  void dispose() {
    _unbind();
    _visit++;
    _revokePresentation();
    super.dispose();
  }

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
    final auth = widget.authViewModel;
    final visit = _visit;
    final accountId = auth.currentUser?.id;
    final wasAdmin = auth.isAdmin;
    submissionId == null
        ? await router.pushNamed<bool>(RouteNames.adminSubmissionNew)
        : await router.pushNamed<bool>(
            RouteNames.adminSubmissionEditor,
            pathParameters: <String, String>{'id': submissionId.toString()},
          );
    if (!mounted) return;
    if (!_owns(owner) ||
        _visit != visit ||
        !identical(widget.authViewModel, auth) ||
        auth.isDisposed ||
        auth.isAdmin != wasAdmin ||
        auth.currentUser?.id != accountId) {
      return;
    }
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

  Future<void> _refreshVisible(
    AdminSubmissionsViewModel owner, {
    bool toolbar = false,
  }) async {
    if (!mounted) return;
    final authority = _capture();
    if (authority == null || !identical(authority.owner, owner)) return;
    final operation = owner.startSelectedLaneRefresh();
    if (operation == null) return;
    _scheduleLookup();
    final progress = Object();
    if (_live(authority)) {
      setState(() {
        _manualRefresh = progress;
        if (toolbar) _toolbarRefresh = progress;
      });
    }
    final outcome = await operation.settled;
    if (!mounted) return;
    if (!_live(authority)) return;
    if (identical(_manualRefresh, progress)) {
      setState(() {
        _manualRefresh = null;
        if (identical(_toolbarRefresh, progress)) _toolbarRefresh = null;
      });
    }
    if (outcome.outcome == AdminDashboardRefreshOutcome.expectedFailure ||
        outcome.outcome == AdminDashboardRefreshOutcome.unexpectedFailure) {
      showSnackBar(
        context: context,
        textContent:
            "Si è verificato un errore durante l'aggiornamento dei contenuti",
        type: SnackBarType.error,
      );
    }
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
    _resetVisit();
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

  VoidCallback _backCallback() {
    final authority = _capture();
    return () => _back(authority);
  }

  Widget _actions(
    BuildContext context,
    AdminSubmissionsViewModel owner,
    AdminAuthViewModel auth,
  ) {
    final refresh = owner.canRefreshSelectedLane
        ? () => unawaited(_refreshVisible(owner, toolbar: true))
        : null;
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
        child: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, _) {
                return [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverAppBar(
                      title: const Text('Area redazione'),
                      leading: CustomBackButton(onPressed: _backCallback()),
                      actions: <Widget>[
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            widget.authViewModel,
                            viewModel,
                          ]),
                          builder: (context, _) => _actions(
                            context,
                            viewModel,
                            widget.authViewModel,
                          ),
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
                                borderRadius:
                                    context.appShapes.circular.cornerFull,
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
                                    unawaited(
                                      _refreshIgnoredSources(viewModel),
                                    );
                                  } else {
                                    viewModel.setFilter(_filters[index]);
                                  }
                                },
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Tutti'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Da revisionare'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Accettati'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Rifiutati'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
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
                            viewModel.ignoredSources.isEmpty &&
                            _manualRefresh == null) {
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
                                key: ValueKey(
                                  'admin_ignored_source_${source.id}',
                                ),
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
                      if (viewModel.loading &&
                          !viewModel.hasData &&
                          _manualRefresh == null) {
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
                            text: const Text(
                              'Impossibile caricare i contributi',
                            ),
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
            if (_toolbarRefresh != null)
              const Positioned(
                top: 112,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: LimitedBox(
                    maxHeight: 240,
                    child: SingleChildScrollView(
                      child: EmptyView.loading(
                        text: Text('Aggiornamento in corso...'),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

typedef _RecoveryIdentity = ({AdminDraftOwner owner, String nonce});

/// Captured publication authority; physical reads keep their own lifetime.
final class _DashboardAuthority {
  const _DashboardAuthority({
    required this.owner,
    required this.auth,
    required this.drafts,
    required this.router,
    required this.route,
    required this.location,
    required this.account,
    required this.visit,
    required this.routeGeneration,
    required this.snackBarClearToken,
    required this.presentation,
  });
  final AdminSubmissionsViewModel owner;
  final AdminAuthViewModel auth;
  final AdminSubmissionDraftRepository? drafts;
  final GoRouter router;
  final ModalRoute<dynamic>? route;
  final Uri location;
  final String account;
  final int visit;
  final int routeGeneration;
  final Object snackBarClearToken;
  final int presentation;
}
