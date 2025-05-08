import 'package:go_router/go_router.dart';
import 'package:moliseis/ui/categories/widgets/categories_screen.dart';
import 'package:moliseis/ui/story/view_models/paragraph_view_model.dart';
import 'package:moliseis/ui/story/view_models/story_view_model.dart';
import 'package:moliseis/ui/story/widgets/story_screen.dart';
import 'package:provider/provider.dart';

GoRoute categoriesRoute({
  required String routeName,
  required String childRouteName,
}) => GoRoute(
  path: 'category/:index',
  name: routeName,
  builder: (context, state) {
    return CategoriesScreen(tabIndex: state.pathParameters['index']);
  },
  routes: <RouteBase>[storyRoute(routeName: childRouteName)],
);

GoRoute storyRoute({required String routeName}) => GoRoute(
  path: 'story/:id',
  name: routeName,
  builder: (context, state) {
    final id = int.parse(state.pathParameters['id']!);
    final paragraphViewModel = ParagraphViewModel(
      paragraphRepository: context.read(),
    );
    final viewModel = StoryViewModel(
      attractionRepository: context.read(),
      galleryRepository: context.read(),
      storyRepository: context.read(),
    );
    viewModel.load.execute(id);
    return StoryScreen(
      attractionId: state.pathParameters['id'],
      paragraphViewModel: paragraphViewModel,
      storyViewModel: viewModel,
    );
  },
);
