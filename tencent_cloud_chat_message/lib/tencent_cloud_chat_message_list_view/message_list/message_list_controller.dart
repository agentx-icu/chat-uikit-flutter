import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_list_view/message_list/message_list.dart';

class MessageListController {
  MessageListState? stateObj;

  notifyNewMessageComing(String firstKey, int newMsgCount) {
    stateObj?.notifyNewMessageComing(firstKey, newMsgCount);
  }

  jumpToIndex(int index) {
    stateObj?.listViewController.sliverController.jumpToIndex(index);
  }

  Future<void> animateToIndex(
    int index, {
    required Duration duration,
    required Curve curve,
    double offset = 0,
    bool offsetBasedOnBottom = false,
  }) async {
    stateObj?.listViewController.sliverController.animateToIndex(index,
        duration: duration,
        curve: curve,
        offset: offset,
        offsetBasedOnBottom: offsetBasedOnBottom);
  }

  mount(MessageListState state) {
    stateObj = state;
  }

  scrollToBottom() {
    stateObj?.scrollToLatestMessage();
  }

  /// Whether the list currently sits at (or within [thresholdPixels] of) the
  /// bottom. The message list is a `reverse: true` FlutterListView, so
  /// "bottom" == scroll offset 0. Defaults to true when the list has no
  /// attached clients yet (initial mount), matching the pre-existing
  /// scroll-on-initial-load behavior.
  bool isNearBottom({double thresholdPixels = 100}) {
    final state = stateObj;
    if (state == null) return true;
    final controller = state.listViewController;
    if (!controller.hasClients) return true;
    return controller.position.pixels <= thresholdPixels;
  }

  /// Scroll to the bottom ONLY when the user is already at/near the bottom.
  /// Used for INBOUND messages appended at the head: when the user has
  /// scrolled up to read history, the list keeps their reading position
  /// (FlutterListView's keepPosition) instead of force-jumping to the newest
  /// message — and instead latches the "new messages" chip with [newMessageKey]
  /// / [newMessageCount] so the user sees there is fresh content below.
  scrollToBottomIfNearBottom({String? newMessageKey, int? newMessageCount}) {
    if (isNearBottom()) {
      stateObj?.scrollToLatestMessage();
    } else if (newMessageKey != null) {
      // Scrolled up: keep the reading position and surface the "new messages"
      // chip instead of jumping. Anchor the chip at the newest message (index 0)
      // directly — see latchNewMessagesChip for why key-search is unreliable.
      stateObj?.latchNewMessagesChip(newMessageCount ?? 1);
    }
  }
}
