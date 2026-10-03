/// Stable moderation errors exercised at transport, ViewModel and UI
/// boundaries.
const adminModerationErrorCases = <(String, int, String)>[
  ('NOT_EVENT_SUBMISSION', 422, 'Imposta una data di inizio'),
  ('START_DATE_REQUIRED', 422, 'Imposta una data di inizio'),
  ('INVALID_DATE_RANGE', 422, 'Correggi le date'),
  ('SOURCE_CHANGED', 409, 'La fonte è cambiata'),
  ('EVENT_CHANGED', 409, 'I dati sono cambiati'),
  ('SUBMISSION_CHANGED', 409, 'I dati sono cambiati'),
  ('NORMALIZATION_MISMATCH', 409, 'richiede una migrazione'),
  ('RELINK_CONFLICT', 409, 'collegato a un altro evento'),
  ('CITY_NOT_FOUND', 422, 'La città non corrisponde'),
  ('PROMOTION_SOURCE_ALREADY_LINKED', 409, 'La fonte è già collegata'),
];
