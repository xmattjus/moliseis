import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/core/ui/custom_ink_well.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/skeletons/app_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/explore/view_models/suggestion_view_model.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

const double _itemWidth = kGridViewCardWidth * 0.8;

class SuggestiondHorizontalListView extends StatelessWidget {
  const SuggestiondHorizontalListView({required this.viewModel, super.key});

  final SuggestionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    const sectionTextBottomPadding = 8.0;
    const placeholderLength = 5;

    final colorScheme = context.colorScheme;
    final borderRadius = context.appShapes.circular.cornerExtraLarge;

    final height =
        (MediaQuery.sizeOf(context).height * 0.45) -
        sectionTextBottomPadding +
        (AppTextStyles.section(context)?.height ?? 16.0);

    return SliverList.list(
      children: [
        const TextSectionDivider(
          'Suggeriti',
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            0,
            16,
            sectionTextBottomPadding,
          ),
        ),
        SizedBox(
          height: height,
          child: ListenableBuilder(
            listenable: viewModel.load,
            builder: (context, child) {
              final showPlaceholders = viewModel.load.running;

              if (viewModel.load.error) {
                return EmptyView.error(
                  text: const Text(
                    'Si è verificato un errore durante il caricamento',
                  ),
                  action: TextButton(
                    onPressed: () => unawaited(viewModel.load.execute()),
                    child: const Text('Riprova'),
                  ),
                );
              }

              // Generates a list of placeholders while loading the suggested
              // places from the repository.
              final children = showPlaceholders
                  ? _buildPlaceholders(
                      length: placeholderLength,
                      height: height,
                      borderRadius: borderRadius,
                    )
                  : _buildContentItems(
                      height: height,
                      borderRadius: borderRadius,
                    );

              if (viewModel.load.completed && viewModel.suggestions.isEmpty) {
                return const EmptyView(
                  text: Text('Nessun luogo suggerito per ora'),
                );
              }

              return Skeletonizer(
                enabled: showPlaceholders,
                effect: AppPulseEffect(
                  from: colorScheme.surfaceContainerHigh,
                  to: colorScheme.surfaceContainerLow,
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                  itemExtent: _itemWidth,
                  children: children,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPlaceholders({
    required int length,
    required double height,
    required BorderRadius borderRadius,
  }) => List.generate(length, (index) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.hardEdge,
        child: Container(
          color: Colors.black,
          width: _itemWidth,
          height: height,
        ),
      ),
    );
  });

  List<Widget> _buildContentItems({
    required double height,
    BorderRadius? borderRadius,
  }) => UnmodifiableListView<Widget>(
    viewModel.suggestions.map<Widget>(
      (content) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: _CarouselViewItem(
          content: content,
          height: height,
          borderRadius: borderRadius,
        ),
      ),
    ),
  );
}

class _CarouselViewItem extends StatelessWidget {
  const _CarouselViewItem({
    required this.content,
    required this.height,
    this.borderRadius,
  });

  final ContentBase content;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        this.borderRadius ?? context.appShapes.circular.cornerExtraLarge;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: <Widget>[
          if (content.media.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(40),
              ),
              position: DecorationPosition.foreground,
              child: AppNetworkImage(
                url: content.media.first.url,
                width: _itemWidth,
                height: height,
                imageWidth: content.media.first.width,
                imageHeight: content.media.first.height,
              ),
            ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: CustomInkWell(
                onPressed: () => GoRouter.of(context).goNamed(
                  RouteNames.homePost,
                  pathParameters: {'id': content.remoteId.toString()},
                  queryParameters: {
                    'type': RouteParameters.contentTypeSlug(
                      content is Event ? ContentType.event : ContentType.place,
                    ),
                  },
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.all(8),
                child: Align(
                  alignment: Alignment.topRight,
                  child: FavouriteButton(
                    color: Colors.white,
                    content: content,
                    borderRadius: context.appShapes.circular.cornerLarge,
                  ),
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ContentNameAndCity(
                    name: content.name,
                    cityName: content.city?.name,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
