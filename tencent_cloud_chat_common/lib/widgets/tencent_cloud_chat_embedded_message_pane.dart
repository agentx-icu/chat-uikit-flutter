import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';

/// Marks a message widget that is embedded in a host pane (the conversation
/// split layout's detail pane) rather than shown on a route of its own.
///
/// Whether the chat header offers a back button is a NAVIGATION question — is
/// there a chat route to pop? — and must not be answered from the screen
/// classifier (`TencentCloudChatScreenAdapter.deviceScreenType`). The two
/// disagree whenever the host's width-driven master-detail and the classifier
/// differ: an iPad in portrait (834 pt, classified mobile) or a landscape Split
/// View shows the chat embedded next to the list, and a back button there popped
/// the HOST route instead, blanking the whole app. A narrow window the classifier
/// calls desktop (e.g. a Stage Manager window wider than it is tall) pushes the
/// chat as a route and was left without any back button.
class TencentCloudChatEmbeddedMessagePane extends InheritedWidget {
  const TencentCloudChatEmbeddedMessagePane({
    super.key,
    required super.child,
  });

  /// True when [context] sits inside an embedded message pane.
  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<
          TencentCloudChatEmbeddedMessagePane>() !=
      null;

  /// Close the chat hosting [context] after it became moot (the profile it
  /// opened deleted the friend / quit the group): pop its route — but only when
  /// it has one. An embedded chat's route is the HOST's; popping it blanked the
  /// app. There the split layout's selection is cleared instead, so the pane
  /// shows no chat rather than the departed conversation.
  /// Returns whether a route was popped.
  static bool closeChatRoute(BuildContext context) {
    // Called from callbacks, not build: look up without registering a
    // dependency.
    if (context.getInheritedWidgetOfExactType<
            TencentCloudChatEmbeddedMessagePane>() !=
        null) {
      TencentCloudChat.instance.dataInstance.conversation.currentConversation =
          null;
      return false;
    }
    Navigator.pop(context);
    return true;
  }

  @override
  bool updateShouldNotify(TencentCloudChatEmbeddedMessagePane oldWidget) =>
      false;
}
