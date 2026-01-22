import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/themes/theme_data.dart';
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
    final vM = widget.viewModel;

    return ListenableBuilder(
      listenable: vM.loadCurrentForecast,
      builder: (BuildContext context, Widget? child) {
        final icon = Icon(vM.currentWeatherCodeIcon);
        final temperatureText = Text('${vM.currentTemperatureCelsius} °C');

        if (vM.loadCurrentForecast.completed) {
          return FilledButton.tonalIcon(
            onPressed: () {
              // Start loading the hourly and daily weather forecast before
              // showing the modal.
              vM.loadHourlyForecast.execute(widget.coordinates);
              vM.loadDailyForecast.execute(widget.coordinates);

              showModalBottomSheet(
                context: context,
                builder: (context) => Theme(
                  data: AppThemeData.modalScreen(context),
                  child: WeatherForecastModal(
                    content: widget.content,
                    viewModel: widget.viewModel,
                  ),
                ),
                backgroundColor: Colors.transparent,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(Shapes.extraLarge),
                  ),
                ),
                constraints: const BoxConstraints(maxWidth: 720.0),
                isScrollControlled: true,
                useSafeArea: true,
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
