import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

/// Ask the host whether a media send may start for this conversation.
///
/// For the entry points that are NOT attachment options and therefore cannot
/// be switched off through `TencentCloudChatMessageAttachmentConfig`'s
/// `enableSend*` flags: hold-to-record, desktop drag & drop, clipboard paste.
/// Call it BEFORE the permission prompt / confirmation dialog, so a host whose
/// backend cannot carry media for this conversation never makes the user
/// record, confirm, and then watch the send fail.
///
/// Returns false when the host refused (it is expected to explain why).
bool tencentCloudChatAllowMediaSend(
  BuildContext context, {
  required String kind,
  String? userID,
  String? groupID,
  String? topicID,
}) {
  final guard = TencentCloudChat.instance.dataInstance.messageData.messageConfig
      .attachmentConfig(userID: userID, groupID: groupID, topicID: topicID)
      .mediaSendGuard;
  return guard?.call(context, kind: kind, userID: userID, groupID: groupID) ??
      true;
}

/// The [tencentCloudChatAllowMediaSend] `kind` of a message that carries a
/// media payload (`image`, `voice`, `file` — video travels as a file), or null
/// for anything else. A message that also carries text is not media: senders
/// dispatch it on its text.
///
/// Decided by `elemType` first: an INCOMING media message that has not been
/// downloaded yet has no image/sound/video/file elem at all (Tim2Tox only
/// builds one once a local path exists), so an elem-presence check called it
/// "not media" and forwarding it into a group skipped the refusal. The elem
/// check stays as the fallback for messages built without an elemType.
String? tencentCloudChatMediaKindOf(V2TimMessage message) {
  if (message.textElem != null) return null;
  switch (message.elemType) {
    case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
      return 'image';
    case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
      return 'voice';
    case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
    case MessageElemType.V2TIM_ELEM_TYPE_FILE:
      return 'file';
  }
  if (message.imageElem != null) return 'image';
  if (message.soundElem != null) return 'voice';
  if (message.videoElem != null || message.fileElem != null) return 'file';
  return null;
}

/// Forward picker: the GROUP targets the host refuses media for, asked once per
/// group through [tencentCloudChatAllowMediaSend] (the host explains the
/// refusal) — only when [messages] contain media at all. Media messages are
/// then not sent to those groups; text still is. Without this a media forward
/// into a group was attempted, failed below the UI, and was never reported.
/// Refusals keyed by GROUP and KIND: `"<groupID>\u0000<kind>"`. A host that
/// refuses images but allows voice must lose only the images, so the caller
/// skips a message when ITS kind is refused for that group — not every media
/// message in the selection.
String mediaRefusalKey(String groupID, String kind) => '$groupID\u0000$kind';

Set<String> tencentCloudChatMediaRefusedGroupTargets(
  BuildContext context,
  List<V2TimMessage> messages,
  List<({String? userID, String? groupID})> chats,
) {
  // Every media kind in the selection, not just the first: a host that
  // refuses only some kinds must be asked about each one it would receive.
  final kinds = <String>{};
  for (final message in messages) {
    final kind = tencentCloudChatMediaKindOf(message);
    if (kind != null) kinds.add(kind);
  }
  if (kinds.isEmpty) return const {};
  final refused = <String>{};
  final asked = <String>{}; // (group, kind) pairs already put to the host
  for (final chat in chats) {
    final groupID = chat.groupID;
    if (groupID == null || groupID.isEmpty) continue;
    for (final kind in kinds) {
      // The same group can appear twice in a forward selection; the host is
      // asked once per (group, kind), as it was once per group before.
      if (!asked.add(mediaRefusalKey(groupID, kind))) continue;
      if (!tencentCloudChatAllowMediaSend(context,
          kind: kind, groupID: groupID)) {
        refused.add(mediaRefusalKey(groupID, kind));
      }
    }
  }
  return refused;
}
