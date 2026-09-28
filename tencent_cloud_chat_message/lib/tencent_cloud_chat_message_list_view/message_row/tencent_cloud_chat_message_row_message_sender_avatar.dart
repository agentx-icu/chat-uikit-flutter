import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_intl/localizations/tencent_cloud_chat_localizations.dart';
import 'package:tencent_cloud_chat_common/components/components_definition/tencent_cloud_chat_component_builder_definitions.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_platform_adapter.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_screen_adapter.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_utils.dart';
import 'package:tencent_cloud_chat_message/common/message_sender_navigation.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/builders/tencent_cloud_chat_common_builders.dart';
import 'package:tencent_cloud_chat_common/widgets/avatar/tencent_cloud_chat_avatar.dart';

class TencentCloudChatMessageRowMessageSenderAvatar extends StatefulWidget {
  final MessageRowMessageSenderAvatarBuilderData data;
  final MessageRowMessageSenderAvatarBuilderMethods methods;
  bool showOthersAvatar = false;
  bool showSelfAvatar = false;

  TencentCloudChatMessageRowMessageSenderAvatar({super.key, required this.data, required this.methods, required this.showOthersAvatar, required this.showSelfAvatar});

  @override
  State<TencentCloudChatMessageRowMessageSenderAvatar> createState() =>
      _TencentCloudChatMessageRowMessageSenderAvatarState();
}

class _TencentCloudChatMessageRowMessageSenderAvatarState
    extends TencentCloudChatState<TencentCloudChatMessageRowMessageSenderAvatar> {
  TapDownDetails? _tapDownDetails;

  void _onTapAvatar() {
    if (TencentCloudChatUtils.checkString(widget.data.message.sender) != null) {
      if ( (!(widget.data.message.isSelf ?? true) && widget.showOthersAvatar) ) {
        // toxee: resolve a group sender's per-group key before opening
        // anything (see openMessageSender). Shared by the desktop and mobile
        // rows: both render this avatar widget.
        openMessageSender(context, widget.data.message,
            groupID: widget.data.groupID);
      }
    }
  }

  void _onLongPressAvatar() {

  }


  @override
  Widget defaultBuilder(BuildContext context) {
    final bool touchScreen = TencentCloudChatPlatformAdapter().isMobile ||
        (TencentCloudChatPlatformAdapter().isWeb &&
            TencentCloudChatScreenAdapter.deviceScreenType == DeviceScreenType.mobile);
    // Screen readers (I5): name the avatar, and give it a tap action — the
    // handler below needs a tap-down position, which an accessibility
    // activation does not deliver, so it is taken from the avatar's centre.
    return Semantics(
      button: true,
      label: TencentCloudChatLocalizations.of(context)?.profile,
      // One focus stop, carrying both of the avatar's actions.
      excludeSemantics: true,
      onTap: () {
        _tapDownFromCentre();
        _handleTap();
      },
      onLongPress: widget.methods.onCustomUIEventLongPressAvatar == null
          ? null
          : () {
              _tapDownFromCentre();
              widget.methods.onCustomUIEventLongPressAvatar?.call(
                message: widget.data.message,
                tapDownDetails: _tapDownDetails!,
                userID: widget.data.userID,
                groupID: widget.data.groupID,
              );
            },
      child: GestureDetector(
      onTapDown: (details) {
        _tapDownDetails = details;
      },
      onSecondaryTapDown: ((details) {
        _tapDownDetails = details;
      }),
      onTap: _handleTap,

      onLongPress: () {
        if (touchScreen && _tapDownDetails != null) {
          widget.methods.onCustomUIEventLongPressAvatar?.call(
            message: widget.data.message,
            tapDownDetails: _tapDownDetails!,
            userID: widget.data.userID,
            groupID: widget.data.groupID,
          );
        }
      },

      child: TencentCloudChatCommonBuilders.getCommonAvatarBuilder(
        scene: (widget.data.message.isSelf ?? true)
            ? TencentCloudChatAvatarScene.messageListForSelf
            : TencentCloudChatAvatarScene.messageListForOthers,
        imageList: [widget.data.message.faceUrl ?? ""],
        width: getSquareSize(36),
        height: getSquareSize(36),
        borderRadius: getSquareSize(18),
      ),
    ));
  }

  /// Accessibility actions carry no pointer position; use the avatar's
  /// centre for the menus the handlers place.
  void _tapDownFromCentre() {
    final box = context.findRenderObject() as RenderBox?;
    _tapDownDetails = TapDownDetails(
      globalPosition: box != null && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : Offset.zero,
    );
  }

  void _handleTap() {
    if (_tapDownDetails != null) {
      if (widget.methods.onCustomUIEventTapAvatar != null) {
        widget.methods.onCustomUIEventTapAvatar?.call(
          message: widget.data.message,
          tapDownDetails: _tapDownDetails!,
          userID: widget.data.userID,
          groupID: widget.data.groupID,
        );
      } else {
        _onTapAvatar();
      }
    }
  }
}
