import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/data/services/services.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_title.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/link_text_button.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_days_list.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_hourly_list.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

class WeatherForecastModal extends StatefulWidget {
  const WeatherForecastModal({
    required this.content,
    required this.viewModel,
    super.key,
  });

  final ContentBase content;
  final WeatherViewModel viewModel;

  @override
  State<WeatherForecastModal> createState() => _WeatherForecastModalState();
}

class _WeatherForecastModalState extends State<WeatherForecastModal> {
  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final appColors = context.appColors;
    final appEffects = context.appEffects;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Align(child: AppBottomSheetDragHandle()),
            AppBottomSheetTitle(
              title: 'Previsioni meteo per ${widget.content.city?.name}',
              onClose: () => context.pop(),
            ),
            const SizedBox(height: 32),
            Text(
              '${viewModel.currentTemperatureCelsius}°',
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.currentWeatherDescription,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            WeatherForecastHourlyList(
              borderColor: appColors.modalBorderColor,
              backgroundColor: appEffects.containerColor(
                context.colorScheme.primary,
                context.colorScheme.surfaceContainer,
              ),
              viewModel: viewModel,
            ),
            const SizedBox(height: 8),
            WeatherForecastDaysList(
              borderColor: appColors.modalBorderColor,
              backgroundColor: appEffects.containerColor(
                context.colorScheme.primary,
                context.colorScheme.surfaceContainer,
              ),
              viewModel: viewModel,
            ),
            const SizedBox(height: 16),
            LinkTextButton(
              label: const Text('Dati meteo forniti da Open-Meteo.com'),
              onPressed: () async {
                final launched = await context
                    .read<UrlLaunchService>()
                    .launchGenericUrl('https://open-meteo.com/');
                if (context.mounted && !launched) {
                  showSnackBarGenericError(context: context);
                }
              },
            ),
            SizedBox(height: context.bottomPadding),
          ],
        ),
      ),
    );
  }
}
