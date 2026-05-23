import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class WeatherForecastHourlyList extends StatefulWidget {
  const WeatherForecastHourlyList({
    super.key,
    required this.borderColor,
    required this.backgroundColor,
    required this.viewModel,
    this.currentHourOverride,
  });

  final Color borderColor;
  final Color backgroundColor;
  final WeatherViewModel viewModel;

  /// Overrides the current hour used to highlight the active slot.
  ///
  /// Only set this in tests to make the widget deterministic.
  @visibleForTesting
  final int? currentHourOverride;

  @override
  State<WeatherForecastHourlyList> createState() =>
      _WeatherForecastHourlyListState();
}

class _WeatherForecastHourlyListState extends State<WeatherForecastHourlyList> {
  final _listController = ListController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _listController.dispose();
    super.dispose();
  }

  // Scrolls the hourly forecast list to the current hour.
  // Guard against the case where the ListView is not visible yet (e.g. still
  // loading), which means no scroll view is attached to the controller.
  void _animateToItem(int index) {
    if (!_scrollController.hasClients) {
      return;
    }

    _listController.animateToItem(
      index: index,
      scrollController: _scrollController,
      alignment: 0,
      // You can provide duration and curve depending on the estimated
      // distance between currentPosition and the target item position.
      duration: (estimatedDistance) => Durations.medium3,
      curve: (estimatedDistance) => Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appEffects = context.appEffects;
    final appSizes = context.appSizes;
    final appShapes = context.appShapes;
    const iconMapper = WmoWeatherIconMapper();

    final viewModel = widget.viewModel;
    final currentHour = widget.currentHourOverride ?? DateTime.now().hour;

    return ClipRRect(
      borderRadius: appShapes.circular.cornerExtraLarge,
      child: Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(
            color: widget.borderColor,
            width: appSizes.borderSide.medium,
          ),
          borderRadius: appShapes.circular.cornerExtraLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                'Nelle prossime ore',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ListenableBuilder(
              listenable: viewModel.loadHourlyForecast,
              builder: (_, _) {
                if (viewModel.loadHourlyForecast.completed) {
                  final hourlyData = viewModel.getHourlyForecastData;

                  if (hourlyData == null) {
                    return const SizedBox();
                  }

                  // Shows at most 24 hours of the hourly weather forecast data.
                  final itemCount = hourlyData.time.take(24).length;

                  // Schedules the hourly forecast list scroll to the current
                  // hour after the first frame has been rendered.
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    _animateToItem(currentHour);
                  });

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SuperListView.builder(
                      scrollDirection: Axis.horizontal,
                      listController: _listController,
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final hour = () {
                          if (index == currentHour) {
                            return 'Adesso';
                          } else if (index < 10) {
                            return '0$index';
                          }
                          return '$index';
                        }();
                        return () {
                          final child = Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 4,
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
                                iconMapper.iconForCode(
                                  hourlyData.weatherCode[index],
                                  hourlyData.isDay?[index] == 1,
                                ),
                              ),
                              label: Text(
                                index == currentHour
                                    ? widget.viewModel.currentTemperatureCelsius
                                    : '${hourlyData.temperature2m[index].toStringAsFixed(1)}°',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          );

                          if (index == currentHour) {
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
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: child,
                            );
                          }

                          return child;
                        }();
                      },
                      itemCount: itemCount,
                    ),
                  );
                }

                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherModalHourlyListItem extends StatelessWidget {
  const _WeatherModalHourlyListItem({
    required this.hourLabel,
    required this.icon,
    required this.label,
  });

  final Widget hourLabel;
  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          hourLabel,
          const SizedBox(height: 12),
          icon,
          const SizedBox(height: 16),
          label,
        ],
      ),
    );
  }
}
