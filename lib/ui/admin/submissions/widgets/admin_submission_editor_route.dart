import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/routing/admin_submission_exit_policy.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/result.dart';

/// Binds a restorable route to the application-owned private Admin session.
///
/// Rebuilding this binding never admits a Save or picker operation.
class AdminSubmissionEditorRoute extends StatefulWidget {
  /// Selects a target, or resumes its stable local [sessionId] after adoption.
  const AdminSubmissionEditorRoute({
    required this.viewModel,
    required this.auth,
    this.submissionId,
    this.sessionId,
    this.child,
    this.exitPolicy,
    this.exitLocation,
    super.key,
  });

  final AdminSubmissionEditorViewModel viewModel;
  final AdminAuthViewModel auth;
  final int? submissionId;
  final String? sessionId;

  /// Optional observer route sharing the same activation binding.
  final Widget? child;

  /// Router-owned exit arbitration; absent for isolated presentations.
  final AdminSubmissionExitPolicy? exitPolicy;

  /// Concrete source supplied by the router builder before async restoration.
  final String? exitLocation;

  @override
  State<AdminSubmissionEditorRoute> createState() =>
      _AdminSubmissionEditorRouteState();
}

class _AdminSubmissionEditorRouteState extends State<AdminSubmissionEditorRoute>
    with RestorationMixin {
  final _restoredSession = RestorableStringN(null);

  @override
  String get restorationId => 'admin_editor_${widget.submissionId ?? 'new'}';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restoredSession, 'session');
    unawaited(_activate());
  }

  var _binding = 0;
  var _ready = false;
  Exception? _error;
  AdminDraftActivation? _activation;
  var _rebindQueued = false;
  AdminEditorExitVisit? _exitVisit;
  AdminSubmissionExitPolicy? _exitPolicy;
  ModalRoute<dynamic>? _editorRoute;
  var _allowExplicitPop = false;
  ModalRoute<dynamic>? _registeredProgress;

  @override
  void initState() {
    super.initState();
    _exitPolicy = widget.exitPolicy;
    widget.auth.addListener(_authChanged);
    widget.viewModel.addListener(_ownerChanged);
  }

  @override
  void didUpdateWidget(covariant AdminSubmissionEditorRoute oldWidget) {
    if (!identical(oldWidget.exitPolicy, widget.exitPolicy)) {
      final visit = _exitVisit;
      if (visit != null) _exitPolicy?.unregister(visit);
      _exitVisit = null;
      _exitPolicy = widget.exitPolicy;
    }
    if (oldWidget.submissionId != widget.submissionId ||
        oldWidget.sessionId != widget.sessionId ||
        !identical(oldWidget.viewModel, widget.viewModel)) {
      // Reused route State must not carry A's resume hint into target B.
      _allowExplicitPop = false;
      _restoredSession.value = null;
      _activation = null;
      _ready = false;
    }
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.auth, widget.auth)) {
      oldWidget.auth.removeListener(_authChanged);
      widget.auth.addListener(_authChanged);
    }
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      oldWidget.viewModel.removeListener(_ownerChanged);
      widget.viewModel.addListener(_ownerChanged);
    }
    if (!identical(oldWidget.viewModel, widget.viewModel) ||
        oldWidget.submissionId != widget.submissionId ||
        oldWidget.sessionId != widget.sessionId ||
        !identical(oldWidget.auth, widget.auth)) {
      unawaited(_activate());
    }
    _syncExitVisit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _editorRoute = ModalRoute.of(context);
    _syncExitVisit();
    if (!_ready &&
        _activation != null &&
        ModalRoute.of(context)?.isCurrent == true) {
      _queueRebind();
    }
  }

  void _queueRebind() {
    if (_rebindQueued) return;
    _rebindQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebindQueued = false;
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent == true) unawaited(_activate());
    });
  }

  void _ownerChanged() {
    if (!mounted || !_ready) return;
    final owner = widget.viewModel;
    if (owner.isActivationCurrent(_activation)) {
      if (owner.hasDurableDraft) _restoredSession.value = owner.sessionId;
      _syncExitVisit();
      return;
    }
    final next = owner.activation;
    final old = _activation;
    if (old != null &&
        next != null &&
        old.owner.submissionId == null &&
        next.owner.submissionId != null &&
        old.owner.accountId == next.owner.accountId &&
        old.owner.sessionId == next.owner.sessionId) {
      _activation = next;
      if (owner.hasDurableDraft) _restoredSession.value = owner.sessionId;
      _syncExitVisit();
      return;
    }
    setState(() => _ready = false);
    _syncExitVisit();
    if (ModalRoute.of(context)?.isCurrent == true) _queueRebind();
  }

  void _authChanged() {
    if (!mounted) return;
    unawaited(_activate());
  }

  Future<void> _activate() async {
    if (!mounted) return;
    _allowExplicitPop = false;
    final owner = widget.viewModel;
    final auth = widget.auth;
    final account = auth.isAdmin ? auth.currentUser?.id : null;
    final target = widget.submissionId;
    final session = widget.sessionId ?? _restoredSession.value;
    final binding = ++_binding;
    _ready = false;
    _error = null;
    _syncExitVisit();
    if (account == null) {
      setState(() {});
      return;
    }
    final result = await owner.activate(
      accountId: account,
      submissionId: target,
      sessionId: session,
      creatorName: auth.displayName ?? auth.email,
      creatorEmail: auth.email,
    );
    if (!mounted) return;
    if (binding != _binding ||
        !auth.isAdmin ||
        auth.currentUser?.id != account) {
      return;
    }
    setState(() {
      _ready = result is Success<void>;
      if (_ready) _activation = owner.activation;
      _error = result is Error<void> ? result.error : null;
    });
    _syncExitVisit();
    if (_ready && owner.isEditMode && !owner.hasLoadedDetail) {
      owner.requestLoad(activation: owner.activation);
    }
    if (_ready && owner.hasDurableDraft) {
      _restoredSession.value = owner.sessionId;
    }
  }

  @override
  void dispose() {
    _binding++;
    final visit = _exitVisit;
    if (visit != null) _exitPolicy?.unregister(visit);
    final progress = _registeredProgress;
    if (progress != null) _exitPolicy?.unregisterProgress(progress);
    widget.auth.removeListener(_authChanged);
    widget.viewModel.removeListener(_ownerChanged);
    _restoredSession.dispose();
    super.dispose();
  }

  /// Binds actual page handles, independently from the root router context.
  void _syncExitVisit() {
    if (!mounted) return;
    final policy = _exitPolicy;
    final route = _editorRoute;
    final activation = _activation;
    final location = widget.exitLocation;
    if (policy == null) return;
    if (widget.child != null) {
      if (_ready &&
          route != null &&
          activation != null &&
          widget.viewModel.isActivationCurrent(activation)) {
        _registeredProgress = route;
        policy.registerProgress(route, widget.viewModel);
      }
      return;
    }
    if (!_ready ||
        widget.child != null ||
        route == null ||
        activation == null ||
        location == null ||
        !widget.viewModel.isActivationCurrent(activation)) {
      final old = _exitVisit;
      if (old != null) policy.unregister(old);
      _exitVisit = null;
      return;
    }
    _exitVisit = policy.register(
      context,
      route,
      widget.viewModel,
      activation,
      location,
    );
  }

  /// Explicit iOS Back initiates router policy without enabling native swipe.
  void _requestBack(
    AdminSubmissionEditorViewModel owner,
    AdminDraftActivation? activation,
    ModalRoute<dynamic>? route,
  ) {
    if (!mounted) return;
    if (!identical(widget.viewModel, owner) ||
        !identical(_editorRoute, route)) {
      return;
    }
    final router = GoRouter.of(context);
    if (route?.isCurrent != true ||
        !owner.isActivationCurrent(activation) ||
        owner.exitDecisionPending) {
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        !owner.hasUncheckpointedChanges) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.goNamed(RouteNames.adminDashboard);
      }
      return;
    }
    setState(() => _allowExplicitPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!identical(widget.viewModel, owner) ||
          !identical(_editorRoute, route) ||
          !owner.isActivationCurrent(activation)) {
        return;
      }
      if (route?.isCurrent == true && owner.isActivationCurrent(activation)) {
        if (router.canPop()) {
          router.pop();
        } else {
          router.goNamed(RouteNames.adminDashboard);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!identical(widget.viewModel, owner) ||
            !identical(_editorRoute, route) ||
            !owner.isActivationCurrent(activation)) {
          return;
        }
        setState(() => _allowExplicitPop = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.viewModel;
    final auth = widget.auth;
    final active = owner.activation;
    final canReturn =
        active != null &&
        auth.isAdmin &&
        auth.currentUser?.id == active.owner.accountId &&
        owner.isActivationCurrent(active);
    if (!_ready) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const EmptyView.loading(text: Text('Apertura editor...'))
            : EmptyView.error(
                text: Text(
                  canReturn && owner.pendingRecoveryCheckpoint
                      ? 'Salva nella bozza locale i campi remoti '
                            'accettati prima di aprire un altro contributo.'
                      : 'Impossibile aprire il contributo. '
                            'Il lavoro locale è conservato.',
                ),
                action: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => unawaited(_activate()),
                      child: const Text('Riprova'),
                    ),
                    if (canReturn)
                      TextButton(
                        key: const ValueKey('admin_return_active_editor'),
                        onPressed: () {
                          if (!mounted) return;
                          if (!identical(widget.viewModel, owner) ||
                              !identical(widget.auth, auth) ||
                              !auth.isAdmin ||
                              auth.currentUser?.id != active.owner.accountId ||
                              !owner.isActivationCurrent(active)) {
                            return;
                          }
                          final id = active.owner.submissionId;
                          context.goNamed(
                            id == null
                                ? RouteNames.adminSubmissionNew
                                : RouteNames.adminSubmissionEditor,
                            pathParameters: {if (id != null) 'id': '$id'},
                            queryParameters: {
                              'session': active.owner.sessionId,
                            },
                          );
                        },
                        child: const Text('Torna all’editor corrente'),
                      ),
                  ],
                ),
              ),
      );
    }
    if (widget.child case final child?) return child;
    final backActivation = _activation;
    final backRoute = _editorRoute;
    void requestBack() => _requestBack(owner, backActivation, backRoute);
    return ListenableBuilder(
      listenable: owner,
      builder: (context, _) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): requestBack,
        },
        child: PopScope<Object?>(
          canPop:
              defaultTargetPlatform != TargetPlatform.iOS ||
              !(owner.hasUncheckpointedChanges || owner.exitDecisionPending) ||
              _allowExplicitPop,
          child: AdminSubmissionEditorScreen(
            viewModel: owner,
            onBack: requestBack,
            onModerationClose: (activation, lane, execution) {
              if (!mounted) return false;
              final visit = _exitVisit;
              return visit != null &&
                  (_exitPolicy?.closeAfterModeration(
                        visit,
                        activation,
                        lane,
                        execution,
                      ) ??
                      false);
            },
          ),
        ),
      ),
    );
  }
}
