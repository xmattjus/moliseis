part of 'geo_map_bottom_sheet.dart';

class _GeoMapBottomSheetSearch extends StatefulWidget {
  const _GeoMapBottomSheetSearch(
    this.query, {
    required this.onResultPressed,
    required this.onBackPressed,
  });

  final String query;
  final void Function(int id) onResultPressed;
  final void Function() onBackPressed;

  @override
  State<_GeoMapBottomSheetSearch> createState() =>
      _GeoMapBottomSheetSearchState();
}

class _GeoMapBottomSheetSearchState extends State<_GeoMapBottomSheetSearch> {
  late final SearchViewModel _searchViewModel;

  @override
  void initState() {
    super.initState();

    _searchViewModel = SearchViewModel(
      attractionRepository: context.read(),
      searchRepository: context.read(),
    );

    _searchViewModel.loadResults.execute(widget.query);
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              CustomBackButton(
                onPressed: widget.onBackPressed,
                backgroundColor: Colors.transparent,
              ),
              Align(
                alignment:
                    Platform.isIOS ? Alignment.center : Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    72.0,
                    18.0,
                    72.0,
                    16.0,
                  ),
                  child: Text(
                    'Risultati',
                    style: CustomTextStyles.title(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: _searchViewModel.loadResults,
          builder: (context, child) {
            if (_searchViewModel.loadResults.running) {
              return const SliverToBoxAdapter(
                child: EmptyView.loading(text: Text('Caricamento in corso...')),
              );
            }

            if (_searchViewModel.loadResults.error) {
              return SliverToBoxAdapter(
                child: EmptyView(
                  text: const Text(
                    'Si è verificato un errore durante il caricamento',
                  ),
                  action: TextButton(
                    onPressed: () {
                      _searchViewModel.loadResults.execute(widget.query);
                    },
                    child: const Text('Riprova'),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.only(bottom: 16.0),
              sliver: AttractionListViewResponsive(
                Future.sync(() => _searchViewModel.resultIds),
                onPressed: widget.onResultPressed,
              ),
            );
          },
        ),
      ],
    );
  }
}
