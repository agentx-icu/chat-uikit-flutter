import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

class TencentCloudChatUserNotificationEvent {
  int eventCode;
  String text;

  TencentCloudChatUserNotificationEvent({
    required this.eventCode,
    required this.text,
  });
}

class TencentCloudChatCodeInfo {
  static TencentCloudChatUserNotificationEvent get originalMessageNotFound =>
      TencentCloudChatUserNotificationEvent(
        eventCode: -10301,
        text: tL10n.originalMessageNotFound,
      );

  static TencentCloudChatUserNotificationEvent get retrievingGroupMembers =>
      TencentCloudChatUserNotificationEvent(
        eventCode: -10302,
        text: _retrievingGroupMembersText,
      );

  static TencentCloudChatUserNotificationEvent get groupJoined =>
      TencentCloudChatUserNotificationEvent(
        eventCode: -10406,
        text: tL10n.groupJoined,
      );

  static TencentCloudChatUserNotificationEvent get copyFileCompleted =>
      TencentCloudChatUserNotificationEvent(
        eventCode: -10407,
        text: tL10n.copyFileSuccess,
      );

  static TencentCloudChatUserNotificationEvent get saveFileCompleted =>
      TencentCloudChatUserNotificationEvent(
        eventCode: -10408,
        text: tL10n.saveFileSuccess,
      );

  static TencentCloudChatUserNotificationEvent get saveFileFailed =>
      TencentCloudChatUserNotificationEvent(
        eventCode: -10409,
        text: tL10n.saveFileFailed,
      );

  static TencentCloudChatUserNotificationEvent get copyLinkSuccess =>
      TencentCloudChatUserNotificationEvent(
        eventCode: -104010,
        text: tL10n.copyLinkSuccess,
      );

  static String get _retrievingGroupMembersText {
    switch (tL10n.localeName) {
      case 'zh':
      case 'zh_Hans':
        return '正在获取群成员，请稍候。';
      case 'zh_Hant':
        return '正在取得群成員，請稍候。';
      case 'ja':
        return 'グループメンバーを取得しています。しばらくお待ちください。';
      case 'ko':
        return '그룹 구성원을 가져오는 중입니다. 잠시만 기다려 주세요.';
      case 'ar':
        return 'لحظة من فضلك، جارٍ جلب أعضاء المجموعة.';
      default:
        return 'Just a moment, retrieving group members.';
    }
  }
}
