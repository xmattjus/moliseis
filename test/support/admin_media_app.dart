import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_media_section.dart';

/// Keeps the real media section mounted while its editor owner changes.
Widget adminMediaApp(AdminSubmissionEditorViewModel owner) => MaterialApp(
  home: Scaffold(
    body: ListenableBuilder(
      listenable: owner,
      builder: (context, _) {
        final activation = owner.activation;
        return AdminSubmissionMediaSection(
          viewModel: owner,
          onAdd: () => owner.requestAddAsset(activation: activation),
          onRemoveStaged: (asset) =>
              owner.requestRemoveStagedAsset(asset, activation: activation),
          onRemoveAsset: (id) =>
              owner.requestDeleteAsset(id, activation: activation),
          onCancelPicker: () {},
        );
      },
    ),
  ),
);
