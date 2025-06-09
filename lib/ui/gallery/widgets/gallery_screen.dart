import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_rich_text.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/gallery/view_models/gallery_view_model.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_screen_image_sliver_grid.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:provider/provider.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late final GalleryViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = context.read<GalleryViewModel>();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsViewModel, AttractionSort>(
      builder: (_, sortBy, _) {
        return Scaffold(
          appBar: const CustomAppBar.hidden(),
          body: SafeArea(
            child: NestedScrollView(
              body: FutureBuilt(
                _viewModel.getAllAttractions(sortBy),
                onLoading: () {
                  return const EmptyView.loading(
                    text: Text('Caricamento in corso...'),
                  );
                },
                onSuccess: (List<Attraction> attractions) {
                  final slivers = <Widget>[];

                  for (int i = 0; i < attractions.length; i++) {
                    final placeName = attractions[i].place.target?.name;

                    slivers.addAll(<Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverList.list(
                          children: <Widget>[
                            SizedBox(height: i > 0 ? 16.0 : 0.0),
                            TextSectionDivider(attractions[i].name),
                            if (placeName != null)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  top: 4.0,
                                ),
                                child: CustomRichText(
                                  Text(placeName),
                                  labelTextStyle: CustomTextStyles.subtitle(
                                    context,
                                  ),
                                  icon: const Icon(Icons.place_outlined),
                                ),
                              )
                            else
                              const SizedBox(),
                            const SizedBox(height: 16.0),
                          ],
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        sliver: GalleryScreenImageSliverGrid(
                          attraction: attractions[i],
                          sortBy: sortBy,
                        ),
                      ),
                    ]);
                  }

                  // Counts the custom scroll view total number of widgets.
                  final childrenCount =
                      _viewModel.getAllImages(sortBy).length +
                      attractions.length;

                  return CustomScrollView(
                    slivers: slivers,
                    semanticChildCount: childrenCount,
                  );
                },
                onError: (error) {
                  return const EmptyView.error(
                    text: Text(
                      'Si è verificato un errore durante il caricamento.',
                    ),
                  );
                },
              ),
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                    return <Widget>[
                      SliverAppBar(
                        title: const Text('Galleria'),
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        actions: <Widget>[
                          MenuAnchor(
                            menuChildren: <Widget>[
                              MenuItemButton(
                                onPressed: () {
                                  context
                                      .read<SettingsViewModel>()
                                      .saveAttractionSortBy(
                                        AttractionSort.byName,
                                      );
                                },
                                leadingIcon: const Icon(Icons.text_fields),
                                trailingIcon: sortBy == AttractionSort.byName
                                    ? const Icon(Icons.check)
                                    : null,
                                child: const Text('Per nome'),
                              ),
                              MenuItemButton(
                                onPressed: () {
                                  context
                                      .read<SettingsViewModel>()
                                      .saveAttractionSortBy(
                                        AttractionSort.byDate,
                                      );
                                },
                                leadingIcon: const Icon(Icons.access_time),
                                trailingIcon: sortBy == AttractionSort.byDate
                                    ? const Icon(Icons.check)
                                    : null,
                                child: const Text('Per data'),
                              ),
                            ],
                            builder: (_, controller, _) {
                              return IconButton(
                                onPressed: () {
                                  controller.isOpen
                                      ? controller.close()
                                      : controller.open();
                                },
                                tooltip: 'Ordina',
                                icon: const Icon(Icons.sort),
                              );
                            },
                          ),
                        ],
                      ),
                    ];
                  },
            ),
          ),
        );
      },
      selector: (_, controller) => controller.attractionSortBy,
    );
  }
}
