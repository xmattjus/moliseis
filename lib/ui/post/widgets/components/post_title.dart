import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/core/themes/text_styles.dart';
import 'package:moliseis/ui/core/ui/content/content_name_and_city.dart';

class PostTitle extends StatelessWidget {
  final ContentBase content;

  const PostTitle({super.key, required this.content});

  @override
  Widget build(BuildContext context) => Expanded(
    child: ContentNameAndCity(
      name: content.name,
      cityName: content.city.target?.name,
      nameStyle: AppTextStyles.title(context),
      cityNameStyle: AppTextStyles.subtitle(context),
      overflow: TextOverflow.visible,
    ),
  );
}
