import 'dart:async';

import 'package:image_picker/image_picker.dart';

/// Shared fake for [ImagePicker] that delegates to optional callbacks.
///
/// Uses callbacks rather than pre-configured result values to support
/// [Completer]-based in-flight tests (see
/// `content_submission_add_asset_form_test.dart`).
///
/// When callbacks are `null`, returns empty/default responses.
final class FakeImagePicker extends ImagePicker {
  FakeImagePicker({this.onPickMultipleMedia, this.onRetrieveLostData});

  final Future<List<XFile>> Function()? onPickMultipleMedia;
  final Future<LostDataResponse> Function()? onRetrieveLostData;

  /// Picker limits supplied by callers, in invocation order.
  final pickMultipleMediaLimits = <int?>[];

  @override
  Future<List<XFile>> pickMultipleMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    pickMultipleMediaLimits.add(limit);
    return onPickMultipleMedia != null ? await onPickMultipleMedia!() : [];
  }

  @override
  Future<LostDataResponse> retrieveLostData() async =>
      onRetrieveLostData != null
      ? await onRetrieveLostData!()
      : LostDataResponse.empty();
}
