import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/utils/command.dart';

/// Displays nearby content in a horizontal scrollable list.
///
/// Provides a reusable section for displaying content recommendations near
/// the current location, with customizable data source handling through
/// command and list parameters.
class PostSectionNearbyContent extends StatelessWidget {
  const PostSectionNearbyContent({
    super.key,
    required this.coordinates,
    required this.onContentPressed,
    required this.loadNearContentCommand,
    required this.nearContent,
  });

  final LatLng coordinates;
  final void Function(ContentBase content) onContentPressed;
  final Command1<void, LatLng> loadNearContentCommand;
  final List<ContentBase> nearContent;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: NearbyContentHorizontalList(
        coordinates: coordinates,
        onPressed: onContentPressed,
        loadNearContentCommand: loadNearContentCommand,
        nearContent: nearContent,
      ),
    );
  }
}
