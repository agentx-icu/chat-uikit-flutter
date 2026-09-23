import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

/// toxee: identity of a group member (a member-list row, or the sender of a
/// group message).
///
/// A Tox NGC group identifies every peer by a PER-GROUP public key, not by the
/// peer's long-term key (the one inside their Tox ID). Nothing on the wire maps
/// one to the other, so for other members of an NGC group the `userID` is a key
/// that is only meaningful inside that group: it is not a Tox ID, it cannot be
/// added as a friend, and it never matches a contact. Only two cases resolve to
/// a real identity:
///   * SELF — our own row carries our long-term key.
///   * a legacy conference peer — conferences expose long-term keys, so a
///     friend in the conference matches their contact entry.
/// UI must therefore only offer "Tox ID" / profile / friend actions when
/// [resolveGroupMemberUserID] returns an id, and label the raw key honestly
/// otherwise.
///
/// A third case resolves when the host app knows it: a FRIEND in an NGC group
/// whose per-group key the friend proved to us over the (authenticated)
/// friend channel — see [groupMemberFriendKeyResolver].
///
/// Lives in the common package (re-exported by
/// `tencent_cloud_chat_contact/widgets/group_member_identity.dart`) so the
/// message package — sender avatars in a group chat — resolves members the
/// same way the member list does.

/// toxee: set by the host app. Maps an NGC per-group member key to the
/// long-term public key of the friend it belongs to, or null when unknown.
String? Function(String memberKey)? groupMemberFriendKeyResolver;

String _publicKey(String id) =>
    (id.length >= 64 ? id.substring(0, 64) : id).toUpperCase();

bool _sameIdentity(String a, String b) {
  if (a == b) return true;
  // Tox IDs (76 chars) and bare public keys (64 chars) name the same identity
  // when their 64-char public-key prefix matches.
  return a.length >= 64 && b.length >= 64 && _publicKey(a) == _publicKey(b);
}

/// The contact-world user id a group member resolves to — the logged-in
/// user's id for self, the friend's `userID` for a known friend — or null when
/// [memberID] is a key that identifies nobody outside the group.
String? resolveGroupMemberUserID(String memberID) {
  if (memberID.isEmpty) return null;
  final loginID =
      TencentCloudChat.instance.dataInstance.basic.currentUser?.userID;
  if (loginID != null && loginID.isNotEmpty && _sameIdentity(memberID, loginID)) {
    return loginID;
  }
  final friends = TencentCloudChat.instance.dataInstance.contact.contactList;
  for (final friend in friends) {
    if (_sameIdentity(memberID, friend.userID)) return friend.userID;
  }
  final friendKey = groupMemberFriendKeyResolver?.call(memberID);
  if (friendKey != null && friendKey.isNotEmpty) {
    for (final friend in friends) {
      if (_sameIdentity(friendKey, friend.userID)) return friend.userID;
    }
  }
  return null;
}
