import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/utils/tox_group_kind.dart';

/// toxee: set by the host app. Whether the logged-in user may change the
/// announcement of the group `groupID` RIGHT NOW — true / false — or null when
/// the host cannot tell (then [canEditGroupAnnouncement] falls back to the
/// V2TIM role).
///
/// An NGC group's announcement is its Tox topic, and toxcore decides who may
/// set it from the group's TOPIC LOCK (on by default: founder + moderators
/// only; off: everyone but observers) plus our live role — state that
/// `V2TimGroupInfo` cannot carry. The host answers from the Tox instance.
bool? Function(String groupID)? groupAnnouncementEditableResolver;

/// Whether to offer "edit announcement" for [groupInfo].
///
/// A legacy conference has no topic: its announcement is a local note that
/// never fails for lack of permission, so it stays editable.
///
/// Tim2Tox reports every NGC group as `GroupType.Work`, so UIKit's stock rule
/// ("anyone may edit a Work group's notification") offered the edit to plain
/// members, whose topic change toxcore then refused under the topic lock —
/// silently. Decide instead by what the network will accept.
bool canEditGroupAnnouncement(V2TimGroupInfo groupInfo) {
  if (isToxConferenceGroupType(groupInfo.groupType)) return true;
  final live = groupAnnouncementEditableResolver?.call(groupInfo.groupID);
  if (live != null) return live;
  // Unknown lock state: assume the default (locked), where only the founder
  // and moderators may set the topic. `role` is nullable in the SDK model and
  // this runs inside build(): unknown means "cannot edit", never a throw.
  final role = groupInfo.role ?? GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER;
  return role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER ||
      role == GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN;
}
