import 'package:desktop_drop_for_t/desktop_drop_for_t.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/components/components_definition/tencent_cloud_chat_component_builder_definitions.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_message/common/for_desktop/file_tools.dart';
import 'package:tencent_cloud_chat_message/common/media_send_guard.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_input/desktop/tencent_cloud_chat_message_input_member_mention_panel.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_input/desktop/tencent_cloud_chat_message_input_sticker_panel.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_layout/special_case/tencent_cloud_chat_message_drop_target.dart';

class TencentCloudChatMessageLayout extends StatefulWidget {
  final MessageLayoutBuilderWidgets widgets;
  final MessageLayoutBuilderData data;
  final MessageLayoutBuilderMethods methods;

  const TencentCloudChatMessageLayout({
    super.key,
    required this.widgets,
    required this.data,
    required this.methods,
  });

  @override
  State<TencentCloudChatMessageLayout> createState() => _TencentCloudChatMessageLayoutState();
}

class _TencentCloudChatMessageLayoutState extends TencentCloudChatState<TencentCloudChatMessageLayout> {
  bool _dragging = false;

  /// Height the composer's fixed content needs below the header.
  static const double _composerAllowance = 140;

  /// Whether a soft keyboard is up. Reads the RAW view inset: in the
  /// master-detail right pane the host shell's Scaffold has already consumed
  /// it from this subtree's MediaQuery. Desktops have no soft keyboard.
  bool _softKeyboardUp(BuildContext context) =>
      View.of(context).viewInsets.bottom > 0;

  /// Height left for header + body once the keyboard is accounted for. As the
  /// master-detail right pane, [paneHeight] is already keyboard-shrunk and the
  /// MediaQuery inset is 0; as a pushed route (a 720-800 dp landscape phone)
  /// the inset is still in MediaQuery and is subtracted here — never twice.
  double _availableHeight(BuildContext context, double paneHeight) =>
      paneHeight - MediaQuery.viewInsetsOf(context).bottom;

  @override
  Widget defaultBuilder(BuildContext context) {
    return Scaffold(
      appBar: widget.widgets.header,
      // resizeToAvoidBottomInset: false,
      // The input used to be an unbounded non-flex child: reply bar + a
      // multi-line composer + the sticker panel on a landscape phone pushed
      // the list to zero and the Column overflowed. Bound the input so its
      // sticker panel (the only part that can shrink) yields. The list keeps
      // up to a 96-px strip, but only out of height the composer does not
      // need: the reservation fades to 0 below a 296-px body, so a
      // keyboard-shrunk body (e.g. 114 px on a landscape phone) goes entirely
      // to the fixed composer instead of leaving it 18 px.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double body = constraints.maxHeight;
          final double listReserve = (body - 200).clamp(0.0, 96.0).toDouble();
          return Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  child: widget.widgets.messageListView,
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: body - listReserve),
                child: widget.widgets.messageInput,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget desktopBuilder(BuildContext context) {
    // Measure the pane before the inner Scaffold: when a soft keyboard leaves
    // it too short, drop the header (the master-detail conversation list stays
    // visible beside it, so nothing is lost) and bound the composer to the
    // body, so the chat never overflows.
    return LayoutBuilder(builder: (context, pane) {
     final keyboardUp = _softKeyboardUp(context);
     // Drop the header only when it would not leave the composer room. The
     // system back gesture / button still leaves a pushed chat, and the
     // header returns as soon as the keyboard closes.
     final compact = keyboardUp &&
         _availableHeight(context, pane.maxHeight) <
             widget.widgets.header.preferredSize.height + _composerAllowance;
     return Scaffold(
      // resizeToAvoidBottomInset: false,
      appBar: compact ? null : widget.widgets.header,
      body: DropTarget(
          onDragDone: (detail) {
            setState(() {
              _dragging = false;
            });
            if (!tencentCloudChatAllowMediaSend(context,
                kind: 'file',
                userID: widget.data.userID,
                groupID: widget.data.groupID,
                topicID: widget.data.topicID)) {
              return;
            }
            final filesPath = detail.files.map((e) => e.path).toList();
            TencentCloudChatDesktopFileTools.sendFileWithConfirmation(
              filesPath: filesPath,
              currentConversationShowName: widget.data.currentConversationShowName,
              sendFileMessage: widget.methods.sendFileMessage,
              context: context,
            );
          },
          onDragEntered: (detail) {
            setState(() {
              _dragging = true;
            });
          },
          onDragExited: (detail) {
            setState(() {
              _dragging = false;
            });
          },
          // LayoutBuilder: the sticker panel is a Positioned child of this
          // Stack and needs the pane width to clamp itself inside it.
          child: LayoutBuilder(builder: (context, paneConstraints) => Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        widget.methods.closeSticker();
                        // widget.methods;
                      },
                      child: widget.widgets.messageListView,
                  )),
                  // Bounded (as in [defaultBuilder]) only while a soft keyboard
                  // is up, i.e. on touch platforms, whose composer sizes to its
                  // content and scrolls when short. The desktop composer grows
                  // to any finite max height, so without a soft keyboard the
                  // bound is infinite (the old unbounded slot). The ConstrainedBox
                  // itself is ALWAYS there: swapping the composer's parent when
                  // the keyboard opens would rebuild it and drop its focus,
                  // closing the keyboard it just opened.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: keyboardUp
                          ? paneConstraints.maxHeight -
                              (paneConstraints.maxHeight - 200).clamp(0.0, 96.0).toDouble()
                          : double.infinity,
                    ),
                    child: widget.widgets.messageInput,
                  ),
                ],
              ),
              TencentCloudChatDesktopMemberMentionPanel(
                atMemberPanelScroll: widget.methods.desktopInputMemberSelectionPanelScroll,
                onSelectMember: widget.methods.onSelectMember,
                desktopMentionBoxPositionX: widget.data.desktopMentionBoxPositionX,
                desktopMentionBoxPositionY: widget.data.desktopMentionBoxPositionY,
                activeMentionIndex: widget.data.activeMentionIndex,
                currentFilteredMembersListForMention: widget.data.currentFilteredMembersListForMention,
              ),
              if (widget.data.hasStickerPlugin && widget.data.stickerPluginInstance != null && widget.data.desktopStickerBoxPositionX != 0.0 && widget.data.desktopStickerBoxPositionY != 0.0)
                TencentCloudChatDesktopStickerPanel(
                  desktopStickerBoxPositionX: widget.data.desktopStickerBoxPositionX,
                  desktopStickerBoxPositionY: widget.data.desktopStickerBoxPositionY,
                  stickerPluginInstance: widget.data.stickerPluginInstance!,
                  paneWidth: paneConstraints.maxWidth,
                ),
              if (_dragging)
                TencentCloudChatMessageDropTarget(
                  currentConversationShowName: widget.data.currentConversationShowName,
                ),
            ],
          ))),
    );
    });
  }
}
