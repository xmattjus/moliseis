import 'package:flutter/material.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:provider/provider.dart';

/// Builds the provider, app theme, global messenger, and scaffold required by
/// favourite-button widget tests.
Widget favouriteButtonHarness({
  required FavouriteViewModel viewModel,
  required Widget child,
}) => Builder(
  builder: (context) => ChangeNotifierProvider<FavouriteViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      theme: AppThemeData.light(context: context),
      home: Scaffold(body: child),
    ),
  ),
);
