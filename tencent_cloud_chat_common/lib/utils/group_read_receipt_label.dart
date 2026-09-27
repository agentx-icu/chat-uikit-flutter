import 'package:tencent_cloud_chat_intl/localizations/tencent_cloud_chat_localizations.dart';

/// toxee: the long-press menu label for a group message's read receipt.
///
/// A `V2TimMessageReceipt` carries `readCount` and `unreadCount`, and both are
/// nullable. `unreadCount == null` is the bridge saying it could not derive the
/// member arithmetic ("members - 1 - readCount") for this row, so the UI cannot
/// establish an EXACT number of members who read from this receipt — `readCount`
/// is the most it can honestly claim, not a count.
///
/// That is not a corner case. A group message's read state survives a restart as
/// a BOOLEAN: reader identities are deliberately never persisted (each member's
/// per-group public key rotates, so a stored reader set would de-anonymize who
/// read what across restarts), so a row read in a previous session comes back
/// with the floor of 1 and no exact count — and never regains one this session.
/// Rendering that floor as `memberReadCount` made a restored row read
/// "1 member read" even when two members had read it before the restart.
///
/// [isAllRead] stays the caller's decision and keeps precedence: it requires an
/// exact `unreadCount == 0`, so a null unread count can never reach it and the
/// "all members read" claim is unaffected by anything here. Likewise the tick
/// itself (`showReadByOthersStatus`) means "at least one member read" and is
/// still true either way.
///
/// A [readCount] of 0 with a null [unreadCount] is NOT a lower bound: the reader
/// tally genuinely says nobody read it and only the membership lookup was
/// unknown, so it keeps the exact wording ("No member read").
String groupReadReceiptMenuLabel({
  required TencentCloudChatLocalizations l10n,
  required bool isAllRead,
  required int? readCount,
  required int? unreadCount,
}) {
  if (isAllRead) {
    return l10n.allMembersRead;
  }
  final int read = readCount ?? 0;
  if (unreadCount == null && read > 0) {
    return l10n.memberReadCountAtLeast(read);
  }
  return l10n.memberReadCount(read);
}
