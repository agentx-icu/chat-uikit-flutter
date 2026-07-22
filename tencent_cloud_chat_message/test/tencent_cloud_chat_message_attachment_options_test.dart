import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_input/mobile/tencent_cloud_chat_message_attachment_options.dart';

void main() {
  test('attachment overlay clamps to the trailing screen edge', () {
    const placement = AttachmentOverlayLayoutInput(
      viewportSize: Size(360, 720),
      safeArea: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
      tapGlobalDx: 350,
      maxContentWidth: 360,
    );

    final result = computeAttachmentOverlayPlacement(placement);

    expect(result.maxWidth, 328);
    expect(result.left + result.maxWidth, lessThanOrEqualTo(344));
    expect(result.left, 16);
  });

  test('attachment overlay sits above the mobile keyboard and safe area', () {
    const placement = AttachmentOverlayLayoutInput(
      viewportSize: Size(390, 844),
      safeArea: EdgeInsets.only(top: 47, bottom: 34),
      viewInsets: EdgeInsets.only(bottom: 310),
      tapGlobalDx: 24,
      maxContentWidth: 390,
    );

    final result = computeAttachmentOverlayPlacement(placement);

    expect(result.bottom, 326);
    expect(result.left, 16);
    expect(result.maxHeight, 455);
  });
}
