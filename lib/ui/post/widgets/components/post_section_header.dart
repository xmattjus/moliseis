import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/widgets/weather_forecast_button.dart';

/// Displays the post title and weather forecast button in a row.
///
/// Provides a consistent layout for displaying content title alongside
/// weather information, with standardized spacing and alignment across all
/// post contexts.
class PostSectionHeader extends StatelessWidget {
  const PostSectionHeader({
    super.key,
    required this.content,
    required this.weatherViewModel,
  });

  final ContentBase content;
  final WeatherViewModel weatherViewModel;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16.0,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8.0,
                children: <Widget>[
                  ContentNameAndCity(
                    name: content.name,
                    cityName: content.city.target?.name,
                    nameStyle: AppTextStyles.title(context),
                    cityNameStyle: AppTextStyles.subtitle(context),
                    overflow: TextOverflow.visible,
                  ),
                  if (content case final EventContent event)
                    EventFormattedDateTime(event: event),
                ],
              ),
            ),
            WeatherForecastButton(
              content: content,
              coordinates: content.coordinates,
              viewModel: weatherViewModel,
            ),
          ],
        ),
      ),
    );
  }
}
