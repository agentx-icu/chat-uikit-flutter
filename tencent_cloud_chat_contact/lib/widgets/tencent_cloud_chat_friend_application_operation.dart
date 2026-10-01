import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_common/components/tencent_cloud_chat_components_utils.dart';
import 'package:tencent_cloud_chat_common/models/tencent_cloud_chat_models.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat_common.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_code_info.dart';
// The SDK is supplied by the common package, and platform identity scopes the
// operation to a runtime session even when accounts share a UIKit login alias.
// ignore: depend_on_referenced_packages
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_platform_interface.dart';

typedef _ApplicationOperationKey = ({
  TencentCloudChatSdkPlatform sdk,
  String? account,
  String applicant,
});

/// Shares the in-flight guard between list buttons, context menus and details.
/// Closing a view does not abandon a successful operation. Switching accounts
/// invalidates its result and feedback before it can update the new session.
mixin TencentCloudChatFriendApplicationOperation<T extends StatefulWidget>
    on TencentCloudChatState<T> {
  static final _pending = ValueNotifier<Set<_ApplicationOperationKey>>({});

  V2TimFriendApplication get friendApplication;

  _ApplicationOperationKey get _operationKey => (
        sdk: TencentCloudChatSdkPlatform.instance,
        account:
            TencentCloudChat.instance.dataInstance.basic.currentUser?.userID,
        applicant: friendApplication.userID,
      );

  bool get applicationOperationPending =>
      _pending.value.contains(_operationKey);

  bool _isCurrentContext(_ApplicationOperationKey key) =>
      identical(key.sdk, TencentCloudChatSdkPlatform.instance) &&
      key.account ==
          TencentCloudChat.instance.dataInstance.basic.currentUser?.userID;

  @override
  void initState() {
    super.initState();
    _pending.addListener(_onPendingChanged);
  }

  @override
  void dispose() {
    _pending.removeListener(_onPendingChanged);
    super.dispose();
  }

  void _onPendingChanged() {
    if (mounted) {
      safeSetState(() {});
    }
  }

  Future<void> respondToFriendApplication({
    required bool accept,
    required ValueChanged<ContactApplicationResult> onSuccess,
  }) async {
    if (!mounted || applicationOperationPending) return;
    final application = friendApplication;
    final key = _operationKey;
    final resultText = accept ? tL10n.accepted : tL10n.declined;
    final failureText = tL10n.operationFailed;
    _pending.value = {..._pending.value, key};
    try {
      V2TimValueCallback<V2TimFriendOperationResult> response;
      try {
        // The contactSDK convenience wrapper publishes applicationCode after
        // its await. Dispatch through the manager so every data write can first
        // verify that the originating account/session is still current.
        final manager = TencentCloudChat.instance.chatSDKInstance.manager
            .getFriendshipManager();
        final type = FriendApplicationTypeEnum.values[application.type];
        response = accept
            ? await manager.acceptFriendApplication(
                userID: key.applicant,
                responseType:
                    FriendResponseTypeEnum.V2TIM_FRIEND_ACCEPT_AGREE_AND_ADD,
                type: type,
              )
            : await manager.refuseFriendApplication(
                userID: key.applicant,
                type: type,
              );
      } catch (_) {
        if (_isCurrentContext(key)) {
          _reportFailure(-1, failureText);
        }
        return;
      }
      if (!_isCurrentContext(key)) return;
      final result = response.data;
      final code = result?.resultCode ?? (response.code == 0 ? 0 : -1);
      if (response.code == 0 && result != null) {
        TencentCloudChat.instance.dataInstance.contact
            .setApplicationCode(code, key.applicant);
      }
      if (response.code != 0 ||
          (result?.userID ?? key.applicant) != key.applicant ||
          code != 0) {
        _reportFailure(response.code == 0 ? code : response.code, failureText);
        return;
      }
      TencentCloudChat.instance.dataInstance.contact.deleteApplicationList(
        [key.applicant],
        'onFriendApplicationListDeleted',
      );
      if (mounted) {
        onSuccess(ContactApplicationResult(
          result: resultText,
          userID: key.applicant,
        ));
      }
    } finally {
      _pending.value = {..._pending.value}..remove(key);
    }
  }

  void _reportFailure(int code, String text) {
    TencentCloudChat.instance.callbacks.onUserNotificationEvent(
      TencentCloudChatComponentsEnum.contact,
      TencentCloudChatUserNotificationEvent(eventCode: code, text: text),
    );
  }
}
