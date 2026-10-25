import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_title.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result_command.dart';

class EventsModal extends StatelessWidget {
  const EventsModal({
    required this.localizedMonths,
    required this.selectedDate,
    required this.viewModel,
    this.scrollController,
    super.key,
  });

  final List<String> localizedMonths;
  final EventCalendarDate selectedDate;
  final EventViewModel viewModel;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final command = viewModel.loadByDate;

    final showDragHandle = context.windowSizeClass.isAtMost(
      WindowSizeClass.medium,
    );

    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, command.results]),
      builder: (context, _) {
        final date = viewModel.selectedDate;
        final month = localizedMonths[date.month - 1];
        final bottomSheetTitle = date == viewModel.currentCalendarDate
            ? 'Eventi di oggi ${date.day} $month'
            : 'Eventi del ${date.day} $month';
        return CustomScrollView(
          controller: scrollController,
          slivers: <Widget>[
            SliverList.list(
              children: <Widget>[
                if (showDragHandle) const AppBottomSheetDragHandle(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    showDragHandle ? 0.0 : 16.0,
                    16,
                    16,
                  ),
                  child: AppBottomSheetTitle(
                    title: bottomSheetTitle,
                    icon: null,
                  ),
                ),
              ],
            ),
            Builder(
              builder: (context) {
                final snapshot = command.results.value;
                if (command.isRunningSync.value ||
                    !viewModel.hasCurrentDaySnapshot) {
                  return const SkeletonContentSliverGrid();
                }
                if (snapshot.hasFailure) {
                  return SliverToBoxAdapter(
                    child: EmptyView.error(
                      text: const Text(
                        'Si è verificato un errore durante il caricamento.',
                      ),
                      action: TextButton(
                        onPressed: () =>
                            viewModel.selectDate(viewModel.selectedDate),
                        child: const Text('Riprova'),
                      ),
                    ),
                  );
                }
                if (snapshot.completed) {
                  final events = viewModel.byMonth;

                  if (events.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyView(
                        text: Text('Nessun evento trovato per questa data.'),
                      ),
                    );
                  }

                  return ContentSliverGrid(
                    events,
                    onPressed: (content) {
                      GoRouter.of(context).goNamed(
                        RouteNames.eventsPost,
                        pathParameters: {'id': content.remoteId.toString()},
                        queryParameters: {'type': RouteParameters.eventType},
                      );
                    },
                  );
                }

                return const SkeletonContentSliverGrid();
              },
            ),
          ],
        );
      },
    );
  }
}
