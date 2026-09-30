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

  /// The current draft identity (account + conversation), comparable with
  /// `==`; null without an account or conversation.
  Object? get identity => _identity;

  /// A [sendAndClear] is in flight; another one would be refused.
  bool get isSending => _isSending;
  Completer<void>? _idle;

  /// Completes when no [sendAndClear] is in flight (at once if none is).
  Future<void> whenIdle() {
    if (!_isSending) return Future<void>.value();
    return (_idle ??= Completer<void>()).future;
  }
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
      await _lastSaves[identity];
      await _pendingRestores[identity];
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

  /// Restores into a stored draft still running, per draft identity, across
  /// coordinators: a composer mounted meanwhile for that conversation waits
  /// for them before loading its draft ([loadDraft]).
  static final Map<_DraftIdentity, Future<void>> _pendingRestores = {};

  /// The last queued save per draft identity, across coordinators: a
  /// composer mounted right after another one for the same conversation was
  /// disposed must not load the draft before that one's last save landed
  /// (it would show — and a restore would merge into — a stale draft).
  static final Map<_DraftIdentity, Future<void>> _lastSaves = {};

  /// Put [texts] (hardware-Enter sends that were taken out of the composer
  /// and then not sent) in front of the stored draft of [identity] (a value
  /// of [identity] captured at send time), one per line.
  Future<void> restoreIntoDraft(Object? identity, List<String> texts) {
    if (identity is! _DraftIdentity || texts.isEmpty) {
      return Future<void>.value();
    }
    final previous = _pendingRestores[identity] ?? Future<void>.value();
    final provider = _draftProvider;
    late final Future<void> run;
    run = previous.then((_) async {
      try {
        await _latestDraftSave;
        await _lastSaves[identity];
        final stored = await provider.loadDraft(
          conversationID: identity.conversationID,
          accountToxId: identity.accountToxId,
        );
        final draft = [
          ...texts,
          if (stored != null && stored.isNotEmpty) stored,
        ].join('\n');
        _writeConversationPreview(provider, identity, draft);
        await _enqueueDraftSave(
          provider: provider,
          identity: identity,
          draft: draft,
        );
      } catch (error) {
        debugPrint('Failed to restore unsent text into the draft: $error');
      }
    }).whenComplete(() {
      if (identical(_pendingRestores[identity], run)) {
        _pendingRestores.remove(identity);
      }
    });
    _pendingRestores[identity] = run;
    return run;
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
      final idle = _idle;
      _idle = null;
      idle?.complete();
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
    final saved = completer.future;
    _lastSaves[identity] = saved;
    unawaited(saved.whenComplete(() {
      if (identical(_lastSaves[identity], saved)) _lastSaves.remove(identity);
    }));
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
