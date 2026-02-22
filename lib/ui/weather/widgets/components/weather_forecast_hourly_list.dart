import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class WeatherForecastHourlyList extends StatefulWidget {
  final Color borderColor;
  final Color backgroundColor;
  final WeatherViewModel viewModel;

  const WeatherForecastHourlyList({
    super.key,
    required this.borderColor,
    required this.backgroundColor,
    required this.viewModel,
  });

  @override
  State<WeatherForecastHourlyList> createState() =>
      _WeatherForecastHourlyListState();
}

class _WeatherForecastHourlyListState extends State<WeatherForecastHourlyList> {
  final _hourlyScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final appEffects = context.appEffects;
    final appSizes = context.appSizes;

    final viewModel = widget.viewModel;
    final nowHour = DateTime.now().hour;

    // Schedules the hourly forecast list scroll to the current hour after
    // the first frame is rendered.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _scrollHourlyForecastToNow(nowHour),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(25.0),
      child: Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(
            color: widget.borderColor,
            width: appSizes.borderSide.medium,
          ),
          borderRadius: BorderRadius.circular(25.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 0),
              child: Text(
                'Nelle prossime ore',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ListenableBuilder(
              listenable: viewModel.loadHourlyForecast,
              builder: (_, _) {
                if (viewModel.loadHourlyForecast.completed) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140.0),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      controller: _hourlyScrollController,
                      padding: const EdgeInsets.all(8.0),
                      itemBuilder: (context, index) {
                        final hourlyData = viewModel.getHourlyForecastData!;
                        final hour = () {
                          if (index == nowHour) {
                            return 'Adesso';
                          } else if (index < 10) {
                            return '0$index';
                          }
                          return '$index';
                        }();
                        return () {
                          final child = Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 4.0,
                            ),
                            child: _WeatherModalHourlyListItem(
                              hourLabel: Text(
                                hour,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontVariations: const <FontVariation>[
                                        FontVariation.weight(300),
                                      ],
                                    ),
                                softWrap: false,
                              ),
                              icon: Icon(
                                const WmoWeatherIconMapper().iconForCode(
                                  hourlyData.weatherCode[index],
                                  hourlyData.isDay?[index] == 1,
                                ),
                              ),
                              label: Text(
                                index == nowHour
                                    ? widget.viewModel.currentTemperatureCelsius
                                    : '${hourlyData.temperature2m[index].toStringAsFixed(1)}°',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          );

                          if (index == nowHour) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: appEffects.containerColor2(
                                  context.colorScheme.primary,
                                  context.colorScheme.surfaceContainer,
                                ),
                                border: Border.all(
                                  color: context.appColors.modalBorderColor,
                                  width: appSizes.borderSide.medium,
                                ),
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: child,
                            );
                          }

                          return child;
                        }();
                      },
                      itemCount: 24,
                    ),
                  );
                }

                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Scrolls the hourly forecast list to the current hour.
  void _scrollHourlyForecastToNow(int now) => _hourlyScrollController.animateTo(
    now * 68.0,
    duration: Durations.medium3,
    curve: Curves.easeInOut,
  );
}

class _WeatherModalHourlyListItem extends StatelessWidget {
  final Widget hourLabel;
  final Widget icon;
  final Widget label;

  const _WeatherModalHourlyListItem({
    required this.hourLabel,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 60.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          hourLabel,
          const SizedBox(height: 12.0),
          icon,
          const SizedBox(height: 16.0),
          label,
        ],
      ),
    );
  }
}
