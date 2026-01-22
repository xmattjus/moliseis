import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/app_colors_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_effects_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_sizes_theme_extension.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_title.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_days_list.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_hourly_list.dart';

class WeatherForecastModal extends StatefulWidget {
  final ContentBase content;
  final WeatherViewModel viewModel;

  const WeatherForecastModal({
    super.key,
    required this.content,
    required this.viewModel,
  });

  @override
  State<WeatherForecastModal> createState() => _WeatherForecastModalState();
}

class _WeatherForecastModalState extends State<WeatherForecastModal> {
  @override
  Widget build(BuildContext context) {
    final vM = widget.viewModel;

    final appSizes = Theme.of(context).extension<AppSizesThemeExtension>()!;
    final appEffects = Theme.of(context).extension<AppEffectsThemeExtension>()!;

    return DraggableScrollableSheet(
      snap: true,
      minChildSize: appSizes.modalMinSnapSize,
      snapSizes: appSizes.modalSnapSizes,
      builder: (context, scrollController) {
        final appColors = Theme.of(
          context,
        ).extension<AppColorsThemeExtension>()!;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Shapes.extraLarge),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: appEffects.modalBlurEffect,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: appColors.modalBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(Shapes.extraLarge),
                        ),
                        border: Border.all(
                          color: appColors.modalBorderColor,
                          width: appSizes.borderSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Align(child: BottomSheetDragHandle()),
                      BottomSheetTitle(
                        title:
                            'Previsioni meteo per ${widget.content.city.target?.name}',
                        onClose: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 32.0),
                      Text(
                        '${vM.currentTemperatureCelsius}°',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        vM.currentWeatherDescription,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 16.0),
                      WeatherForecastHourlyList(
                        borderColor: appColors.modalBorderColor,
                        backgroundColor: appColors.modalBackgroundColor,
                        viewModel: vM,
                      ),
                      const SizedBox(height: 8.0),
                      WeatherForecastDaysList(
                        borderColor: appColors.modalBorderColor,
                        backgroundColor: appColors.modalBackgroundColor,
                        viewModel: vM,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        'Dati meteo forniti da Open-Meteo.com',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 16.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
