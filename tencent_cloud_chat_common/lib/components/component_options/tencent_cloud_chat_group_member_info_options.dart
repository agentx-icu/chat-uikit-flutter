import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

class TencentCloudChatGroupMemberInfoOptions {
  final V2TimGroupMemberFullInfo memberFullInfo;

  /// toxee: the type of the group the member belongs to, when known. A legacy
  /// conference names members by their long-term key, an NGC group by a
  /// per-group key; the member-info page explains the key accordingly.
  final String? groupType;

  TencentCloudChatGroupMemberInfoOptions(
      {required this.memberFullInfo, this.groupType});

  Map<String, dynamic> toMap() {
    return {'memberFullInfo': memberFullInfo.toString(), 'groupType': groupType};
  }

  static TencentCloudChatGroupMemberInfoOptions fromMap(Map<String, dynamic> map) {
    return TencentCloudChatGroupMemberInfoOptions(
        memberFullInfo: map['memberFullInfo'] as V2TimGroupMemberFullInfo,
        groupType: map['groupType'] as String?);
  }
}