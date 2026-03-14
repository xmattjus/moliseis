import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/domain/models/place_content.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/post_inner_screen.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({
    super.key,
    required this.isEvent,
    required this.viewModel,
    required this.weatherViewModel,
  });

  final bool isEvent;
  final PostViewModel viewModel;
  final WeatherViewModel weatherViewModel;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  String _currentUri = '';

  @override
  Widget build(BuildContext context) {
    _currentUri = GoRouterState.of(context).fullPath.toString();

    return Scaffold(
      appBar: const CustomAppBar(
        showBackButton: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.viewModel.loadEvent,
            widget.viewModel.loadPlace,
          ]),
          builder: (context, child) {
            if (widget.viewModel.loadEvent.completed ||
                widget.viewModel.loadPlace.completed) {
              final content = widget.viewModel.content is EventContent
                  ? widget.viewModel.content as EventContent
                  : widget.viewModel.content as PlaceContent;

              return PostInnerScreen(
                content: content,
                onContentPressed: (content) => _buildPostRoute(content),
                onCategoryPressed: () {
                  _buildCategoriesRoute(content.category);
                },
                onMapPressed: () {
                  // Sets a [UniqueKey] so that go_router
                  // can notify [mapState] changes to the next
                  // route.
                  //
                  // Removing the [key] query parameter will
                  // prevent state changes for the next route
                  // if it is already present in the
                  // navigation stack.
                  context.goNamed(
                    RouteNames.geoMap,
                    queryParameters: {"key": UniqueKey().toString()},
                    extra: content,
                  );
                },
                loadNearContent: widget.viewModel.loadNearContent,
                nearContent: widget.viewModel.nearContent,
                weatherViewModel: widget.weatherViewModel,
              );
            }

            return const Center(
              child: EmptyView.loading(text: Text('Caricamento in corso...')),
            );
          },
        ),
      ),
      extendBodyBehindAppBar: true,
    );
  }

  void _buildCategoriesRoute(ContentCategory category) {
    String? nextRouteName;

    if (_currentUri.startsWith(RoutePaths.favourites)) {
      nextRouteName = RouteNames.favouritesCategory;
    } else if (_currentUri.startsWith(RoutePaths.events)) {
      nextRouteName = RouteNames.eventsCategory;
    } else {
      nextRouteName = RouteNames.homeCategory;
    }

    GoRouter.of(context).goNamed(
      nextRouteName,
      pathParameters: {'index': (category.index - 1).toString()},
    );
  }

  void _buildPostRoute(ContentBase content) {
    String? nextRoute;
    var indexNecessary = false;

    if (_currentUri.startsWith('${RoutePaths.events}/category')) {
      nextRoute = RouteNames.eventsCategoryPost;
      indexNecessary = true;
    } else if (_currentUri.startsWith('${RoutePaths.favourites}/category')) {
      nextRoute = RouteNames.favouritesCategoryPost;
      indexNecessary = true;
    } else if (_currentUri.startsWith('${RoutePaths.home}/category')) {
      nextRoute = RouteNames.homeCategoryPost;
      indexNecessary = true;
    } else if (_currentUri.startsWith(RoutePaths.events)) {
      nextRoute = RouteNames.eventsPost;
    } else if (_currentUri.startsWith(RoutePaths.favourites)) {
      nextRoute = RouteNames.favouritesPost;
    } else if (_currentUri.startsWith(RoutePaths.home)) {
      nextRoute = RouteNames.homePost;
    }

    if (nextRoute != null) {
      final map = {'id': content.remoteId.toString()};

      if (indexNecessary) {
        map['index'] = (content.category.index - 1).toString();
      }

      GoRouter.of(context).pushReplacementNamed(
        nextRoute,
        pathParameters: map,
        queryParameters: {
          'isEvent': (content is EventContent ? 'true' : 'false'),
        },
      );
    }
  }
}
