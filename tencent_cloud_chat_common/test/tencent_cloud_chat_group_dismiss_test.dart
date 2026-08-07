import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_common/chat_sdk/components/tencent_cloud_chat_group_sdk.dart';
import 'package:tencent_cloud_chat_common/data/contact/tencent_cloud_chat_contact_data.dart';
import 'package:tencent_cloud_chat_common/data/conversation/tencent_cloud_chat_conversation_data.dart';
import 'package:tencent_cloud_chat_common/data/group_profile/tencent_cloud_chat_group_profile_data.dart';
import 'package:tencent_cloud_chat_common/eventbus/tencent_cloud_chat_eventbus.dart';
import 'package:tencent_cloud_chat_common/models/tencent_cloud_chat_callbacks.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TencentCloudChatIntl().setLocale(const Locale('en'));
    TencentCloudChat.instance.callbacks.removeAllCallbacks();
    TencentCloudChat.instance.dataInstance.contact.clear();
    TencentCloudChat.instance.dataInstance.groupProfile.clear();
    TencentCloudChat.instance.dataInstance.conversation.clear();
  });

  tearDown(() {
    TencentCloudChat.instance.callbacks.removeAllCallbacks();
    TencentCloudChat.instance.dataInstance.contact.clear();
    TencentCloudChat.instance.dataInstance.groupProfile.clear();
    TencentCloudChat.instance.dataInstance.conversation.clear();
  });

  test('group dismiss removes joined group without replaying quit event',
      () async {
    const groupID = 'dismissed_group';
    final groupEvents = <TencentCloudChatGroupProfileData<
        TencentCloudChatGroupProfileDataKeys>>[];
    final contactEvents =
        <TencentCloudChatContactData<TencentCloudChatContactDataKeys>>[];
    final conversationEvents =
        <TencentCloudChatConversationData<dynamic>>[];
    final notificationTexts = <String>[];

    final groupSub = TencentCloudChat.instance.eventBusInstance
        .on<
            TencentCloudChatGroupProfileData<
                TencentCloudChatGroupProfileDataKeys>>(
          TencentCloudChatEventBus.eventNameGroup,
        )!
        .listen(groupEvents.add);
    final contactSub = TencentCloudChat.instance.eventBusInstance
        .on<TencentCloudChatContactData<TencentCloudChatContactDataKeys>>(
          TencentCloudChatEventBus.eventNameContact,
        )!
        .listen(contactEvents.add);
    final conversationSub = TencentCloudChat.instance.eventBusInstance
        .on<TencentCloudChatConversationData<dynamic>>(
          TencentCloudChatEventBus.eventNameConversation,
        )!
        .listen(conversationEvents.add);
    addTearDown(groupSub.cancel);
    addTearDown(contactSub.cancel);
    addTearDown(conversationSub.cancel);

    final callbacks = TencentCloudChatCallbacks(
      onTencentCloudChatUIKitUserNotificationEvent: (_, event) {
        notificationTexts.add(event.text);
      },
    );
    TencentCloudChat.instance.callbacks.addCallback(callbacks);
    addTearDown(
        () => TencentCloudChat.instance.callbacks.removeCallback(callbacks));

    await Future<void>.delayed(Duration.zero);
    groupEvents.clear();
    contactEvents.clear();

    TencentCloudChat.instance.dataInstance.contact.buildGroupList(
      [
        V2TimGroupInfo(
          groupID: groupID,
          groupType: GroupType.Work,
          groupName: 'Dismissed Group',
        ),
      ],
      'test',
    );
    TencentCloudChat.instance.dataInstance.conversation.buildConversationList(
      [
        V2TimConversation(
          conversationID: 'group_$groupID',
          groupID: groupID,
          type: ConversationType.V2TIM_GROUP,
          showName: 'Dismissed Group',
        ),
      ],
      'test',
    );
    await Future<void>.delayed(Duration.zero);
    groupEvents.clear();
    contactEvents.clear();
    conversationEvents.clear();
    notificationTexts.clear();

    expect(
      TencentCloudChat.instance.dataInstance.contact.groupList
          .where((group) => group.groupID == groupID),
      hasLength(1),
      reason: 'precondition: the dismissed group must be joined before cleanup',
    );
    expect(
      TencentCloudChat.instance.dataInstance.conversation.conversationList
          .where((conversation) => conversation.conversationID == 'group_$groupID'),
      hasLength(1),
      reason: 'precondition: the dismissed group conversation must exist before cleanup',
    );

    final groupListener =
        TencentCloudChatGroupSDKGenerator.getInstance().groupListener;
    groupListener.onGroupDismissed(
        groupID, V2TimGroupMemberInfo(userID: 'owner'));
    groupListener.onGroupDismissed(
        groupID, V2TimGroupMemberInfo(userID: 'owner'));
    await Future<void>.delayed(Duration.zero);

    expect(
      notificationTexts,
      hasLength(1),
      reason:
          'native and Platform dismiss callbacks should surface one notification',
    );
    expect(conversationEvents, hasLength(1),
        reason: 'dismiss should remove the conversation exactly once');
    expect(
      groupEvents.where((event) =>
          event.currentUpdatedFields ==
          TencentCloudChatGroupProfileDataKeys.quitGroup),
      isEmpty,
      reason: 'dismiss must not replay the explicit quit event',
    );
    expect(
      TencentCloudChat.instance.dataInstance.contact.groupList
          .where((group) => group.groupID == groupID),
      isEmpty,
      reason: 'dismiss should remove the joined group once',
    );
    expect(
      TencentCloudChat.instance.dataInstance.conversation.conversationList
          .where((conversation) => conversation.conversationID == 'group_$groupID'),
      isEmpty,
      reason: 'dismiss should remove the deleted group conversation from the list',
    );

    TencentCloudChatGroupSDKGenerator.getInstance().handleDismissedGroup(groupID);
    await Future<void>.delayed(Duration.zero);

    expect(conversationEvents, hasLength(1),
        reason: 'repeat cleanup must not emit a second conversation change');
    expect(
      TencentCloudChat.instance.dataInstance.conversation.conversationList
          .where((conversation) => conversation.conversationID == 'group_$groupID'),
      isEmpty,
      reason: 'repeat cleanup must keep the conversation list empty',
    );
  });

  test('explicit quit still emits the normal quit event', () async {
    const groupID = 'quit_group';
    final groupEvents = <TencentCloudChatGroupProfileData<
        TencentCloudChatGroupProfileDataKeys>>[];
    final groupSub = TencentCloudChat.instance.eventBusInstance
        .on<
            TencentCloudChatGroupProfileData<
                TencentCloudChatGroupProfileDataKeys>>(
          TencentCloudChatEventBus.eventNameGroup,
        )!
        .listen(groupEvents.add);
    addTearDown(groupSub.cancel);

    await Future<void>.delayed(Duration.zero);
    groupEvents.clear();

    TencentCloudChat.instance.dataInstance.contact.buildGroupList(
      [V2TimGroupInfo(groupID: groupID, groupType: GroupType.Work)],
      'test',
    );
    await Future<void>.delayed(Duration.zero);
    groupEvents.clear();

    TencentCloudChatGroupSDKGenerator.getInstance()
        .groupListener
        .onQuitFromGroup(groupID);
    await Future<void>.delayed(Duration.zero);

    expect(
      groupEvents
          .where((event) =>
              event.currentUpdatedFields ==
              TencentCloudChatGroupProfileDataKeys.quitGroup)
          .length,
      1,
    );
  });
}
