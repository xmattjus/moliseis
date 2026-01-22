import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/use-cases/category/category_use_case.dart';
import 'package:moliseis/domain/use-cases/detail/detail_use_case.dart';
import 'package:moliseis/domain/use-cases/explore/explore_use_case.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/ui/category/widgets/category_screen.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/detail/view_models/detail_view_model.dart';
import 'package:moliseis/ui/detail/widgets/detail_screen.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:provider/provider.dart';

GoRoute categoryRoute({required String name, required String childName}) {
  return GoRoute(
    path: RoutePaths.category,
    name: name,
    builder: (_, state) {
      final tabIndex = int.parse(
        state.pathParameters['index'] ?? kcategoryScreenNoIndex.toString(),
      );

      return ChangeNotifierProvider<CategoryViewModel>(
        create: (context) {
          final viewModel = CategoryViewModel(
            categoryUseCase: CategoryUseCase(
              eventRepository: context.read(),
              placeRepository: context.read(),
            ),
            exploreGetByIdUseCase: ExploreUseCase(
              eventRepository: context.read(),
              placeRepository: context.read(),
            ),
            settingsRepository: context.read(),
          );

          final allCategories = ContentCategory.values.minusUnknown;

          viewModel.setSelectedCategories.execute(
            tabIndex != kcategoryScreenNoIndex
                ? {allCategories.elementAt(tabIndex)}
                : {...allCategories},
          );

          return viewModel;
        },
        builder: (context, _) => CategoryScreen(viewModel: context.read()),
      );
    },
    routes: <RouteBase>[detailRoute(name: childName)],
  );
}

GoRoute detailRoute({required String name}) {
  return GoRoute(
    path: RoutePaths.details,
    name: name,
    builder: (context, state) {
      final id = int.parse(state.pathParameters['id']!);
      final isEvent = bool.parse(
        state.uri.queryParameters['isEvent'] ?? 'false',
      );

      final detailUseCase = DetailUseCase(
        cachedWeatherApiClient: CachedWeatherApiClient(
          weatherApiClient: WeatherApiClient(),
          currentWeatherCache: context.read(),
          hourlyWeatherCache: context.read(),
          dailyWeatherCache: context.read(),
        ),
        eventRepository: context.read(),
        placeRepository: context.read(),
      );

      final viewModel = DetailViewModel(detailUseCase: detailUseCase);

      final weatherViewModel = WeatherViewModel(
        detailUseCase: detailUseCase,
        weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
        weatherCodeIconMapper: const WmoWeatherIconMapper(),
      );

      if (isEvent) {
        viewModel.loadEvent.execute(id);
      } else {
        viewModel.loadPlace.execute(id);
      }

      return DetailScreen(
        isEvent: isEvent,
        viewModel: viewModel,
        weatherViewModel: weatherViewModel,
      );
    },
    redirect: (context, state) {
      final contentId = state.pathParameters['id'];

      if (contentId == null || int.tryParse(contentId) == null) {
        final log = Logger('CoreRoutes');

        log.severe('Content Id $contentId is not a parsable integer.');
        showSnackBar(
          context: context,
          textContent:
              'Si è verificato un errore durante il caricamento, riprova più '
              'tardi.',
        );
        return RoutePaths.home;
      }

      return null;
    },
  );
}
