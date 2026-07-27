import 'dart:async';
import 'dart:typed_data';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

class ChatMessageSendResult {
  ChatMessageSendResult({
    required this.messageID,
    required this.isPending,
  }) {
    if (messageID.isEmpty) {
      throw ArgumentError.value(messageID, 'messageID', 'must not be empty');
    }
  }

  final String messageID;
  final bool isPending;
}

abstract class ChatMessageProvider {
  Stream<List<V2TimMessage>> streamFor({String? userID, String? groupID});
  Future<void> sendText({
    String? userID,
    String? groupID,
    required String text,
  });
  Future<void> sendImage(
      {String? userID,
      String? groupID,
      required String imagePath,
      String? imageName});
  Future<void> sendFile(
      {String? userID,
      String? groupID,
      required String filePath,
      String? fileName});
  Future<void> deleteMessages(
      {String? userID, String? groupID, required List<String> msgIDs});
}

/// Optional text-send capability for providers that can preserve caller-owned
/// message identity and report whether transport delivery is still pending.
abstract class ChatMessageProviderWithSendResult extends ChatMessageProvider {
  Future<ChatMessageSendResult> sendTextWithResult({
    String? userID,
    String? groupID,
    required String text,
    String? clientMessageID,
  });
}

/// Optional account-scoped storage used by UIKit for regenerable media files.
abstract class ChatScratchFileProvider {
  Future<String> writeScratchBytes({
    required String category,
    required String suggestedFileName,
    required Uint8List bytes,
  });

  Future<void> deleteScratchFile(String path);
}

abstract interface class ChatDraftProvider {
  Future<String?> loadDraft({
    required String conversationID,
    required String accountToxId,
  });

  Future<void> saveDraft({
    required String conversationID,
    required String accountToxId,
    String? draft,
  });
}

abstract interface class ChatDraftProviderOwnsConversationState
    implements ChatDraftProvider {}

class ChatMessageProviderRegistry {
  static ChatMessageProvider? provider;
}
