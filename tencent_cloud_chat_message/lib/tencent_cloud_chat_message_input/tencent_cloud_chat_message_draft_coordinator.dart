import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_common/data/message/tencent_cloud_chat_draft_data_provider.dart';
import 'package:tencent_cloud_chat_common/external/chat_message_provider.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

typedef _DraftIdentity = ({
  String conversationID,
  String accountToxId,
});

class TencentCloudChatMessageDraftCoordinator {
  TencentCloudChatMessageDraftCoordinator({
    required void Function(String conversationID, String draft)
        updateConversationPreview,
    ChatDraftProvider? fallbackProvider,
    ChatDraftProvider? Function()? registeredProvider,
  })  : _updateConversationPreview = updateConversationPreview,
        _fallbackProvider =
            fallbackProvider ?? TencentCloudChatDraftDataProvider.shared,
        _registeredProvider = registeredProvider ?? _registeredDraftProvider;

  final void Function(String conversationID, String draft)
      _updateConversationPreview;
  final ChatDraftProvider _fallbackProvider;
  final ChatDraftProvider? Function() _registeredProvider;

  Future<void> _latestDraftSave = Future<void>.value();
  final List<
      ({
        ChatDraftProvider provider,
        _DraftIdentity identity,
        String? draft,
        Completer<void> completer,
      })> _draftSaveQueue = [];
  bool _drainingDraftSaves = false;
  bool _isSending = false;
  _DraftIdentity? _identity;
  int _contextGeneration = 0;
  int _editGeneration = 0;

  bool updateContext({
    String? topicID,
    String? userID,
    String? groupID,
  }) {
    final nextIdentity = _buildIdentity(
      topicID: topicID,
      userID: userID,
      groupID: groupID,
    );
    if (nextIdentity == _identity) {
      return false;
    }
    _identity = nextIdentity;
    _contextGeneration++;
    return true;
  }

  void invalidateLoad() {
    _contextGeneration++;
  }

  void markEdited() {
    _editGeneration++;
  }

  void saveDraft(String draft) {
    final identity = _identity;
    if (identity == null) {
      return;
    }
    final provider = _draftProvider;
    _writeConversationPreview(provider, identity, draft);
    _enqueueDraftSave(
      provider: provider,
      identity: identity,
      draft: draft,
    );
  }

  Future<void> loadDraft({
    required String initialText,
    required String Function() currentText,
    required bool Function() isActive,
    required void Function(String draft) applyText,
  }) async {
    final identity = _identity;
    if (identity == null || initialText.isNotEmpty) {
      return;
    }
    final provider = _draftProvider;
    final contextGeneration = _contextGeneration;
    final editGeneration = _editGeneration;
    try {
      await _latestDraftSave;
      final draft = await provider.loadDraft(
        conversationID: identity.conversationID,
        accountToxId: identity.accountToxId,
      );
      if (!isActive() ||
          contextGeneration != _contextGeneration ||
          editGeneration != _editGeneration ||
          identity != _identity ||
          currentText() != initialText) {
        return;
      }
      _writeConversationPreview(provider, identity, draft ?? '');
      applyText(draft ?? '');
    } catch (error) {
      debugPrint('Failed to load message draft: $error');
    }
  }

  bool sendAndClear({
    required String text,
    required FutureOr<Object?> Function() sendMessage,
    required String Function() currentText,
    required bool Function() isActive,
    required VoidCallback clearComposer,
    void Function(Object error)? onError,
  }) {
    if (_isSending) {
      return false;
    }
    _isSending = true;
    final identity = _identity;
    final provider = _draftProvider;
    final contextGeneration = _contextGeneration;
    final editGeneration = _editGeneration;
    unawaited(_sendAndClear(
      text: text,
      sendMessage: sendMessage,
      currentText: currentText,
      isActive: isActive,
      clearComposer: clearComposer,
      onError: onError,
      identity: identity,
      provider: provider,
      contextGeneration: contextGeneration,
      editGeneration: editGeneration,
    ));
    return true;
  }

  Future<void> _sendAndClear({
    required String text,
    required FutureOr<Object?> Function() sendMessage,
    required String Function() currentText,
    required bool Function() isActive,
    required VoidCallback clearComposer,
    required void Function(Object error)? onError,
    required _DraftIdentity? identity,
    required ChatDraftProvider provider,
    required int contextGeneration,
    required int editGeneration,
  }) async {
    try {
      var result = sendMessage();
      if (result is Future) {
        result = await result;
      }
      if (result == false) {
        throw StateError('Text message send failed');
      }

      final active = isActive();
      final contextIsCurrent =
          contextGeneration == _contextGeneration && identity == _identity;
      final draftIsUnchanged = editGeneration == _editGeneration;
      final textIsUnchanged = active &&
          contextIsCurrent &&
          draftIsUnchanged &&
          currentText() == text;
      if (textIsUnchanged) {
        clearComposer();
      }

      final shouldClearDraft = identity != null &&
          draftIsUnchanged &&
          (!active || !contextIsCurrent || textIsUnchanged);
      if (shouldClearDraft) {
        if (active) {
          _writeConversationPreview(provider, identity, '');
        }
        await _enqueueDraftSave(
          provider: provider,
          identity: identity,
          draft: null,
        );
      }
    } catch (error) {
      onError?.call(error);
    } finally {
      _isSending = false;
    }
  }

  Future<void> _enqueueDraftSave({
    required ChatDraftProvider provider,
    required _DraftIdentity identity,
    required String? draft,
  }) {
    final completer = Completer<void>();
    _draftSaveQueue.add((
      provider: provider,
      identity: identity,
      draft: draft,
      completer: completer,
    ));
    _latestDraftSave = completer.future;
    if (!_drainingDraftSaves) {
      unawaited(_drainDraftSaves());
    }
    return completer.future;
  }

  Future<void> _drainDraftSaves() async {
    _drainingDraftSaves = true;
    while (_draftSaveQueue.isNotEmpty) {
      final operation = _draftSaveQueue.removeAt(0);
      try {
        await operation.provider.saveDraft(
          conversationID: operation.identity.conversationID,
          accountToxId: operation.identity.accountToxId,
          draft: operation.draft,
        );
      } catch (error) {
        debugPrint('Failed to save message draft: $error');
      } finally {
        operation.completer.complete();
      }
    }
    _drainingDraftSaves = false;
  }

  void _writeConversationPreview(
    ChatDraftProvider provider,
    _DraftIdentity identity,
    String draft,
  ) {
    if (provider is ChatDraftProviderOwnsConversationState) {
      return;
    }
    _updateConversationPreview(identity.conversationID, draft);
  }

  ChatDraftProvider get _draftProvider {
    return _registeredProvider() ?? _fallbackProvider;
  }

  static ChatDraftProvider? _registeredDraftProvider() {
    final provider = ChatMessageProviderRegistry.provider;
    return provider is ChatDraftProvider ? provider as ChatDraftProvider : null;
  }

  static _DraftIdentity? _buildIdentity({
    String? topicID,
    String? userID,
    String? groupID,
  }) {
    final accountToxId = TencentCloudChat
        .instance.dataInstance.basic.currentUser?.userID
        ?.trim();
    final conversationID = _conversationID(
      topicID: topicID,
      userID: userID,
      groupID: groupID,
    );
    if (accountToxId == null ||
        accountToxId.isEmpty ||
        conversationID == null) {
      return null;
    }
    return (
      conversationID: conversationID,
      accountToxId: accountToxId,
    );
  }

  static String? _conversationID({
    String? topicID,
    String? userID,
    String? groupID,
  }) {
    final topic = topicID?.trim();
    if (topic != null && topic.isNotEmpty) {
      return 'topic_$topic';
    }
    final user = userID?.trim();
    if (user != null && user.isNotEmpty) {
      return 'c2c_$user';
    }
    final group = groupID?.trim();
    if (group != null && group.isNotEmpty) {
      return 'group_$group';
    }
    return null;
  }
}
