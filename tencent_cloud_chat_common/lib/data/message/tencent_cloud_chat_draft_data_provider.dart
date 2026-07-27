import 'dart:async';

import 'package:tencent_cloud_chat_common/external/chat_message_provider.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

abstract class TencentCloudChatDraftStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

class TencentCloudChatCacheDraftStore implements TencentCloudChatDraftStore {
  const TencentCloudChatCacheDraftStore();

  @override
  Future<String?> read(String key) async {
    return TencentCloudChat.instance.cache.getChatDraft(key);
  }

  @override
  Future<void> remove(String key) {
    return TencentCloudChat.instance.cache.removeChatDraft(key);
  }

  @override
  Future<void> write(String key, String value) {
    return TencentCloudChat.instance.cache.cacheChatDraft(key, value);
  }
}

class TencentCloudChatDraftDataProvider implements ChatDraftProvider {
  TencentCloudChatDraftDataProvider({
    TencentCloudChatDraftStore store = const TencentCloudChatCacheDraftStore(),
  }) : _store = store;

  static final TencentCloudChatDraftDataProvider shared =
      TencentCloudChatDraftDataProvider();

  static const String _keyPrefix = 'tencent_cloud_chat_draft';

  final TencentCloudChatDraftStore _store;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<String?> loadDraft({
    required String conversationID,
    required String accountToxId,
  }) {
    return _enqueue(() async {
      final scopedKey = _scopedKey(
        conversationID: conversationID,
        accountToxId: accountToxId,
      );
      final scopedDraft = await _store.read(scopedKey);
      if (scopedDraft != null) {
        if (scopedDraft.isEmpty) {
          await _store.remove(scopedKey);
          return null;
        }
        return scopedDraft;
      }

      final legacyKey = _legacyKey(conversationID);
      final legacyDraft = await _store.read(legacyKey);
      if (legacyDraft == null) {
        return null;
      }
      if (legacyDraft.isNotEmpty) {
        await _store.write(scopedKey, legacyDraft);
      }
      await _store.remove(legacyKey);
      return legacyDraft.isEmpty ? null : legacyDraft;
    });
  }

  @override
  Future<void> saveDraft({
    required String conversationID,
    required String accountToxId,
    String? draft,
  }) {
    return _enqueue(() async {
      final key = _scopedKey(
        conversationID: conversationID,
        accountToxId: accountToxId,
      );
      if (draft == null || draft.isEmpty) {
        await _store.remove(key);
        return;
      }
      await _store.write(key, draft);
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static String _scopedKey({
    required String conversationID,
    required String accountToxId,
  }) {
    return '$_keyPrefix:${_normalizeAccountToxId(accountToxId)}:${_canonicalizeConversationID(conversationID)}';
  }

  static String _legacyKey(String conversationID) {
    return '$_keyPrefix:${_canonicalizeConversationID(conversationID)}';
  }

  static String _normalizeAccountToxId(String value) {
    return Uri.encodeComponent(value.trim().toUpperCase());
  }

  static String _canonicalizeConversationID(String value) {
    return Uri.encodeComponent(value.trim());
  }
}
