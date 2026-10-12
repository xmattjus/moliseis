import 'package:command_it/command_it.dart' as commands;
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_mode.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/search_result_sliver_list.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

/// Presentation authority for one Map submission, including equal queries.
typedef GeoMapSearchAdmission = ({
  SearchViewModel searchOwner,
  GeoMapSearchResults mode,
  commands.CommandResult<String?, Result<List<ContentBase>?>?> excludedSnapshot,
});

/// Rejects retained snapshots in both deferred publication windows.
bool admitsGeoMapSearchSnapshot(
  GeoMapSearchAdmission? admission,
  GeoMapViewModel owner,
  SearchViewModel searchOwner,
) {
  if (admission == null ||
      owner.isDisposed ||
      !identical(admission.searchOwner, searchOwner) ||
      !identical(owner.mode, admission.mode)) {
    return false;
  }
  final snapshot = searchOwner.loadResults.results.value;
  return !identical(snapshot, admission.excludedSnapshot) &&
      snapshot.paramData == admission.mode.query &&
      !searchOwner.loadResults.isRunningSync.value &&
      (snapshot.completed || snapshot.hasFailure);
}

/// Map-specific admission gating around the unchanged shared result list.
class GeoMapModalSearchResults extends StatelessWidget {
  const GeoMapModalSearchResults({
    required this.admission,
    required this.geoMapOwner,
    required this.onResultPressed,
    required this.onRetryPressed,
    required this.onBackPressed,
    required this.viewModel,
    super.key,
  });

  final GeoMapSearchAdmission? admission;
  final GeoMapViewModel geoMapOwner;
  final void Function(ContentBase content) onResultPressed;
  final VoidCallback onRetryPressed;
  final VoidCallback onBackPressed;
  final SearchViewModel viewModel;

  /// The committed query; rendering authority always reads the live owner.
  String get query => admission?.mode.query ?? '';

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: <Widget>[
      SliverToBoxAdapter(
        child: Row(
          spacing: 16,
          children: <Widget>[
            CustomBackButton(
              onPressed: onBackPressed,
              backgroundColor: Colors.transparent,
            ),
            Expanded(
              child: Text(
                'Risultati',
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      ListenableBuilder(
        listenable: Listenable.merge([
          geoMapOwner,
          viewModel.loadResults.results,
        ]),
        builder: (_, _) =>
            admitsGeoMapSearchSnapshot(admission, geoMapOwner, viewModel)
            ? SearchResultSliverList(
                onResultPressed: onResultPressed,
                onRetrySearchPressed: onRetryPressed,
                viewModel: viewModel,
              )
            : const SkeletonContentSliverGrid(),
      ),
    ],
  );
}
