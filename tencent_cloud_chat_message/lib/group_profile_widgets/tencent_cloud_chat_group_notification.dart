import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
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

  @override
  initState() {
    super.initState();
    notification = widget.groupInfo.notification ?? "";
  }

  // toxee: Tim2Tox reports every NGC group as GroupType.Work, and the stock
  // rule let anyone edit a Work group's notification — so plain members were
  // offered an edit that toxcore refuses under the (default) topic lock. The
  // shared rule asks the host for the live topic permission and otherwise
  // gates on the real self role (see group_announcement_permission.dart).
  // Desktop and mobile builders below both use it.
  bool canEditNotification() => canEditGroupAnnouncement(widget.groupInfo);

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
