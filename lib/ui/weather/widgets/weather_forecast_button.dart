import 'dart:async' show unawaited;

import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/core/ui/app_show_modal_bottom_sheet.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/components/weather_forecast_modal.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result_command.dart';

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
  bool _requestScheduled = false;
  Object? _opening;
  VoidCallback? _cancelOpening;

  WeatherTarget get _target => (
    id: widget.content.remoteId,
    type: widget.content is Event ? ContentType.event : ContentType.place,
    latitude: widget.coordinates.latitude,
    longitude: widget.coordinates.longitude,
  );

  @override
  void initState() {
    super.initState();
    widget.viewModel.loadCurrentForecast.results.addListener(_onCurrentChanged);
    _scheduleRequest();
  }

  @override
  void didUpdateWidget(covariant WeatherForecastButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      oldWidget.viewModel.loadCurrentForecast.results.removeListener(
        _onCurrentChanged,
      );
      widget.viewModel.loadCurrentForecast.results.addListener(
        _onCurrentChanged,
      );
      _cancelOpening?.call();
    } else if (oldWidget.content.remoteId != widget.content.remoteId ||
        oldWidget.content.runtimeType != widget.content.runtimeType ||
        oldWidget.coordinates != widget.coordinates) {
      _cancelOpening?.call();
    }
    _scheduleRequest();
  }

  void _onCurrentChanged() {
    if (!mounted) return;
    final owner = widget.viewModel;
    final snapshot = owner.loadCurrentForecast.results.value;
    if (snapshot.idle || owner.isDisposed || owner.currentTarget != _target) {
      _cancelOpening?.call();
    }
    if (snapshot.idle) _scheduleRequest();
  }

  void _scheduleRequest() {
    if (_requestScheduled) return;
    _requestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestScheduled = false;
      widget.viewModel.requestCurrent(_target);
    });
  }

  Future<void> _openModal(
    WeatherViewModel expectedOwner,
    WeatherTarget expectedTarget,
  ) async {
    if (!mounted) return;
    final owner = widget.viewModel;
    final target = _target;
    if (!identical(owner, expectedOwner) || target != expectedTarget) return;
    final content = widget.content;
    final snapshot = owner.loadCurrentForecast.results.value;
    if (_opening != null ||
        owner.isDisposed ||
        owner.currentTarget != target ||
        owner.currentTemperatureCelsius == '--.-' ||
        snapshot.paramData != target ||
        !snapshot.completed ||
        owner.loadCurrentForecast.isRunningSync.value) {
      return;
    }
    final token = Object();
    _opening = token;
    final navigator = Navigator.of(context);
    ModalBottomSheetRoute<void>? route;
    var revoked = false;
    var pushed = false;
    void cancel() {
      if (revoked) return;
      revoked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final captured = route;
        if (!navigator.mounted || captured == null || !captured.isActive) {
          return;
        }
        if (captured.isCurrent) {
          navigator.pop();
        } else {
          navigator.removeRoute(captured);
        }
      });
    }

    _cancelOpening = cancel;
    try {
      owner
        ..requestHourly(target)
        ..requestDaily(target);
      if (revoked ||
          !mounted ||
          !identical(owner, widget.viewModel) ||
          owner.isDisposed ||
          owner.currentTarget != target ||
          _target != target) {
        return;
      }
      final future = appShowModalBottomSheet<void>(
        context: context,
        onRouteCreated: (created) => route = created,
        builder: (_) {
          if (revoked || owner.isDisposed || owner.currentTarget != target) {
            cancel();
            return const SizedBox.shrink();
          }
          return WeatherForecastModal(
            content: content,
            viewModel: owner,
            expectedTarget: target,
          );
        },
        isScrollControlled: true,
      );
      pushed = true;
      await future;
    } finally {
      if (pushed) await route!.completed;
      if (mounted && identical(_opening, token)) {
        _opening = null;
        _cancelOpening = null;
      }
    }
  }

  @override
  void dispose() {
    widget.viewModel.loadCurrentForecast.results.removeListener(
      _onCurrentChanged,
    );
    _cancelOpening?.call();
    _opening = null;
    _cancelOpening = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.viewModel;
    return ListenableBuilder(
      listenable: owner.loadCurrentForecast.results,
      builder: (context, _) {
        final snapshot = owner.loadCurrentForecast.results.value;
        final ready =
            !owner.isDisposed &&
            owner.currentTarget == _target &&
            owner.currentTemperatureCelsius != '--.-' &&
            snapshot.paramData == _target &&
            snapshot.completed &&
            !owner.loadCurrentForecast.isRunningSync.value;
        final target = _target;
        return FilledButton.tonalIcon(
          onPressed: ready ? () => unawaited(_openModal(owner, target)) : null,
          style: ready
              ? FilledButton.styleFrom(
                  foregroundColor: context.colorScheme.onTertiaryContainer,
                  backgroundColor: context.colorScheme.tertiaryContainer,
                )
              : null,
          icon: Icon(
            ready ? owner.currentWeatherCodeIcon : Symbols.question_mark,
          ),
          label: Text(
            ready ? '${owner.currentTemperatureCelsius} °C' : '--.- °C',
          ),
        );
      },
    );
  }
}
