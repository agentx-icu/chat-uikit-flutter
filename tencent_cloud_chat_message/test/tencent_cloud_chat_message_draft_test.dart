import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:tencent_cloud_chat_common/components/component_config/tencent_cloud_chat_message_common_defines.dart';
import 'package:tencent_cloud_chat_common/components/components_definition/tencent_cloud_chat_component_builder_definitions.dart';
import 'package:tencent_cloud_chat_common/external/chat_message_provider.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_input/tencent_cloud_chat_message_draft_coordinator.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_input/desktop/tencent_cloud_chat_message_input_desktop.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_input/mobile/tencent_cloud_chat_message_input_mobile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in _ComposerPlatform.values) {
    group('${platform.name} draft persistence', () {
      late _FakeMessageProvider provider;
      late _SendHarness sendHarness;

      setUp(() {
        TencentCloudChatIntl(locale: const Locale('en')).setLocale(
          const Locale('en'),
        );
        TencentCloudChatIntl.hasInitialized = true;
        provider = _FakeMessageProvider();
        sendHarness = _SendHarness();
        ChatMessageProviderRegistry.provider = provider;
        _setCurrentAccount('ACCOUNT-A-FULL-TOX-ID');
      });

      tearDown(() {
        ChatMessageProviderRegistry.provider = null;
      });

      testWidgets('restores on init and saves edits', (tester) async {
        provider.drafts['ACCOUNT-A-FULL-TOX-ID|c2c_friend'] = 'restored draft';

        await _pumpComposer(
          tester,
          platform: platform,
          userID: 'friend',
          sendHarness: sendHarness,
        );

        expect(_composerText(tester), 'restored draft');
        _setComposerText(platform, 'edited draft');
        await tester.pump();
        await _pumpUntilSaveCount(tester, provider, 1);

        expect(provider.saves.last, (
          accountToxId: 'ACCOUNT-A-FULL-TOX-ID',
          conversationID: 'c2c_friend',
          draft: 'edited draft',
        ));
      });

      testWidgets('late load cannot overwrite a conversation or account switch',
          (tester) async {
        final oldLoad = Completer<String?>();
        provider.pendingLoads['ACCOUNT-A-FULL-TOX-ID|c2c_friend'] = oldLoad;
        provider.drafts['ACCOUNT-B-FULL-TOX-ID|c2c_other'] = 'new draft';

        await _pumpComposer(
          tester,
          platform: platform,
          userID: 'friend',
          sendHarness: sendHarness,
        );
        _setCurrentAccount('ACCOUNT-B-FULL-TOX-ID');
        await _pumpComposer(
          tester,
          platform: platform,
          userID: 'other',
          sendHarness: sendHarness,
        );

        expect(_composerText(tester), 'new draft');
        oldLoad.complete('stale draft');
        await tester.pump();
        expect(_composerText(tester), 'new draft');
      });

      testWidgets('late load cannot overwrite user typing', (tester) async {
        final load = Completer<String?>();
        provider.pendingLoads['ACCOUNT-A-FULL-TOX-ID|c2c_friend'] = load;

        await _pumpComposer(
          tester,
          platform: platform,
          userID: 'friend',
          sendHarness: sendHarness,
        );
        _setComposerText(platform, 'typed first');
        load.complete('late draft');
        await tester.pump();
        await _pumpUntilSaveCount(tester, provider, 1);

        expect(_composerText(tester), 'typed first');
      });

      testWidgets('successful send clears composer and persisted draft',
          (tester) async {
        await _pumpComposer(
          tester,
          platform: platform,
          userID: 'friend',
          sendHarness: sendHarness,
        );
        _sendComposerText(platform, 'send me');
        await _pumpUntilSendCalled(tester, sendHarness);

        expect(_composerText(tester), 'send me');
        sendHarness.completeSuccess();
        await tester.idle();
        await tester.pump();
        await _pumpUntilSaveCount(tester, provider, 2);

        expect(_composerText(tester), isEmpty);
        expect(provider.saves.last.draft, isNull);
      });

      testWidgets('failed send retains composer and persisted draft',
          (tester) async {
        await _pumpComposer(
          tester,
          platform: platform,
          userID: 'friend',
          sendHarness: sendHarness,
        );
        _sendComposerText(platform, 'keep me');
        await _pumpUntilSendCalled(tester, sendHarness);
        sendHarness.completeFailure();
        await tester.idle();
        await tester.pump();
        await _pumpUntilSaveCount(tester, provider, 1);

        expect(_composerText(tester), 'keep me');
        expect(provider.saves.last.draft, 'keep me');
      });
    });
  }

  test('owner provider skips preview writes while fallback retains them',
      () async {
    _setCurrentAccount('ACCOUNT-A-FULL-TOX-ID');
    final ownerProvider = _OwningFakeMessageProvider()
      ..drafts['ACCOUNT-A-FULL-TOX-ID|group_Team'] = 'owned draft';
    final ownerPreviews = <({String conversationID, String draft})>[];
    final ownerCoordinator = TencentCloudChatMessageDraftCoordinator(
      updateConversationPreview: (conversationID, draft) {
        ownerPreviews.add((conversationID: conversationID, draft: draft));
      },
      registeredProvider: () => ownerProvider,
    )..updateContext(groupID: 'Team');
    var appliedText = '';

    await ownerCoordinator.loadDraft(
      initialText: '',
      currentText: () => appliedText,
      isActive: () => true,
      applyText: (draft) => appliedText = draft,
    );
    ownerCoordinator.markEdited();
    ownerCoordinator.saveDraft('owned edit');

    expect(appliedText, 'owned draft');
    expect(ownerPreviews, isEmpty);
    expect(ownerProvider.saves.last.draft, 'owned edit');

    final fallbackProvider = _FakeMessageProvider();
    final fallbackPreviews = <({String conversationID, String draft})>[];
    final fallbackCoordinator = TencentCloudChatMessageDraftCoordinator(
      updateConversationPreview: (conversationID, draft) {
        fallbackPreviews.add((conversationID: conversationID, draft: draft));
      },
      fallbackProvider: fallbackProvider,
      registeredProvider: () => null,
    )..updateContext(groupID: 'Team');

    fallbackCoordinator.markEdited();
    fallbackCoordinator.saveDraft('fallback edit');

    expect(fallbackPreviews, [
      (conversationID: 'group_Team', draft: 'fallback edit'),
    ]);
    expect(fallbackProvider.saves.last.draft, 'fallback edit');
  });
}

enum _ComposerPlatform { mobile, desktop }

Future<void> _pumpComposer(
  WidgetTester tester, {
  required _ComposerPlatform platform,
  required String userID,
  required _SendHarness sendHarness,
}) async {
  final inputData = MessageInputBuilderData(
    userID: userID,
    attachmentOptions: const [],
    inSelectMode: false,
    enableReplyWithMention: false,
    status: TencentCloudChatMessageInputStatus.canSendMessage,
    selectedMessages: const [],
    desktopMentionBoxPositionX: 0,
    desktopMentionBoxPositionY: 0,
    isGroupAdmin: false,
    activeMentionIndex: -1,
    currentFilteredMembersListForMention: const [],
    groupMemberList: const [],
    currentConversationShowName: userID,
    hasStickerPlugin: false,
    stickerPluginInstance: null,
  );
  final inputMethods = MessageInputBuilderMethods(
    sendTextMessage: sendHarness.send,
    sendImageMessage: ({imagePath, imageName, inputElement}) {},
    sendVideoMessage: ({videoPath, inputElement}) {},
    sendFileMessage: ({filePath, fileName, inputElement}) {},
    sendVoiceMessage: ({required voicePath, required duration}) {},
    onChooseGroupMembers: () async => [],
    controller: Object(),
    clearRepliedMessage: () {},
    setDesktopMentionBoxPositionX: (_) {},
    setDesktopMentionBoxPositionY: (_) {},
    setActiveMentionIndex: (_) {},
    setCurrentFilteredMembersListForMention: (_) {},
    desktopInputMemberSelectionPanelScroll: AutoScrollController(),
    messageAttachmentOptionsBuilder: Object(),
    closeSticker: () {},
  );
  final composer = switch (platform) {
    _ComposerPlatform.mobile => TencentCloudChatMessageInputMobile(
        key: const ValueKey('draft-composer'),
        inputData: inputData,
        inputMethods: inputMethods,
        debugDraftPersistenceOnly: true,
      ),
    _ComposerPlatform.desktop => TencentCloudChatMessageInputDesktop(
        key: const ValueKey('draft-composer'),
        inputData: inputData,
        inputMethods: inputMethods,
        debugDraftPersistenceOnly: true,
      ),
  };

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          TencentCloudChatIntl().init(context);
          return Scaffold(body: composer);
        },
      ),
    ),
  );
  await tester.pump();
}

String _composerText(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const ValueKey('draft_persistence_text')))
      .data!;
}

void _setComposerText(_ComposerPlatform platform, String text) {
  switch (platform) {
    case _ComposerPlatform.mobile:
      debugRealUiMobileComposerSetText!(text);
    case _ComposerPlatform.desktop:
      debugRealUiDesktopComposerSetText!(text);
  }
}

void _sendComposerText(_ComposerPlatform platform, String text) {
  switch (platform) {
    case _ComposerPlatform.mobile:
      debugRealUiMobileComposerSendText!(text);
    case _ComposerPlatform.desktop:
      debugRealUiDesktopComposerSendText!(text);
  }
}

void _setCurrentAccount(String accountToxId) {
  TencentCloudChat.instance.dataInstance.basic.updateCurrentUserInfo(
    userFullInfo: V2TimUserFullInfo(userID: accountToxId),
  );
}

Future<void> _pumpUntilSaveCount(
  WidgetTester tester,
  _FakeMessageProvider provider,
  int count,
) async {
  for (var attempt = 0;
      attempt < 10 && provider.saves.length < count;
      attempt++) {
    await tester.pump();
  }
  expect(provider.saves.length, greaterThanOrEqualTo(count));
}

Future<void> _pumpUntilSendCalled(
  WidgetTester tester,
  _SendHarness sendHarness,
) async {
  await tester.pump();
  for (var attempt = 0; attempt < 10 && sendHarness.callCount == 0; attempt++) {
    await tester.pump();
  }
  expect(sendHarness.callCount, 1);
}

class _SendHarness {
  Completer<void>? _completer;
  int callCount = 0;

  Future<void> send({required String text, List<String>? mentionedUsers}) {
    callCount++;
    _completer = Completer<void>();
    return _completer!.future;
  }

  void completeSuccess() {
    _completer!.complete();
  }

  void completeFailure() {
    _completer!.completeError(StateError('send failed'));
  }
}

class _FakeMessageProvider implements ChatMessageProvider, ChatDraftProvider {
  final Map<String, String> drafts = {};
  final Map<String, Completer<String?>> pendingLoads = {};
  final List<({String conversationID, String accountToxId, String? draft})>
      saves = [];

  String _key(String accountToxId, String conversationID) {
    return '$accountToxId|$conversationID';
  }

  @override
  Future<String?> loadDraft({
    required String conversationID,
    required String accountToxId,
  }) {
    final key = _key(accountToxId, conversationID);
    return pendingLoads[key]?.future ?? Future<String?>.value(drafts[key]);
  }

  @override
  Future<void> saveDraft({
    required String conversationID,
    required String accountToxId,
    String? draft,
  }) {
    saves.add((
      conversationID: conversationID,
      accountToxId: accountToxId,
      draft: draft,
    ));
    final key = _key(accountToxId, conversationID);
    if (draft == null || draft.isEmpty) {
      drafts.remove(key);
    } else {
      drafts[key] = draft;
    }
    return Future<void>.value();
  }

  @override
  Future<void> deleteMessages({
    String? userID,
    String? groupID,
    required List<String> msgIDs,
  }) async {}

  @override
  Future<void> sendFile({
    String? userID,
    String? groupID,
    required String filePath,
    String? fileName,
  }) async {}

  @override
  Future<void> sendImage({
    String? userID,
    String? groupID,
    required String imagePath,
    String? imageName,
  }) async {}

  @override
  Future<void> sendText({
    String? userID,
    String? groupID,
    required String text,
  }) async {}

  @override
  Stream<List<V2TimMessage>> streamFor({String? userID, String? groupID}) {
    return const Stream<List<V2TimMessage>>.empty();
  }
}

class _OwningFakeMessageProvider extends _FakeMessageProvider
    implements ChatDraftProviderOwnsConversationState {}
