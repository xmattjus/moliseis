import 'dart:async' show unawaited;

import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/app_show_modal_bottom_sheet.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_modal.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class WeatherForecastButton extends StatefulWidget {
  const WeatherForecastButton({
    required this.content,
    required this.coordinates,
    required this.viewModel,
    super.key,
  });

  final ContentBase content;
  final LatLng coordinates;
  final WeatherViewModel viewModel;

  @override
  State<WeatherForecastButton> createState() => _WeatherForecastButtonState();
}

class _WeatherForecastButtonState extends State<WeatherForecastButton> {
  /// Last admitted owner and semantic target; never uses model object identity.
  (WeatherViewModel, (Type, int, double, double))? _submitted;
  bool _requestScheduled = false;
  Command1<CurrentWeatherForecastData, LatLng>? _waitingCommand;

  /// Current content identity and numeric coordinates.
  (Type, int, double, double) get _target => (
    widget.content.runtimeType,
    widget.content.remoteId,
    widget.coordinates.latitude,
    widget.coordinates.longitude,
  );

  @override
  void initState() {
    super.initState();
    _scheduleRequest();
  }

  @override
  void didUpdateWidget(covariant WeatherForecastButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ownerChanged = !identical(oldWidget.viewModel, widget.viewModel);
    final oldTarget = (
      oldWidget.content.runtimeType,
      oldWidget.content.remoteId,
      oldWidget.coordinates.latitude,
      oldWidget.coordinates.longitude,
    );
    if (ownerChanged) _detachWaiter();
    if (ownerChanged || oldTarget != _target) _scheduleRequest();
  }

  /// Coalesces admission and resolves only the currently desired target.
  void _scheduleRequest() {
    if (_requestScheduled) return;
    _requestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestScheduled = false;
      if (!mounted) return;
      final owner = widget.viewModel;
      final desired = (owner, _target);
      if (_submitted == desired) return;
      final command = owner.loadCurrentForecast;
      if (command.running) {
        if (!identical(_waitingCommand, command)) {
          _detachWaiter();
          _waitingCommand = command;
          command.addListener(_onWaitingCommandChanged);
        }
        return;
      }
      _detachWaiter();
      _submitted = desired;
      unawaited(command.execute(widget.coordinates));
    });
  }

  /// Admits the latest target once its single-flight owner is available.
  void _onWaitingCommandChanged() {
    if (_waitingCommand?.running ?? true) return;
    _detachWaiter();
    if (mounted) _scheduleRequest();
  }

  /// Removes the temporary terminal observer before owner replacement/disposal.
  void _detachWaiter() {
    _waitingCommand?.removeListener(_onWaitingCommandChanged);
    _waitingCommand = null;
  }

  @override
  void dispose() {
    _detachWaiter();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return ListenableBuilder(
      listenable: viewModel.loadCurrentForecast,
      builder: (context, child) {
        final ready =
            _submitted == (viewModel, _target) &&
            !viewModel.loadCurrentForecast.running &&
            viewModel.loadCurrentForecast.completed;
        final icon = Icon(
          ready ? viewModel.currentWeatherCodeIcon : Symbols.question_mark,
        );
        final temperatureText = Text(
          ready ? '${viewModel.currentTemperatureCelsius} °C' : '--.- °C',
        );

        if (ready) {
          return FilledButton.tonalIcon(
            onPressed: () async {
              final coordinates = widget.coordinates;
              final content = widget.content;
              // Start loading the hourly and daily weather forecast before
              // showing the modal.
              unawaited(viewModel.loadHourlyForecast.execute(coordinates));
              unawaited(viewModel.loadDailyForecast.execute(coordinates));

              await appShowModalBottomSheet<void>(
                context: context,
                builder: (_) {
                  return WeatherForecastModal(
                    content: content,
                    viewModel: viewModel,
                  );
                },
                isScrollControlled: true,
              );
            },
            style: FilledButton.styleFrom(
              foregroundColor: context.colorScheme.onTertiaryContainer,
              backgroundColor: context.colorScheme.tertiaryContainer,
            ),
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
