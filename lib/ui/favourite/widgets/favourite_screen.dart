import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/content/content_adaptive_list_grid_view.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_list.dart';
import 'package:moliseis/ui/core/ui/window_size_provider.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';

class FavouriteScreen extends StatelessWidget {
  const FavouriteScreen({super.key, required this.viewModel});

  final FavouriteViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Preferiti'),
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
            ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                if (viewModel.load.completed) {
                  if (viewModel.favouriteEventIds.isEmpty &&
                      viewModel.favouritePlaceIds.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        icon: Icon(
                          Icons.favorite_border_sharp,
                          color: Colors.redAccent,
                        ),
                        text: Text(
                          'Il contenuto salvato verrà mostrato qui, prova!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  } else {
                    return ContentAdaptiveListGridView(
                      viewModel.favouriteEvents + viewModel.favouritePlaces,
                      onPressed: (content) {
                        GoRouter.of(context).goNamed(
                          RouteNames.favouritesDetails,
                          pathParameters: {'id': content.remoteId.toString()},
                          queryParameters: {
                            'isEvent': (content is EventContent
                                ? 'true'
                                : 'false'),
                          },
                        );
                      },
                    );
                  }
                }

                if (viewModel.load.error) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      text: const Text(
                        'Si è verificato un errore durante il caricamento.',
                      ),
                      action: TextButton(
                        onPressed: () => viewModel.load.execute(),
                        child: const Text('Riprova'),
                      ),
                    ),
                  );
                }

                final length =
                    viewModel.favouriteEventIds.length +
                    viewModel.favouritePlaceIds.length;

                return WindowSizeProvider.of(context).isCompact
                    ? SkeletonContentList.sliver(itemCount: length)
                    : SkeletonContentGrid.sliver(itemCount: length);
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 16.0)),
          ],
        ),
      ),
    );
  }
}
