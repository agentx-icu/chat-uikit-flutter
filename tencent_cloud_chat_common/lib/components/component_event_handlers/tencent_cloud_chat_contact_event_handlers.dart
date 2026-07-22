typedef OnTapContactItem = Future<bool> Function({
  String? userID,
  String? groupID,
});

class TencentCloudChatContactEventHandlers {
  final TencentCloudChatContactUIEventHandlers _uiEventHandlers;
  final TencentCloudChatContactLifeCycleEventHandlers _lifeCycleEventHandlers;

  TencentCloudChatContactEventHandlers({
    TencentCloudChatContactUIEventHandlers? uiEventHandlers,
    TencentCloudChatContactLifeCycleEventHandlers? lifeCycleEventHandlers,
  })  : _uiEventHandlers = uiEventHandlers ?? TencentCloudChatContactUIEventHandlers(),
        _lifeCycleEventHandlers = lifeCycleEventHandlers ?? TencentCloudChatContactLifeCycleEventHandlers();

  TencentCloudChatContactUIEventHandlers get uiEventHandlers => _uiEventHandlers;

  TencentCloudChatContactLifeCycleEventHandlers get lifeCycleEventHandlers => _lifeCycleEventHandlers;
}

class TencentCloudChatContactUIEventHandlers {
  /// This function is triggered when the user taps on a contact item.
  /// By default, tapping a contact item navigates to the corresponding Message component on Mobile devices, while do nothing on Tablet or Desktop devices.
  /// You can customize this behavior based on the provided data.
  /// Return value:
  /// - true: If you handle this event and want to prevent automatic navigation to the Message component.
  /// - false: If you want to keep the default behavior and allow UIKit to navigate to the Message component.
  OnTapContactItem? _onTapContactItem;

  /// Triggered when a PROFILE surface asks to open the chat with its target —
  /// the user-profile "Send a message" tile and the group-profile "Send
  /// Message" tile. This is a distinct intent from [_onTapContactItem] (a
  /// contact/group ROW tap in a list): sharing one slot forced apps that open
  /// a profile on row-tap to guess which surface fired, and the guess broke
  /// for profiles pushed from the chat header (send-a-message loop).
  OnTapContactItem? _onNavigateToChat;

  OnTapContactItem? get onTapContactItem => _onTapContactItem;

  /// Falls back to [_onTapContactItem] when no dedicated handler is set, so
  /// apps registering only the single legacy handler keep the old aliased
  /// behavior.
  OnTapContactItem? get onNavigateToChat =>
      _onNavigateToChat ?? _onTapContactItem;

  TencentCloudChatContactUIEventHandlers({
    OnTapContactItem? onTapContactItem,
    OnTapContactItem? onNavigateToChat,
  })  : _onTapContactItem = onTapContactItem,
        _onNavigateToChat = onNavigateToChat;

  void setEventHandlers({
    OnTapContactItem? onTapContactItem,
    OnTapContactItem? onNavigateToChat,
  }) {
    _onTapContactItem = onTapContactItem ?? _onTapContactItem;
    _onNavigateToChat = onNavigateToChat ?? _onNavigateToChat;
  }
}

class TencentCloudChatContactLifeCycleEventHandlers {
  TencentCloudChatContactLifeCycleEventHandlers();

  void setEventHandlers() {}
}
