import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/cards/card_attraction_grid_item.dart';
import 'package:moliseis/ui/core/ui/cards/card_attraction_list_item.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:responsive_framework/responsive_framework.dart';

class AttractionListViewResponsive extends StatelessWidget {
  /// Creates a list/grid view of attractions based on the device form factor.
  const AttractionListViewResponsive(
    this.future, {
    super.key,
    required this.onPressed,
  });

  final Future<List<int>> future;

  final void Function(int id) onPressed;

  @override
  Widget build(BuildContext context) {
    return FutureBuilt<List<int>>(
      future,
      onLoading: () {
        return const SliverFillRemaining(
          child: Center(child: CustomCircularProgressIndicator.withDelay()),
        );
      },
      onSuccess: (data) {
        if (data.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyView(text: Text("Non c'è nulla qui per il momento.")),
          );
        }

        if (ResponsiveBreakpoints.of(context).isMobile) {
          return SliverList.separated(
            itemBuilder: (context, index) {
              return CardAttractionListItem(
                data[index],
                color: Theme.of(context).colorScheme.surface,
                elevation: 0,
                onPressed: () => onPressed(data[index]),
                actions: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16.0),
                    child: FavouriteButton(
                      key: ValueKey<String>('fav-btn:${data[index]}'),
                      // viewModel: favouriteViewModel,
                      id: data[index],
                    ),
                  ),
                ],
              );
            },
            separatorBuilder:
                (context, index) => Divider(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
            itemCount: data.length,
          );
        } else {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                return CardAttractionGridItem(
                  data[index],
                  onPressed: () => onPressed(data[index]),
                );
              }, childCount: data.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
                mainAxisExtent: kGridViewCardHeight,
              ),
            ),
          );
        }
      },
      onError:
          (error) => const SliverToBoxAdapter(
            child: EmptyView.error(
              text: Text('Si è verificato un errore durante il caricamento.'),
            ),
          ),
    );
  }
}
