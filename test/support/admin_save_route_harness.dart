import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_draft_repositories.dart';
import 'fake_repositories.dart';
import 'mock_gotrue_client.dart';
import 'sync_harness.dart';

/// Production Admin routes composed with the existing sync and local fakes.
final class AdminSaveRouteHarness {
  AdminSaveRouteHarness({Iterable<int> persistedTargets = const []}) {
    for (final id in persistedTargets) {
      final draftOwner = AdminDraftOwner(
        accountId: AdminDraftSessionHarness.accountA,
        submissionId: id,
      );
      final detail = sampleAdminSubmission(
        id: id,
        name: 'Target $id',
        description: null,
        modifiedAtToken: '2026-08-20T00:00:00.123456Z',
      );
      final fields = AdminDraftSnapshot(
        category: ContentCategory.history,
        city: 'Campobasso',
        name: 'Target $id',
      );
      local.drafts.drafts[draftOwner.lookupKey] = AdminSubmissionDraft(
        owner: draftOwner,
        snapshot: fields,
        remoteBaseline: AdminRemoteBaseline(
          snapshot: fields,
          status: detail.status,
          modifiedAt: detail.modifiedAt,
          modifiedAtToken: detail.modifiedAtToken,
        ),
      );
      repository.getByIdResults[id] = Result.success(detail);
    }
    final user = User.fromJson({
      ...makeAuthUser(isAdmin: true).toJson(),
      'id': AdminDraftSessionHarness.accountA,
    })!;
    auth = ControllableAdminAuth(initialUser: user);
    owner = AdminSubmissionEditorViewModel(
      repository: repository,
      contentSubmissionRepository: content,
      draftSession: local.session,
    )..bindAuth(auth.viewModel);
    router = buildAppRouter(
      syncViewModel: sync.viewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  final sync = SyncHarness(gated: false);
  final local = AdminDraftSessionHarness();
  final repository = FakeAdminContentSubmissionRepository(
    createResult: Result.success(
      sampleAdminSubmission(
        description: null,
        modifiedAtToken: '2026-08-20T00:00:00.123456Z',
      ),
    ),
    getByIdResults: {
      1: Result.success(
        sampleAdminSubmission(
          description: null,
          modifiedAtToken: '2026-08-20T00:00:00.123456Z',
        ),
      ),
    },
  );
  final content = FakeContentSubmissionRepository();
  late final ControllableAdminAuth auth;
  late final AdminSubmissionEditorViewModel owner;
  late final GoRouter router;

  /// Retains one application owner across editor/progress page reconstruction.
  Widget app() => MultiProvider(
    providers: [
      ...buildSyncProviders(sync, auth: auth),
      Provider<AdminContentSubmissionRepository>.value(value: repository),
      Provider<AdminSubmissionDraftRepository>.value(value: local.drafts),
      Provider<ContentSubmissionRepository>.value(value: content),
      ChangeNotifierProvider<AdminSubmissionEditorViewModel>.value(
        value: owner,
      ),
    ],
    child: MaterialApp.router(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      restorationScopeId: 'admin-save-test',
      routerConfig: router,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en'), Locale('it')],
    ),
  );

  /// Owners are released by testOwnerUI after unmounting the routes.
  void dispose() {
    router.dispose();
    owner.dispose();
    auth.dispose();
    sync.viewModel.dispose();
  }
}
