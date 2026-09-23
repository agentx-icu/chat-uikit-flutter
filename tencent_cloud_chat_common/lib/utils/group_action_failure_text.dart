import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

/// toxee: user-facing reason for a failed group action (kick, set / dismiss
/// admin, mute, invite, editing the announcement), derived from the code the
/// Tim2Tox group manager returns (V2TIMGroupManagerImpl):
///   * 10007 = our role does not allow it (ERR_SVR_GROUP_PERMISSION_DENY) —
///     toxcore's *_PERMISSIONS refusals: kicking or changing the role of a
///     member at or above our own role, a non-moderator muting, setting the
///     NGC topic (announcement) under the topic lock;
///   * 7013 = this kind of group cannot do it at all
///     (ERR_SDK_INTERFACE_NOT_SUPPORT) — legacy conferences have no moderation,
///     a moderator cannot be muted;
///   * 6013 = Tox not up yet (ERR_SDK_NOT_INITIALIZED).
/// Anything else gets the action-specific [fallback]. Localized through the
/// fork's `tL10n`.
///
/// Lives in the common package (re-exported by
/// `tencent_cloud_chat_contact/widgets/group_action_failure_text.dart`) so the
/// group-profile widgets in the message package report failures the same way.
String groupActionFailureText(int code, String fallback) {
  switch (code) {
    case 10007:
      return tL10n.groupActionNoPermission;
    case 7013:
      return tL10n.groupActionNotSupported;
    case 6013:
      return tL10n.groupActionNotConnected;
    default:
      return fallback;
  }
}
