import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:moliseis/data/services/remote/open-meteo/hourly_weather_forecast_response.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/result.dart';

class OpenMeteoClient {
  final _log = Logger('Open-MeteoClient');

  Future<Result<HourlyWeatherForecastResponse>> getHourlyWeatherForecast(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=$latitude&"
        "longitude=$longitude&hourly=temperature_2m,relative_humidity_2m,"
        "apparent_temperature,precipitation,precipitation_probability,"
        "weather_code&timezone=Europe%2FBerlin&forecast_days=1",
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'com.benitomatteobercini.moliseis/2.0',
            },
          )
          .timeout(const Duration(seconds: kDefaultNetworkTimeoutSeconds));

      if (response.statusCode == 200) {
        final jsonData = HourlyWeatherForecastResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );

        return Result.success(jsonData);
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on TimeoutException catch (error) {
      _log.warning(const NetworkTimeoutException());
      return Result.error(error);
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'An exception occurred while getting hourly weather forecast.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }
}
