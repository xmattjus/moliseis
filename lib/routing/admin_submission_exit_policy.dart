import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/domain/use_cases/admin_draft_session.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:provider/provider.dart';

/// One registered editor page visit, distinct from its retained draft session.
final class AdminEditorExitVisit {
  /// Captures handles from an initialized editor binding, before any await.
  AdminEditorExitVisit(
    this.context,
    this.route,
    this.owner,
    this.activation,
    this.matchedLocation,
  );

  /// Context of the actual editor binding, never the root onExit context.
  final BuildContext context;

  /// Exact page protected by this visit.
  final ModalRoute<dynamic> route;

  /// Application-owned editor used by this page.
  final AdminSubmissionEditorViewModel owner;

  /// Authority established when this visit was bound.
  final AdminDraftActivation activation;

  /// Concrete target location, independent of a reused route-pattern page key.
  final String matchedLocation;

  /// GoRouter assigns a distinct page key to each imperative editor visit.
  LocalKey? get pageKey =>
      route.settings is Page ? (route.settings as Page<dynamic>).key : null;
}

/// Admin-only presentation arbitration for the existing router and draft owner.
///
/// Results belong to individual router invocations. This object never owns a
/// draft, starts remote work, or transfers affirmative permission to a retry.
final class AdminSubmissionExitPolicy {
  /// Uses the router's existing synchronous authentication authority.
  AdminSubmissionExitPolicy(this.auth);

  /// Existing account authority; no additional authentication lifecycle owner.
  final AdminAuthViewModel auth;
  AdminEditorExitVisit? _visit;
  Object? _pending;
  VoidCallback? _releaseReservation;
  VoidCallback? _revokePresentation;
  ModalRoute<dynamic>? _progressRoute;
  AdminSubmissionEditorViewModel? _progressOwner;
  DialogRoute<UnsavedChangesDecision>? _dialog;
  AdminEditorExitVisit? _moderationClose;

  /// Registers only editor pages; Progress retains its separate pop policy.
  AdminEditorExitVisit register(
    BuildContext context,
    ModalRoute<dynamic> route,
    AdminSubmissionEditorViewModel owner,
    AdminDraftActivation activation,
    String location,
  ) {
    final old = _visit;
    if (old != null &&
        old.route == route &&
        old.matchedLocation == location &&
        identical(old.owner, owner) &&
        owner.isActivationCurrent(old.activation)) {
      _observeCoverage();
      return old;
    }
    if (old != null) unregister(old);
    return _visit = AdminEditorExitVisit(
      context,
      route,
      owner,
      activation,
      location,
    );
  }

  /// Old disposal cannot retire a replacement page's authority.
  void unregister(AdminEditorExitVisit visit) {
    if (!identical(_visit, visit)) return;
    _visit = null;
    // The old presentation has detached. Keep the router invocation occupied,
    // but allow the replacement binding to activate its independently guarded
    // target rather than failing on the outgoing presentation's reservation.
    _releaseReservation?.call();
    _releaseReservation = null;
    _retireDialog();
  }

  /// Tracks only the known Progress covering page, never an editor source.
  void registerProgress(
    ModalRoute<dynamic> route,
    AdminSubmissionEditorViewModel owner,
  ) {
    _progressRoute = route;
    _progressOwner = owner;
    _observeCoverage();
  }

  /// An older Progress disposal cannot clear a replacement presentation.
  void unregisterProgress(ModalRoute<dynamic> route) {
    if (!identical(_progressRoute, route)) return;
    _progressRoute = null;
    _progressOwner = null;
  }

  bool _presented(AdminEditorExitVisit visit) {
    if (visit.route.isCurrent) return true;
    final progress = _progressRoute;
    if (progress?.isCurrent != true ||
        !identical(_progressOwner, visit.owner) ||
        visit.owner.isSaveRunning ||
        !visit.context.mounted) {
      return false;
    }
    final configuration = GoRouter.of(
      visit.context,
    ).routerDelegate.currentConfiguration;
    final top = configuration.last;
    final uri = top is ImperativeRouteMatch
        ? top.matches.uri
        : configuration.uri;
    return top.route.name == RouteNames.adminSubmissionSaveProgress &&
        uri.queryParameters['session'] == visit.owner.sessionId;
  }

  /// A temporary arbitrary covering route permanently retires this decision.
  void _observeCoverage() {
    final visit = _visit;
    if (_pending == null || visit == null || _presented(visit)) return;
    // Our own modal is the only expected cover during a decision.
    if (_dialog?.isActive == true && _dialog?.isCurrent == true) return;
    _revokePresentation?.call();
  }

  bool _authorized(
    AdminSubmissionEditorViewModel owner,
    AdminDraftActivation activation,
  ) =>
      auth.isAdmin &&
      auth.currentUser?.id == activation.owner.accountId &&
      owner.isActivationCurrent(activation);

  void _retireDialog() {
    final dialog = _dialog;
    final navigator = dialog?.navigator;
    if (dialog == null || navigator == null) return;
    scheduleMicrotask(() {
      if (navigator.mounted && dialog.isActive) navigator.removeRoute(dialog);
    });
  }

  /// Guards only incoming Admin identity changes and occupied exit decisions.
  FutureOr<OnEnterResult> onEnter(
    BuildContext context,
    GoRouterState current,
    GoRouterState next,
    GoRouter router,
  ) {
    final owner = context.read<AdminSubmissionEditorViewModel?>();
    if (!auth.isAdmin ||
        _visit != null && !_authorized(_visit!.owner, _visit!.activation) ||
        owner?.accountId != null && owner!.accountId != auth.currentUser?.id) {
      _pending = null;
      _retireDialog();
      return const Allow();
    }
    if (_pending != null || _moderationClose != null) return const Block.stop();
    if (owner == null) return const Allow();
    final segments = next.uri.pathSegments;
    final editor =
        segments.length == 3 &&
        segments[0] == 'admin' &&
        segments[1] == 'submissions' &&
        segments[2] != 'save-progress';
    if (!editor) return const Allow();
    final id = int.tryParse(segments[2]);
    final session = next.uri.queryParameters['session'];
    // A resume hint for A cannot authorize presenting A through explicit B.
    // Refuse before a field decision, retaining the active private editor.
    if (session != null &&
        session == owner.sessionId &&
        id != null &&
        id != owner.submissionId) {
      return const Block.stop();
    }
    if (_visit != null && session != null && session != owner.sessionId) {
      return _validateHint(context, current, next, router, owner, session);
    }
    return _evaluateIncoming(context, current, next, owner);
  }

  Future<OnEnterResult> _validateHint(
    BuildContext context,
    GoRouterState current,
    GoRouterState next,
    GoRouter router,
    AdminSubmissionEditorViewModel owner,
    String session,
  ) async {
    final visit = _visit!;
    final account = auth.currentUser?.id;
    if (account == null) return const Block.stop();
    final token = Object();
    _pending = token;
    final configuration = router.routerDelegate.currentConfiguration;
    try {
      final result = await context
          .read<AdminSubmissionDraftRepository>()
          .loadDraftBySession(accountId: account, sessionId: session);
      if (!context.mounted) return const Block.stop();
      if (!identical(_pending, token) ||
          !identical(_visit, visit) ||
          !_authorized(owner, visit.activation) ||
          auth.currentUser?.id != account ||
          !identical(
            configuration,
            router.routerDelegate.currentConfiguration,
          )) {
        return const Block.stop();
      }
      final id = int.tryParse(next.uri.pathSegments.last);
      if (result is! Success<AdminSubmissionDraft?> ||
          result.value == null ||
          result.value!.owner.accountId != account ||
          id != null && result.value!.owner.submissionId != id) {
        return const Block.stop();
      }
    } finally {
      if (identical(_pending, token)) _pending = null;
    }
    return await _evaluateIncoming(context, current, next, owner);
  }

  FutureOr<OnEnterResult> _evaluateIncoming(
    BuildContext context,
    GoRouterState current,
    GoRouterState next,
    AdminSubmissionEditorViewModel owner,
  ) {
    final id = int.tryParse(next.uri.pathSegments.last);
    final session = next.uri.queryParameters['session'];
    final same = session != null
        ? session == owner.sessionId && (id == null || id == owner.submissionId)
        : (next.uri.pathSegments.last == 'new'
              ? owner.submissionId == null
              : id == owner.submissionId);
    if (!same && owner.pendingRecoveryCheckpoint) {
      if (context.mounted) {
        showSnackBar(
          context: context,
          textContent:
              'Salva nella bozza locale i campi remoti accettati '
              'prima di aprire un altro contributo.',
        );
      }
      return const Block.stop();
    }
    final visit = _visit;
    if (!same &&
        visit != null &&
        current.uri.path == next.uri.path &&
        current.uri.queryParameters['session'] != session) {
      return exit(
        context,
        current,
      ).then((allowed) => allowed ? const Allow() : const Block.stop());
    }
    return const Allow();
  }

  /// Qualifies the consumed moderation effect before dispatching its own pop.
  bool closeAfterModeration(
    AdminEditorExitVisit visit,
    AdminDraftActivation? activation,
    String lane,
    int? execution,
  ) {
    final owner = visit.owner;
    if (!identical(_visit, visit) ||
        !visit.context.mounted ||
        !visit.route.isCurrent ||
        activation == null ||
        !_authorized(owner, activation) ||
        _pending != null ||
        execution == null) {
      return false;
    }
    final valid = switch (lane) {
      'reject' =>
        execution == owner.rejectExecutionId && owner.rejectSnapshot.completed,
      'promote' =>
        execution == owner.promoteExecutionId &&
            owner.promoteSnapshot.completed,
      'link' =>
        execution == owner.linkExecutionId && owner.linkSnapshot.completed,
      'apply' =>
        execution == owner.applyExecutionId && owner.applySnapshot.completed,
      _ => false,
    };
    if (!valid || _moderationClose != null) return false;
    _moderationClose = visit;
    GoRouter.of(visit.context).pop(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_moderationClose, visit)) _moderationClose = null;
    });
    return true;
  }

  /// Decides one actual removal or one query-only identity rebind.
  Future<bool> exit(BuildContext context, GoRouterState state) async {
    final visit = _visit;
    if (!auth.isAdmin ||
        visit != null &&
            auth.currentUser?.id != visit.activation.owner.accountId) {
      _retireDialog();
      return true;
    }
    // An unavailable pushed editor never registered an editing visit. Its own
    // pop must not ask permission to remove the protected editor underneath.
    // Full-stack replacement will separately invoke that editor's onExit.
    if (visit != null && visit.pageKey != state.pageKey) return true;
    if (visit != null && visit.matchedLocation != state.matchedLocation) {
      return false;
    }
    if (_pending != null) return false;
    if (visit == null) {
      return true; // Unavailable binding retains its app owner.
    }
    final owner = visit.owner;
    final activation = visit.activation;
    if (!_authorized(owner, activation) ||
        !visit.context.mounted ||
        !_presented(visit)) {
      return false;
    }
    final token = Object();
    _pending = token;
    final router = GoRouter.of(visit.context);
    final configuration = router.routerDelegate.currentConfiguration;
    AdminDraftExitReview? review;
    DialogRoute<UnsavedChangesDecision>? ownedDialog;
    var leaving = false;
    var revoked = false;
    _revokePresentation = () => revoked = true;
    bool current() =>
        !revoked &&
        identical(_pending, token) &&
        identical(_visit, visit) &&
        visit.context.mounted &&
        visit.route.isActive &&
        _authorized(owner, activation) &&
        identical(router.routerDelegate.currentConfiguration, configuration);
    void revokeIfObsolete() {
      if (!_authorized(owner, activation)) {
        revoked = true;
        if (identical(_pending, token)) {
          _retireDialog();
          _pending = null;
          _releaseReservation = null;
          _revokePresentation = null;
          if (review != null) owner.endExitDecision(review);
        }
      }
    }

    void release() {
      if (review != null) owner.endExitDecision(review);
      if (identical(_pending, token)) {
        _pending = null;
        _releaseReservation = null;
        _revokePresentation = null;
      }
    }

    auth.addListener(revokeIfObsolete);
    owner.addListener(revokeIfObsolete);
    try {
      if (identical(_moderationClose, visit)) {
        _moderationClose = null;
        leaving = true;
        return true;
      }
      review = owner.beginExitDecision(activation);
      if (review == null) return false;
      _releaseReservation = () => owner.endExitDecision(review!, notify: false);
      if (!owner.hasUncheckpointedChanges) {
        leaving = true;
        return true;
      }
      final navigator = Navigator.of(visit.context, rootNavigator: true);
      final dialog = DialogRoute<UnsavedChangesDecision>(
        context: visit.context,
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        builder: (dialogContext) {
          final route = ModalRoute.of(dialogContext);
          if (route != null && route.isActive && !route.isCurrent) {
            revoked = true;
          }
          return const UnsavedChangesDialog(
            supportingText:
                'Salva ed esci conserva i campi nella bozza locale '
                'su questo dispositivo: '
                'non salva il contributo sul server. '
                'Usa Salva per inviare le modifiche. '
                'Esci senza salvare annulla solo le modifiche ai campi '
                'successive alla '
                'bozza locale o alla versione remota accettata. '
                'Foto in attesa e lavoro '
                'già salvato nella bozza restano conservati.',
          );
        },
      );
      ownedDialog = dialog;
      _dialog = dialog;
      final choice = await navigator.push(dialog);
      if (!context.mounted) return false;
      if (!current() || !_presented(visit)) return false;
      final result = switch (choice) {
        UnsavedChangesDecision.saveAndExit => await owner.checkpointForExit(
          review,
        ),
        UnsavedChangesDecision.discardAndExit => await owner.discardForExit(
          review,
        ),
        UnsavedChangesDecision.cancel || null => null,
      };
      if (!context.mounted) return false;
      if (!current() || !_presented(visit) || result == null) return false;
      final confirmed = choice == UnsavedChangesDecision.saveAndExit
          ? owner.isExitCheckpointConfirmed(review)
          : owner.isExitDiscardConfirmed(review);
      if (result is Error<void> || !confirmed) {
        showSnackBarGenericError(context: visit.context);
        return false;
      }
      leaving = true;
      return true;
    } on Object catch (error, stack) {
      if (error is AssertionError) rethrow;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          context: ErrorDescription('leaving an Admin editor'),
        ),
      );
      if (current() && _presented(visit)) {
        showSnackBarGenericError(context: visit.context);
      }
      return false;
    } finally {
      auth.removeListener(revokeIfObsolete);
      owner.removeListener(revokeIfObsolete);
      if (identical(_dialog, ownedDialog)) {
        if (!leaving) _retireDialog();
        _dialog = null;
      }
      if (leaving) {
        WidgetsBinding.instance.addPostFrameCallback((_) => release());
      } else {
        release();
      }
    }
  }
}
