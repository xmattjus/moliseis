import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/text_style.dart';

class StoryAuthor extends StatelessWidget {
  const StoryAuthor({super.key, required this.s});

  final String s;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        Text('Autore', style: CustomTextStyles.section(context)),
        const SizedBox(height: 8.0),
        Row(
          spacing: 8.0,
          children: <Widget>[
            CircleAvatar(maxRadius: 18.0, child: Text(s.substring(0, 1))),
            Text(s),
          ],
        ),
      ],
    );
  }
}
