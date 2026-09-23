import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/components/component_options/tencent_cloud_chat_group_profile_options.dart';
import 'package:tencent_cloud_chat_common/components/component_options/tencent_cloud_chat_user_profile_options.dart';
import 'package:tencent_cloud_chat_common/data/conversation/tencent_cloud_chat_conversation_data.dart';
import 'package:tencent_cloud_chat_common/router/tencent_cloud_chat_navigator.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_utils.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/builders/tencent_cloud_chat_common_builders.dart';
import 'package:tencent_cloud_chat_common/widgets/avatar/tencent_cloud_chat_avatar.dart';

class TencentCloudChatMessageHeaderProfileImage extends StatefulWidget {
  final V2TimConversation? conversation;
  final List<V2TimGroupMemberFullInfo> Function() getGroupMembersInfo;
  final VoidCallback? startVoiceCall;
  final VoidCallback? startVideoCall;

  const TencentCloudChatMessageHeaderProfileImage({
    super.key,
    required this.getGroupMembersInfo,
    this.conversation,
    this.startVoiceCall,
    this.startVideoCall,
  });

  @override
  State<TencentCloudChatMessageHeaderProfileImage> createState() =>
      _TencentCloudChatMessageHeaderProfileImageState();
}

class _TencentCloudChatMessageHeaderProfileImageState
    extends TencentCloudChatState<TencentCloudChatMessageHeaderProfileImage> {
  /// toxee: the conversation as last seen in UIKit's conversation data. The
  /// header is built with the conversation captured when the chat opened (a
  /// compact shell pushes the route once and never rebuilds it with a fresh
  /// one), so a changed avatar — e.g. a new group avatar picked on the group
  /// profile — reached the conversation row but never this header. Mirrors
  /// toxee's `ToxeeMessageHeaderInfo`, which fixed the same gap for the title.
  V2TimConversation? _liveConversation;
  StreamSubscription<TencentCloudChatConversationData<dynamic>>?
      _conversationSub;

  V2TimConversation? get _conversation =>
      _liveConversation ?? widget.conversation;

  @override
  void initState() {
    super.initState();
    _conversationSub = TencentCloudChat.instance.eventBusInstance
        .on<TencentCloudChatConversationData<dynamic>>(
            'TencentCloudChatConversationData')
        ?.listen(_onConversationData);
  }

  @override
  void didUpdateWidget(
      covariant TencentCloudChatMessageHeaderProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A parent rebuild handing in a different conversation (or a fresher
    // avatar for the same one) wins over what the event stream delivered.
    if (oldWidget.conversation?.conversationID !=
            widget.conversation?.conversationID ||
        oldWidget.conversation?.faceUrl != widget.conversation?.faceUrl) {
      _liveConversation = null;
    }
  }

  @override
  void dispose() {
    _conversationSub?.cancel();
    super.dispose();
  }

  void _onConversationData(TencentCloudChatConversationData<dynamic> data) {
    final id = widget.conversation?.conversationID;
    if (id == null || id.isEmpty || !mounted) return;
    for (final conv in data.conversationList) {
      if (conv.conversationID != id) continue;
      if (conv.faceUrl != _conversation?.faceUrl) {
        setState(() => _liveConversation = conv);
      }
      return;
    }
  }

  List<String> getConversationFaceURL(V2TimConversation? conversation) {
    if (conversation == null) {
      return [""];
    }

    return [
      TencentCloudChatUtils.checkString(conversation.faceUrl) == null
          ? ""
          : conversation.faceUrl!
    ];
  }

  @override
  Widget? desktopBuilder(BuildContext context) {
    // Key DIRECTLY on the GestureDetector (NOT a KeyedSubtree wrapper): the
    // onTap only PUSHES a profile route, where a flutter_skill double-fire
    // (synthetic pointer + the _tryInvokeCallback fallback that direct-invokes
    // GestureDetector.onTap) is harmless — two stacked profile routes, the top
    // one asserted then popped. The direct key is important because it lets
    // _tryInvokeCallback GUARANTEE the navigation fires even if the synthetic
    // pointer misses this small (34px) avatar; a KeyedSubtree wrapper would
    // suppress that fallback and the open became unreliable.
    return GestureDetector(
      key: const ValueKey('message_header_profile_avatar'),
      onTap: TencentCloudChatUtils.checkString(widget.conversation?.userID) !=
              null
          ? () => navigateToUserProfile(
                context: context,
                options: TencentCloudChatUserProfileOptions(
                  userID: widget.conversation!.userID!,
                  startVideoCall: widget.startVideoCall,
                  startVoiceCall: widget.startVoiceCall,
                ),
              )
          : TencentCloudChatUtils.checkString(widget.conversation?.groupID) !=
                  null
              ? () {
                Object? result = navigateToGroupProfile(
                  context: context,
                  options: TencentCloudChatGroupProfileOptions(
                    groupID: widget.conversation!.groupID!,
                  ),
                );
              }
              : null,
      child: TencentCloudChatCommonBuilders.getCommonAvatarBuilder(
        scene: TencentCloudChatAvatarScene.messageHeader,
        imageList: getConversationFaceURL(_conversation),
        width: getSquareSize(34),
        height: getSquareSize(34),
        borderRadius: getSquareSize(17),
      ),
    );
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    // Direct key on the GestureDetector — see desktopBuilder (lets
    // _tryInvokeCallback guarantee the profile open even if the synthetic
    // pointer misses the small avatar; double-fire is harmless for a push).
    return GestureDetector(
      key: const ValueKey('message_header_profile_avatar'),
      onTap: () async {
        if (mounted) {
          if (TencentCloudChatUtils.checkString(widget.conversation?.userID) != null) {
            Object? result = await navigateToUserProfile(
              context: context,
              options: TencentCloudChatUserProfileOptions(
                userID: widget.conversation!.userID!,
                startVideoCall: widget.startVideoCall,
                startVoiceCall: widget.startVoiceCall,
              ),
            );

            if (result != null && (result is bool && result == true) && mounted) {
              Navigator.pop(context);
            }
          } else if (TencentCloudChatUtils.checkString(widget.conversation?.groupID) != null) {
            Object? result = await navigateToGroupProfile(
              context: context,
              options: TencentCloudChatGroupProfileOptions(
                groupID: widget.conversation!.groupID!,
              ),
            );

            if (result != null && (result is bool && result == true) && mounted) {
              Navigator.pop(context);
            }
          }
        }
      },
      child: TencentCloudChatCommonBuilders.getCommonAvatarBuilder(
        scene: TencentCloudChatAvatarScene.messageHeader,
        imageList: getConversationFaceURL(_conversation),
        width: getSquareSize(34),
        height: getSquareSize(34),
        borderRadius: getSquareSize(17),
      ),
    );
  }
}
