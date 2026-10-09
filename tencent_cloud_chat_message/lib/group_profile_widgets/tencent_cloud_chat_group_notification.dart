import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_common/data/group_profile/tencent_cloud_chat_group_profile_data.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat_common.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_safe_dialog_pop.dart';
import 'package:tencent_cloud_chat_common/components/tencent_cloud_chat_components_utils.dart';
import 'package:tencent_cloud_chat_common/utils/group_action_failure_text.dart';
import 'package:tencent_cloud_chat_common/utils/group_announcement_permission.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_code_info.dart';

class TencentCloudChatGroupNotification extends StatefulWidget {
  final V2TimGroupInfo groupInfo;

  const TencentCloudChatGroupNotification(
      {super.key, required this.groupInfo});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatGroupNotificationState();
}

class TencentCloudChatGroupNotificationState
    extends TencentCloudChatState<TencentCloudChatGroupNotification> {
  String notification = "";
  late V2TimGroupInfo _groupInfo = widget.groupInfo;
  // Our own role as last announced by a grant / revoke (null: use
  // _groupInfo.role). Kept apart so the shared group object is never mutated.
  int? _selfRole;
  StreamSubscription<TencentCloudChatGroupProfileData<dynamic>>?
      _groupProfileSubscription;

  @override
  initState() {
    super.initState();
    notification = widget.groupInfo.notification ?? "";
    // toxee: the page used to show its initState snapshot until reopened, so
    // a topic changed by another member (or a role change that grants or
    // revokes the edit) never reached an open page.
    _groupProfileSubscription = TencentCloudChat.instance.eventBusInstance
        .on<TencentCloudChatGroupProfileData<dynamic>>(
            "TencentCloudChatGroupProfileData")
        ?.listen(_onGroupProfileData);
  }

  @override
  void dispose() {
    _groupProfileSubscription?.cancel();
    super.dispose();
  }

  void _onGroupProfileData(TencentCloudChatGroupProfileData<dynamic> data) {
    final groupID = widget.groupInfo.groupID;
    switch (data.currentUpdatedFields) {
      case TencentCloudChatGroupProfileDataKeys.updateGroupInfo:
        if (data.updateGroupInfo.groupID != groupID) return;
        safeSetState(() {
          _groupInfo = data.updateGroupInfo;
          _selfRole = null; // a fresh group object carries the current role
          notification = data.updateGroupInfo.notification ?? "";
        });
      // A grant / revoke (or any member refresh) can change who may edit.
      // The live rule (groupAnnouncementEditableResolver) is re-asked on
      // rebuild; the role is only its fallback, kept current for our own row.
      // For NGC groups our id in the event (64-hex public key) never equals
      // currentUser (76-hex address): there the rebuild is what covers it.
      case TencentCloudChatGroupProfileDataKeys.updateMemberRole:
        if (data.updateGroupID != groupID) return;
        final self =
            TencentCloudChat.instance.dataInstance.basic.currentUser?.userID;
        final mine = data.updateMemberList.any((m) => m.userID == self);
        safeSetState(() {
          if (mine) _selfRole = data.updateMemberRole;
        });
      case TencentCloudChatGroupProfileDataKeys.membersChange:
        if (data.updateGroupID != groupID) return;
        safeSetState(() {});
      default:
        return;
    }
  }

  // toxee: Tim2Tox reports every NGC group as GroupType.Work, and the stock
  // rule let anyone edit a Work group's notification — so plain members were
  // offered an edit that toxcore refuses under the (default) topic lock. The
  // shared rule asks the host for the live topic permission and otherwise
  // gates on the real self role (see group_announcement_permission.dart).
  // Desktop and mobile builders below both use it.
  bool canEditNotification() => canEditGroupAnnouncement(V2TimGroupInfo(
        groupID: _groupInfo.groupID,
        groupType: _groupInfo.groupType,
        role: _selfRole ?? _groupInfo.role,
      ));

  Future<void> _onSetGroupNotification(String value) async {
    final res = await TencentCloudChat.instance.chatSDKInstance.groupSDK
        .setGroupInfo(
            groupID: widget.groupInfo.groupID,
            groupType: widget.groupInfo.groupType,
            notification: value);
    if (res.code == 0) {
      safeSetState(() {
        notification = value;
      });
      return;
    }
    // A refused or failed edit used to be dropped here: the dialog closed and
    // the old announcement stayed, with no word to the user.
    TencentCloudChat.instance.callbacks.onUserNotificationEvent(
      TencentCloudChatComponentsEnum.message,
      TencentCloudChatUserNotificationEvent(
        eventCode: res.code,
        text: groupActionFailureText(res.code, tL10n.setFailed),
      ),
    );
  }

  onEditNotification() {
    String mid = "";

    showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: Text(tL10n.setGroupAnnouncement),
            content: CupertinoTextField(
              maxLines: null,
              onChanged: (value) {
                mid = value;
              },
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () {
                  unawaited(_onSetGroupNotification(mid));
                  popDialogIfCurrent(context);
                },
                child: Text(tL10n.confirm),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  popDialogIfCurrent(context);
                },
                child: Text(tL10n.cancel),
              ),
            ],
          );
        });
  }

  @override
  Widget? desktopBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: getWidth(16), vertical: getHeight(12)),
                    child: Text(
                      notification,
                      style: TextStyle(
                          color: colorTheme.groupProfileTextColor,
                          fontSize: textStyle.fontsize_14),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => popDialogIfCurrent(context),
                          child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: getHeight(16),
                                  horizontal: getWidth(16)),
                              child: Text(
                                tL10n.cancel,
                                style: TextStyle(
                                    color: colorTheme
                                        .groupProfileAddMemberTextColor,
                                    fontSize: textStyle.fontsize_14),
                              )),
                        ),
                        canEditNotification()
                            ? GestureDetector(
                                onTap: onEditNotification,
                                child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: getHeight(16),
                                        horizontal: getWidth(16)),
                                    child: Text(
                                      tL10n.edit,
                                      style: TextStyle(
                                          color: colorTheme
                                              .groupProfileAddMemberTextColor,
                                          fontSize: textStyle.fontsize_14),
                                    )),
                              )
                            : Container()
                      ],
                    ),
                  )
                ]));
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Scaffold(
              appBar: AppBar(
                leadingWidth: getWidth(100),
                leading: GestureDetector(
                    onTap: () => popDialogIfCurrent(context),
                    child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: getHeight(16), horizontal: getWidth(16)),
                        child: Text(
                          tL10n.cancel,
                          style: TextStyle(
                              color: colorTheme.groupProfileAddMemberTextColor,
                              fontSize: textStyle.fontsize_14),
                        ))),
                actions: [
                  canEditNotification()
                      ? GestureDetector(
                          onTap: onEditNotification,
                          child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: getHeight(16),
                                  horizontal: getWidth(16)),
                              child: Text(
                                tL10n.edit,
                                style: TextStyle(
                                    color: colorTheme
                                        .groupProfileAddMemberTextColor,
                                    fontSize: textStyle.fontsize_14),
                              )),
                        )
                      : Container()
                ],
                title: Text(tL10n.announcement,
                    style: TextStyle(
                      fontSize: textStyle.fontsize_16,
                      color: colorTheme.groupProfileTextColor,
                    )),
                centerTitle: true,
              ),
              body: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: getWidth(16), vertical: getHeight(12)),
                child: Text(
                  notification,
                  style: TextStyle(
                      color: colorTheme.groupProfileTextColor,
                      fontSize: textStyle.fontsize_14),
                ),
              ),
            ));
  }
}
