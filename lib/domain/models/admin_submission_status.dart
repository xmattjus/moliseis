/// Moderation status of a content submission.
///
/// Mirrors the backend `public.submission_status` enum exactly.
enum AdminSubmissionStatus {
  pending('Da revisionare'),
  accepted('Accettato'),
  rejected('Rifiutato')
  ;

  const AdminSubmissionStatus(this.label);

  /// Italian display label used by the dashboard and editor.
  final String label;
}
