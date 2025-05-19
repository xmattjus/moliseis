import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
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
                if (viewModel.load.running) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView.loading(
                      text: Text('Caricamento in corso...'),
                    ),
                  );
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

                if (viewModel.favourites.isEmpty) {
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
                  return AttractionListViewResponsive(
                    Future.sync(() => viewModel.favourites),
                    onPressed: (attractionId) {
                      GoRouter.of(context).goNamed(
                        RouteNames.favouritesStory,
                        pathParameters: {'id': attractionId.toString()},
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
