import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/admin_submission.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/utils/extensions/date_time_extensions.dart';

/// A tappable dashboard row describing one moderation submission.
class AdminSubmissionListItem extends StatelessWidget {
  /// Creates a dashboard list item for [summary].
  const AdminSubmissionListItem({
    required this.summary,
    required this.onTap,
    super.key,
  });

  /// The summary displayed by this row.
  final AdminSubmission summary;

  /// Opens the editor for [summary].
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final type = summary.isEvent ? 'Evento' : 'Luogo';

    return CardBase(
      onPressed: onTap,
      child: ListTile(
        title: Text(summary.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(summary.city),
            Text('$type · ${summary.status.label}'),
            Text(
              '${summary.userName} · ${summary.createdAt.formatDate(locale)}',
            ),
          ],
        ),
      ),
    );
  }
}
