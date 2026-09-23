import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_common/components/component_options/tencent_cloud_chat_group_member_info_options.dart';
import 'package:tencent_cloud_chat_common/components/component_options/tencent_cloud_chat_user_profile_options.dart';
import 'package:tencent_cloud_chat_common/router/tencent_cloud_chat_navigator.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/utils/group_member_identity.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_utils.dart';
import 'package:tencent_cloud_chat_common/utils/tox_group_kind.dart';

/// toxee: open whoever sent [message] — the avatar tap in the message list
/// (desktop row and mobile row share this).
///
/// In a Tox NGC group `message.sender` is the sender's PER-GROUP key, not a
/// Tox ID (see group_member_identity.dart): opening a user profile for it
/// showed a stranger with a fake "Tox ID" and add-friend actions that can
/// never work. So in a group the sender is resolved first — self, a friend in
/// a conference, or a friend who proved their per-group key open their real
/// profile — and anyone else opens the group member-info page, exactly like
/// tapping their row in the member list.
///
/// [groupID] is the conversation's group when the message itself does not
/// carry one.
void openMessageSender(
  BuildContext context,
  V2TimMessage message, {
  String? groupID,
}) {
  final sender = TencentCloudChatUtils.checkString(message.sender);
  if (sender == null) return;
  final gid = TencentCloudChatUtils.checkString(message.groupID) ??
      TencentCloudChatUtils.checkString(groupID);
  if (gid == null) {
    // One-to-one chat: the sender is the peer's real Tox identity.
    navigateToUserProfile(
      context: context,
      options: TencentCloudChatUserProfileOptions(userID: sender),
    );
    return;
  }
  final resolved = resolveGroupMemberUserID(sender);
  if (resolved != null) {
    navigateToUserProfile(
      context: context,
      options: TencentCloudChatUserProfileOptions(userID: resolved),
    );
    return;
  }
  showGroupMemberInfo(
    context: context,
    options: TencentCloudChatGroupMemberInfoOptions(
      memberFullInfo: groupMemberInfoForSender(gid, message),
      groupType: knownGroupTypeOf(gid),
    ),
  );
}

/// The member row of [message]'s sender in [groupID] — from the cached member
/// list when it is loaded (role, join time), else built from what the message
/// itself carries.
V2TimGroupMemberFullInfo groupMemberInfoForSender(
  String groupID,
  V2TimMessage message,
) {
  final sender = message.sender ?? '';
  final key = sender.toUpperCase();
  final cached = TencentCloudChat.instance.dataInstance.groupProfile
      .getGroupMemberList(groupID);
  for (final member in cached) {
    if (member != null && member.userID.toUpperCase() == key) return member;
  }
  return V2TimGroupMemberFullInfo(
    userID: sender,
    nickName: message.nickName,
    nameCard: message.nameCard,
    faceUrl: message.faceUrl,
  );
}
