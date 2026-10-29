import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
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
    super.key,
  });

  final AdminSubmissionEditorViewModel viewModel;
  final AdminAuthViewModel auth;
  final int? submissionId;
  final String? sessionId;

  /// Optional observer route sharing the same activation binding.
  final Widget? child;

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

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_authChanged);
    widget.viewModel.addListener(_ownerChanged);
  }

  @override
  void didUpdateWidget(covariant AdminSubmissionEditorRoute oldWidget) {
    if (oldWidget.submissionId != widget.submissionId ||
        oldWidget.sessionId != widget.sessionId ||
        !identical(oldWidget.viewModel, widget.viewModel)) {
      // Reused route State must not carry A's resume hint into target B.
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      return;
    }
    setState(() => _ready = false);
    if (ModalRoute.of(context)?.isCurrent == true) _queueRebind();
  }

  void _authChanged() {
    if (!mounted) return;
    unawaited(_activate());
  }

  Future<void> _activate() async {
    if (!mounted) return;
    final owner = widget.viewModel;
    final auth = widget.auth;
    final account = auth.isAdmin ? auth.currentUser?.id : null;
    final target = widget.submissionId;
    final session = widget.sessionId ?? _restoredSession.value;
    final binding = ++_binding;
    _ready = false;
    _error = null;
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
    widget.auth.removeListener(_authChanged);
    widget.viewModel.removeListener(_ownerChanged);
    _restoredSession.dispose();
    super.dispose();
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
    return widget.child ??
        AdminSubmissionEditorScreen(viewModel: widget.viewModel);
  }
}
