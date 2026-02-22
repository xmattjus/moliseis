import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/app_show_modal_bottom_sheet.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_modal.dart';

class WeatherForecastButton extends StatefulWidget {
  const WeatherForecastButton({
    super.key,
    required this.content,
    required this.coordinates,
    required this.viewModel,
  });

  final ContentBase content;
  final LatLng coordinates;
  final WeatherViewModel viewModel;

  @override
  State<WeatherForecastButton> createState() => _WeatherForecastButtonState();
}

class _WeatherForecastButtonState extends State<WeatherForecastButton> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.viewModel.loadCurrentForecast.execute(widget.coordinates),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return ListenableBuilder(
      listenable: viewModel.loadCurrentForecast,
      builder: (BuildContext context, Widget? child) {
        final icon = Icon(viewModel.currentWeatherCodeIcon);
        final temperatureText = Text(
          '${viewModel.currentTemperatureCelsius} °C',
        );

        if (viewModel.loadCurrentForecast.completed) {
          return FilledButton.tonalIcon(
            onPressed: () {
              // Start loading the hourly and daily weather forecast before
              // showing the modal.
              viewModel.loadHourlyForecast.execute(widget.coordinates);
              viewModel.loadDailyForecast.execute(widget.coordinates);

              appShowModalBottomSheet(
                context: context,
                builder: (_) {
                  return WeatherForecastModal(
                    content: widget.content,
                    viewModel: widget.viewModel,
                  );
                },
                isScrollControlled: true,
              );
            },
            icon: icon,
            label: temperatureText,
          );
        }

        return FilledButton.tonalIcon(
          onPressed: null,
          label: temperatureText,
          icon: icon,
        );
      },
    );
  }
}
