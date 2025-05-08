part of 'search_screen.dart';

class SearchScreenHomeView extends StatelessWidget {
  const SearchScreenHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AttractionViewModel>(
      builder: (context, value, child) {
        ///
        final list = value.savedAttractionIds;

        return CustomScrollView(
          slivers: <Widget>[
            /*
        const SliverList(
            delegate: SliverChildListDelegate.fixed(<Widget>[
          ContentDividerText(
              padding: EdgeInsetsDirectional.only(
                  start: 16.0, top: 16.0, bottom: 8.0),
              child: Text('Suggeriti'))
        ])),
        FutureBuilt(
          exploreService.getSuggestedAttractions(),
          onLoading: () {
            return const SliverToBoxAdapter(
              child: Center(
                child: AppLoadingIndicator(),
              ),
            );
          },
          onSuccess: (data) {
            data as List<Attraction>;
            return SliverList.builder(
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ListViewAttractionCard(
                    id: data[index].id,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    actions: <Widget>[
                      AppSaveButton(id: data[index].id, uid: data[index].name),
                    ],
                    onTap: () {
                      context
                          .goNamed(ScreenNames.searchDetails, pathParameters: {
                        'id': data[index].id.toString(),
                        'index': (data[index].type.index - 1).toString()
                      });
                    },
                  ),
                ).inList(index, data.length, Axis.vertical);
              },
              itemCount: data.length > 3 ? 3 : data.length,
            );
          },
          onError: (error) {
            return const SliverToBoxAdapter(
              child: EmptyView.error(),
            );
          },
        ),
        */
            SliverToBoxAdapter(
              child: Pad(
                t: 16.0,
                b: 8.0,
                h: 16.0,
                child: CustomRichText(
                  const Text('Preferiti'),
                  labelTextStyle: CustomTextStyles.section(context),
                ),
              ),
            ),
            if (list.isNotEmpty)
              AttractionListViewResponsive(
                Future.sync(() => list),
                onPressed: (attractionId) {
                  GoRouter.of(context).goNamed(
                    RouteNames.searchStory,
                    pathParameters: {'id': attractionId.toString()},
                  );
                },
              )
            else
              const SliverFillRemaining(
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
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 16.0)),
          ],
        );
      },
    );
  }
}
