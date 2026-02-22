import 'package:flutter/material.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class WeatherForecastDaysList extends StatefulWidget {
  final Color borderColor;
  final Color backgroundColor;
  final WeatherViewModel viewModel;

  const WeatherForecastDaysList({
    super.key,
    required this.borderColor,
    required this.backgroundColor,
    required this.viewModel,
  });

  @override
  State<WeatherForecastDaysList> createState() =>
      _WeatherForecastDaysListState();
}

class _WeatherForecastDaysListState extends State<WeatherForecastDaysList> {
  late DateSymbols _dateSymbols;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentLocale = Localizations.localeOf(context);

    _dateSymbols = intl.DateFormat(
      null,
      currentLocale.languageCode,
    ).dateSymbols;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return ClipRRect(
      borderRadius: BorderRadius.circular(25.0),
      child: Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(
            color: widget.borderColor,
            width: context.appSizes.borderSide.medium,
          ),
          borderRadius: BorderRadius.circular(25.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListenableBuilder(
              listenable: viewModel.loadDailyForecast,
              builder: (context, child) {
                if (viewModel.loadDailyForecast.completed) {
                  final dailyData = viewModel.getDailyForecastData!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8.0),
                    itemCount: dailyData.time.length,
                    itemBuilder: (context, index) {
                      final date = DateTime.parse(dailyData.time[index]);

                      final weekDays = _dateSymbols.STANDALONESHORTWEEKDAYS
                          .shift(1);

                      final weekday = weekDays[date.weekday - 1];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(0.7),
                            1: FlexColumnWidth(0.3),
                            2: FlexColumnWidth(0.3),
                            3: FlexColumnWidth(0.25),
                            4: FlexColumnWidth(0.3),
                            5: FlexColumnWidth(double.minPositive),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: <TableRow>[
                            TableRow(
                              children: <Widget>[
                                Text(
                                  _isToday(date) ? 'Oggi' : weekday,
                                  style: context.defaultTextStyle.style
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Symbols.water_drop,
                                      size: 16.0,
                                      fill: 1.0,
                                    ),
                                    Text(
                                      ' ${dailyData.precipitationProbabilityMax[index]}%',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                Icon(
                                  const WmoWeatherIconMapper().iconForCode(
                                    dailyData.weatherCode[index],
                                    true,
                                  ),
                                  size: 24.0,
                                ),
                                _temperatureForecast(
                                  temperature:
                                      dailyData.temperature2mMin[index],
                                  iconData: Symbols.south_west,
                                ),
                                _temperatureForecast(
                                  temperature:
                                      dailyData.temperature2mMax[index],
                                  iconData: Symbols.north_east,
                                ),
                                const SizedBox(height: 40.0),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                return const EmptyBox();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _temperatureForecast({
    required double temperature,
    required IconData iconData,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.min,
      spacing: 4.0,
      children: <Widget>[
        Icon(iconData, size: 16.0),
        Text(
          '${temperature.toStringAsFixed(0)}°',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.end,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
      ],
    );
  }

  /// Returns `true` if the [date] is today. Respects the time zone.
  /// https://stackoverflow.com/a/60213219/1321917
  bool _isToday(DateTime date) {
    final DateTime localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate).inDays;
    return diff == 0 && now.day == localDate.day;
  }
}
