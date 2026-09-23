import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

/// toxee: a legacy Tox conference (text or AV) rather than an NGC group.
/// Tim2Tox reports its stored kind ("conference" / "av_conference"); the
/// conversation layer shows text conferences as `AVChatRoom`. Every NGC group
/// is reported as `Work` (private) or `Public`.
///
/// The two kinds identify members differently: a conference peer is named by
/// their LONG-TERM public key (the one inside their Tox ID), an NGC member by
/// a key that exists only inside that one group.
bool isToxConferenceGroupType(String? groupType) {
  switch (groupType?.trim().toLowerCase()) {
    case 'conference':
    case 'av_conference':
    case 'avchatroom':
      return true;
    default:
      return false;
  }
}

/// The group type the UIKit data layer knows for [groupID] — the joined-group
/// list first (Tim2Tox's stored kind), then the conversation list — or null.
/// For callers that only have a group id (e.g. a message).
String? knownGroupTypeOf(String groupID) {
  if (groupID.isEmpty) return null;
  final data = TencentCloudChat.instance.dataInstance;
  for (final group in data.contact.groupList) {
    if (group.groupID == groupID && group.groupType.isNotEmpty) {
      return group.groupType;
    }
  }
  for (final conversation in data.conversation.conversationList) {
    if (conversation.groupID == groupID) {
      final type = conversation.groupType;
      if (type != null && type.isNotEmpty) return type;
    }
  }
  return null;
}
