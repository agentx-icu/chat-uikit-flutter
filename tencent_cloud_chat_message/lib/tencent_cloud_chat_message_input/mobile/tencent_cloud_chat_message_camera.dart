import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_platform_adapter.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_permission_handlers.dart';
import 'package:tencent_cloud_chat_common/widgets/modal/bottom_modal.dart';

void dispatchCameraPickerResult({
  required String? path,
  required bool isVideo,
  required Function({required String imagePath}) onSendImage,
  required Function({required String videoPath}) onSendVideo,
}) {
  if (path == null || path.isEmpty) return;
  if (isVideo) {
    onSendVideo(videoPath: path);
  } else {
    onSendImage(imagePath: path);
  }
}

/// A camera result Android kept for a process that was reclaimed while the
/// system camera was in front (see [TencentCloudChatMessageCamera.retrieveLostCapture]).
class LostCameraCapture {
  const LostCameraCapture({this.path, required this.isVideo, this.error});

  /// The captured file in the picker's cache; null with [error].
  final String? path;
  final bool isVideo;
  final String? error;
}

/// Called right before the system camera opens / after the pick returns
/// (success, cancel or error — not when the process dies meanwhile).
typedef CameraCaptureStarting = Future<void> Function({required bool isVideo});
typedef CameraCaptureEnded = Future<void> Function();

class TencentCloudChatMessageCamera {
  /// Android can reclaim the app while the system camera is in front; the
  /// photo / video then comes back to a new process, where no one awaits it.
  /// The picker keeps that result until this is called (which clears it).
  /// Null when there is none; always null off Android.
  static Future<LostCameraCapture?> retrieveLostCapture() async {
    if (!Platform.isAndroid) return null;
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty) return null;
    final file = response.file ??
        ((response.files?.isNotEmpty ?? false) ? response.files!.first : null);
    return LostCameraCapture(
      path: file?.path,
      isVideo: response.type == RetrieveType.video,
      error: response.exception?.message ??
          response.exception?.code ??
          (file == null ? 'no file' : null),
    );
  }

  static Future<void> _cameraPicker({
    required BuildContext context,
    required ImageSource source,
    required bool isVideo,
    required Function({required String imagePath}) onSendImage,
    required Function({required String videoPath}) onSendVideo,
    CameraCaptureStarting? onCaptureStarting,
    CameraCaptureEnded? onCaptureEnded,
  }) async {
    if (TencentCloudChatPlatformAdapter().isMobile &&
        await TencentCloudChatPermissionHandler.checkPermission(
            "camera", context)) {
      await onCaptureStarting?.call(isVideo: isVideo);
      try {
        await _pick(source, isVideo, onSendImage, onSendVideo);
      } finally {
        await onCaptureEnded?.call();
      }
    }
  }

  static Future<void> _pick(
    ImageSource source,
    bool isVideo,
    Function({required String imagePath}) onSendImage,
    Function({required String videoPath}) onSendVideo,
  ) async {
    final ImagePicker picker = ImagePicker();
    if (isVideo) {
      final file = await picker.pickVideo(source: source);
      dispatchCameraPickerResult(
        path: file?.path,
        isVideo: true,
        onSendImage: onSendImage,
        onSendVideo: onSendVideo,
      );
    } else {
      final file = await picker.pickImage(source: source);
      dispatchCameraPickerResult(
        path: file?.path,
        isVideo: false,
        onSendImage: onSendImage,
        onSendVideo: onSendVideo,
      );
    }
  }

  static Future<void> showCameraOptions({
    required BuildContext context,
    required Function({required String imagePath}) onSendImage,
    required Function({required String videoPath}) onSendVideo,
    CameraCaptureStarting? onCaptureStarting,
    CameraCaptureEnded? onCaptureEnded,
  }) async {
    showTencentCloudChatBottomModal(
      context: context,
      actions: [
        TencentCloudChatModalAction(
          label: tL10n.takeAPhoto,
          icon: Icons.photo_camera,
          onTap: () => _cameraPicker(
              source: ImageSource.camera,
              context: context,
              isVideo: false,
              onSendImage: onSendImage,
              onSendVideo: onSendVideo,
              onCaptureStarting: onCaptureStarting,
              onCaptureEnded: onCaptureEnded),
        ),
        TencentCloudChatModalAction(
          label: tL10n.recordAVideo,
          icon: Icons.videocam,
          onTap: () => _cameraPicker(
              source: ImageSource.camera,
              isVideo: true,
              onSendImage: onSendImage,
              context: context,
              onSendVideo: onSendVideo,
              onCaptureStarting: onCaptureStarting,
              onCaptureEnded: onCaptureEnded),
        ),
      ],
    );
  }
}
