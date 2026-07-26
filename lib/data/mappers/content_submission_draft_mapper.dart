import 'package:moliseis/data/data-sources/content_submission_draft_entry.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_submission_draft.dart';

extension ContentSubmissionDraftEntityMapper on ContentSubmissionDraftEntity {
  ContentSubmissionDraft toModel() => ContentSubmissionDraft(
    category: categoryIndex != null
        ? contentCategoryFromIndex(categoryIndex!)
        : null,
    city: city,
    name: name,
    description: description,
    startDate: startDate,
    endDate: endDate,
    userEmail: authorEmail,
    userName: authorName,
    acceptedTerms: acceptedTerms,
  );
}

extension ContentSubmissionDraftMapper on ContentSubmissionDraft {
  ContentSubmissionDraftEntity toEntity() => ContentSubmissionDraftEntity(
    categoryIndex: category?.index,
    city: city,
    name: name,
    description: description,
    startDate: startDate,
    endDate: endDate,
    authorEmail: userEmail,
    authorName: userName,
    acceptedTerms: acceptedTerms,
  );
}
