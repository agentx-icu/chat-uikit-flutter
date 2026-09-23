import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_common/components/component_options/tencent_cloud_chat_user_profile_options.dart';
import 'package:tencent_cloud_chat_common/router/tencent_cloud_chat_navigator.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_utils.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_common/builders/tencent_cloud_chat_common_builders.dart';
import 'package:tencent_cloud_chat_common/widgets/avatar/tencent_cloud_chat_avatar.dart';
import 'package:tencent_cloud_chat_contact/widgets/group_member_identity.dart';
import 'package:tencent_cloud_chat_common/utils/tox_group_kind.dart';

class TencentCloudChatGroupMemberInfo extends StatefulWidget {
  final V2TimGroupMemberFullInfo memberFullInfo;

  /// toxee: the member's group type when known (see
  /// TencentCloudChatGroupMemberInfoOptions.groupType).
  final String? groupType;

  const TencentCloudChatGroupMemberInfo({super.key, required this.memberFullInfo, this.groupType});

  @override
  State<StatefulWidget> createState() => TencentCloudChatGroupMemberInfoState();
}

class TencentCloudChatGroupMemberInfoState extends TencentCloudChatState<TencentCloudChatGroupMemberInfo> {
  _getShowName() {
    String name = TencentCloudChatUtils.checkString(widget.memberFullInfo.nameCard) ??
        TencentCloudChatUtils.checkString(widget.memberFullInfo.nickName) ??
        widget.memberFullInfo.userID;
    return name;
  }

  @override
  Widget? desktopBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Scaffold(
                body: TencentCloudChatGroupMemberInfoBody(
              memberFullInfo: widget.memberFullInfo,
              groupType: widget.groupType,
            )));
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Scaffold(
            appBar: AppBar(
              title: Text(
                _getShowName(),
                style: const TextStyle(fontSize: 17),
              ),
              centerTitle: true,
            ),
            body: TencentCloudChatGroupMemberInfoBody(
              memberFullInfo: widget.memberFullInfo,
              groupType: widget.groupType,
            )));
  }
}

class TencentCloudChatGroupMemberInfoBody extends StatefulWidget {
  final V2TimGroupMemberFullInfo memberFullInfo;
  final String? groupType;

  const TencentCloudChatGroupMemberInfoBody({super.key, required this.memberFullInfo, this.groupType});

  @override
  State<StatefulWidget> createState() => TencentCloudChatGroupMemberInfoBodyState();
}

class TencentCloudChatGroupMemberInfoBodyState extends TencentCloudChatState<TencentCloudChatGroupMemberInfoBody> {
  _getShowName() {
    String name = TencentCloudChatUtils.checkString(widget.memberFullInfo.nameCard) ??
        widget.memberFullInfo.nickName ??
        widget.memberFullInfo.userID;
    return name;
  }

  _getGroupRole() {
    String role = tL10n.groupMember;
    switch (widget.memberFullInfo.role) {
      case GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_ADMIN:
        role = tL10n.admin;
        break;
      case GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_OWNER:
        role = tL10n.groupOwner;
        break;
      default:
        role = tL10n.groupMember;
        break;
    }
    return role;
  }

  String _getJoinTime() {
    final joinTime = widget.memberFullInfo.joinTime ?? 0;
    if (joinTime <= 0) return tL10n.none;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(joinTime * 1000);
    return TencentCloudChatIntl.formatDateTime(dateTime, context);
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    // toxee: the row's userID is a Tox identity only when it resolves (self,
    // or a friend in a legacy conference). An NGC member row carries a
    // PER-GROUP key: label it as such, copy it as such, and offer no profile /
    // add-friend route for it (see group_member_identity.dart).
    final resolvedID = resolveGroupMemberUserID(widget.memberFullInfo.userID);
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Center(
              child: ListView(
                children: [
                  SizedBox(
                    height: getHeight(40),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TencentCloudChatCommonBuilders.getCommonAvatarBuilder(
                        scene: TencentCloudChatAvatarScene.groupProfile,
                        imageList: [TencentCloudChatUtils.checkString(widget.memberFullInfo.faceUrl)],
                        width: getSquareSize(94),
                        height: getSquareSize(94),
                        borderRadius: getSquareSize(48),
                      )
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.all(getSquareSize(16)),
                    child: Column(
                      children: [
                        Text(
                          _getShowName(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: textStyle.fontsize_24, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                resolvedID != null
                                    ? "ID: $resolvedID"
                                    : "${tL10n.groupMemberKey}: ${widget.memberFullInfo.userID}",
                                style:
                                    TextStyle(fontSize: textStyle.fontsize_12),
                              ),
                            ),
                            // toxee: a copy affordance for the member's Tox id.
                            // Member info previously showed the id as plain text
                            // with no copy path except the member-LIST desktop
                            // right-click — leaving mobile users no way to copy.
                            IconButton(
                              key: const ValueKey(
                                'group_member_info_copy_id_button',
                              ),
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: tL10n.copy,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: resolvedID ??
                                        widget.memberFullInfo.userID,
                                  ),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                  SnackBar(
                                    content: Text(resolvedID != null
                                        ? tL10n.toxIdCopied
                                        : tL10n.groupMemberKeyCopied),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (resolvedID == null)
                          Padding(
                            padding: EdgeInsets.only(top: getHeight(4)),
                            child: Text(
                              // toxee: a legacy conference names a peer by
                              // their LONG-TERM key (the one in their Tox ID),
                              // so "only identifies the member in this group"
                              // is true only of an NGC per-group key.
                              isToxConferenceGroupType(widget.groupType)
                                  ? tL10n.conferenceMemberKeyHint
                                  : tL10n.groupMemberKeyHint,
                              key: const ValueKey('group_member_info_key_hint'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: textStyle.fontsize_12,
                                  color: colorTheme.secondaryTextColor),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: getWidth(16), vertical: getHeight(12)),
                        width: MediaQuery.of(context).size.width,
                        color: colorTheme.groupProfileTabBackground,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(tL10n.myRoleInGroup,
                                  style: TextStyle(
                                      color: colorTheme.groupProfileTabTextColor, fontSize: textStyle.fontsize_16)),
                            ),
                            Text(_getGroupRole(),
                                style:
                                    TextStyle(color: colorTheme.groupProfileTextColor, fontSize: textStyle.fontsize_16))
                          ],
                        ),
                      )
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: getWidth(16), vertical: getHeight(12)),
                        width: MediaQuery.of(context).size.width,
                        color: colorTheme.groupProfileTabBackground,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(tL10n.joinTime,
                                  style: TextStyle(
                                      color: colorTheme.groupProfileTabTextColor, fontSize: textStyle.fontsize_16)),
                            ),
                            Text(_getJoinTime(),
                                style:
                                    TextStyle(color: colorTheme.groupProfileTextColor, fontSize: textStyle.fontsize_16))
                          ],
                        ),
                      )
                    ],
                  ),
                  if (resolvedID != null)
                  Column(
                    children: [
                      InkWell(
                        // toxee: the member-info screen's only navigation
                        // affordance (row -> that member's user profile). Its
                        // label is the localized `tL10n.profile`, so real-UI
                        // automation needs a stable handle to reach the profile
                        // from the member-info route. Automation-only key.
                        key: const ValueKey('group_member_info_profile_entry'),
                        onTap: () {
                          navigateToUserProfile(
                            context: context,
                            options: TencentCloudChatUserProfileOptions(
                              userID: resolvedID,
                              isNavigatedFromChat: false,
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: getWidth(16), vertical: getHeight(12)),
                          width: MediaQuery.of(context).size.width,
                          color: colorTheme.groupProfileTabBackground,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(tL10n.profile,
                                    style: TextStyle(
                                        color: colorTheme.groupProfileTabTextColor, fontSize: textStyle.fontsize_16)),
                              ),
                              Icon(Icons.chevron_right, color: colorTheme.groupProfileTextColor, size: getSquareSize(20))
                            ],
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ));
  }
}
