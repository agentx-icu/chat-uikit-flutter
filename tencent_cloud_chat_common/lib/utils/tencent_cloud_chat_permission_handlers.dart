import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_platform_adapter.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/widgets/dialog/tencent_cloud_chat_dialog.dart';

class TencentCloudChatPermissionHandler {
  // toxee: WHY THE NON-ANDROID BRANCHES BELOW READ "iOS" AND macOS IS NOT
  // MENTIONED. `isAndroid` is false on desktop too, so macOS/Linux/Windows fall
  // into the same arms — but that is not a live path and macOS deliberately does
  // NOT get the `ios/Podfile` PERMISSION_* treatment:
  //
  //   1. `permission_handler` 11.4.0 ships NO macOS implementation. The endorsed
  //      federated packages are permission_handler_android,
  //      permission_handler_apple (an iOS-only pod) and permission_handler_html
  //      — see pubspec.lock. There is no pod for `macos/Podfile` to configure,
  //      so a `PERMISSION_PHOTOS=1` line there would be inert.
  //   2. Every reachable caller of `checkPermission` for these media strings is
  //      already gated on `isAndroid` / `isMobile`: the file bubble's `_openFile`
  //      (message_file.dart), the attachment pickers (input_container.dart), the
  //      camera sheet and the mobile composer. Desktop media access runs through
  //      out-of-process pickers (FilePicker -> NSOpenPanel), which grant
  //      per-file access with no runtime permission to request.
  //   3. `macos/Runner/Info.plist` already carries NSPhotoLibraryUsageDescription
  //      for the day some macOS path does touch PHPhotoLibrary directly.
  //
  // If a desktop path ever DOES reach here, the right fix is a `null` (no gate)
  // for these strings on non-mobile platforms — never a Podfile macro for a pod
  // that does not exist.
  static Future<Permission?> getPermissionEnum(String permissionString) async {
    switch (permissionString) {
      case 'camera':
        return Permission.camera;
      case 'microphone':
        return Permission.microphone;
      case 'storage':
      case 'photo':
      case 'photos':
        // toxee(P0): never request MANAGE_EXTERNAL_STORAGE on Android 13+ —
        // Play Store rejects apps that request the all-files-access permission
        // for media use-cases. Route 'storage'/'photo'/'photos' to the
        // scoped READ_MEDIA_IMAGES permission (Permission.photos on Android 13+).
        // Pre-Android-13 still uses legacy READ_EXTERNAL_STORAGE.
        if (TencentCloudChatPlatformAdapter().isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (androidInfo.version.sdkInt <= 32) {
            return Permission.storage;
          } else {
            return Permission.photos;
          }
        }
        return Permission.photos;
      // toxee(P0): `Permission.videos` and `Permission.audio` are ANDROID-ONLY
      // permissions (READ_MEDIA_VIDEO / READ_MEDIA_AUDIO, API 33+). Asking for
      // either on iOS is not merely useless, it is UNSATISFIABLE — and it fails
      // in a way that looks like a user denial:
      //
      //   * `Permission.videos` is index 32 and `Permission.audio` index 33 in
      //     permission_handler_platform_interface's `Permission` table; those
      //     ints are handed to the iOS plugin verbatim as
      //     `PermissiongroupVideos` / `PermissionGroupAudio`.
      //   * `permission_handler_apple`'s `PermissionManager.createPermissionStrategy:`
      //     has NO case for either group, so both fall to
      //     `default: return [UnknownPermissionStrategy new]`.
      //   * `UnknownPermissionStrategy` never consults iOS at all:
      //     `checkPermissionStatus:` hardcodes `PermissionStatusDenied` and
      //     `requestPermission:...` hardcodes `PermissionStatusPermanentlyDenied`.
      //
      // So `Permission.videos.request()` on iOS ALWAYS resolves to
      // permanentlyDenied, which drives `checkPermission` below straight into
      // its "go to Settings" dialog — pointing the user at a toggle that does
      // not and cannot exist. Unlike the microphone/camera/photos breakage this
      // is NOT fixable from `ios/Podfile` (there is no `PERMISSION_VIDEOS` /
      // `PERMISSION_AUDIO` opt-in macro; the strategy class simply does not
      // exist) nor from `Info.plist` (there is no usage-description key for an
      // Android media-read permission). The fix has to be here: never route a
      // non-Android platform at an Android-only permission.
      case 'video':
      case 'videos':
        if (TencentCloudChatPlatformAdapter().isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (androidInfo.version.sdkInt <= 32) {
            return Permission.storage;
          } else {
            return Permission.videos;
          }
        }
        // iOS: videos are Photos-library assets, gated by the SAME
        // NSPhotoLibraryUsageDescription / PHPhotoLibrary authorisation as
        // images — `Permission.photos` (PhotoPermissionStrategy, already
        // enabled through `PERMISSION_PHOTOS=1` in ios/Podfile).
        return Permission.photos;
      case 'audio':
      case 'audios':
        if (TencentCloudChatPlatformAdapter().isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (androidInfo.version.sdkInt <= 32) {
            return Permission.storage;
          } else {
            return Permission.audio;
          }
        }
        // iOS: reading an audio FILE needs no runtime permission — the picker
        // is UIDocumentPicker/Files, which grants per-file access out of
        // process. `Permission.mediaLibrary` is deliberately NOT used: it is
        // the Apple Music library (NSAppleMusicUsageDescription), a different
        // corpus this app never touches, and requesting it without that
        // usage-description string would terminate the app. `null` means "no
        // gate on this platform" and `checkPermission` reports success.
        return null;
      default:
        return null;
    }
  }

  static Future<bool> checkPermission(String permissionString, BuildContext context) async {
    final permission = await getPermissionEnum(permissionString);
    if (permission != null) {
      PermissionStatus prevStatus = await permission.status;
      PermissionStatus requestResult = await permission.request();
      if (requestResult.isDenied || requestResult.isPermanentlyDenied) {
        final permission = TencentCloudChat.instance.cache.getPermission();
        final exist = permission.contains(permissionString);
        if (!exist) {
          TencentCloudChat.instance.cache.cachePermission(permissionString);
          return false;
        } else {
          // toxee(double-pop guard): these action buttons capture the OUTER
          // `context` (this method's param) and are handed to showAdaptiveDialog
          // as a PREBUILT `actions:` list, so popDialogIfCurrent would test the
          // page route, not the dialog. Use a one-shot flag shared across the
          // two buttons (only one is reachable per dialog instance) so a
          // double-fired onPressed cannot pop the page underneath.
          var handled = false;
          TencentCloudChatDialog.showAdaptiveDialog(
            context: context,
            title: Text(tL10n.permissionDeniedTitle),
            content: Text(tL10n.permissionDeniedContent(permissionString)),
            actions: [
              TextButton(
                child: Text(tL10n.goToSettingsButtonText),
                onPressed: () async {
                  if (handled) return;
                  handled = true;
                  Navigator.pop(context);
                  await openAppSettings();
                },
              ),
              TextButton(
                child: Text(tL10n.cancel),
                onPressed: () async {
                  if (handled) return;
                  handled = true;
                  Navigator.pop(context);
                },
              ),
            ],
          );
          return false;
        }
      }

      /// Special case for `microphone`
      if (permission == Permission.microphone && (prevStatus.isDenied || prevStatus.isPermanentlyDenied)) {
        return false;
      }

      if (requestResult.isGranted || requestResult.isLimited || requestResult.isRestricted) {
        return true;
      } else {
        PermissionStatus newStatus = await permission.request();
        return newStatus.isGranted;
      }
    } else {
      return true;
    }
  }
}
