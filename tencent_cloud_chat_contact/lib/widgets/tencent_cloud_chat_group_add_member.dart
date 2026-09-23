// ignore_for_file: public_member_api_docs, sort_constructors_first, unnecessary_null_comparison
import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/components/tencent_cloud_chat_components_utils.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_code_info.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_safe_dialog_pop.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_utils.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat_common.dart';
import 'package:tencent_cloud_chat_contact/model/contact_presenter.dart';
import 'package:tencent_cloud_chat_contact/widgets/group_action_failure_text.dart';
import 'package:tencent_cloud_chat_contact/widgets/tencent_cloud_chat_contact_index_bar_fit.dart';
import 'package:tencent_cloud_chat_contact/widgets/tencent_cloud_chat_group_member_list.dart';

class TencentCloudChatGroupAddMember extends StatefulWidget {
  final V2TimGroupInfo groupInfo;
  final List<V2TimGroupMemberFullInfo> memberList;
  final List<V2TimFriendInfo> contactList;

  const TencentCloudChatGroupAddMember(
      {super.key,
      required this.memberList,
      required this.contactList,
      required this.groupInfo});

  @override
  State<StatefulWidget> createState() => TencentCloudChatGroupAddMemberState();
}

class TencentCloudChatGroupAddMemberState
    extends TencentCloudChatState<TencentCloudChatGroupAddMember> {
  ContactPresenter contactPresenter = ContactPresenter();

  /// Invite the selected friends and REPORT the per-user outcome. The result
  /// used to be discarded except for PENDING (3), so a failed invite was
  /// silently lost while the page closed as if it had worked. Outcomes:
  ///   * the whole call fails / throws → one reason-bearing notice
  ///     ([groupActionFailureText]: no permission, not connected, …);
  ///   * per-user FAIL / INVALID / OVERLIMIT → the failed friends by name;
  ///   * PENDING (e.g. an invite queued for an offline friend) → requestWait.
  Future<void> submitAdd() async {
    final invitees = List<V2TimFriendInfo>.of(selectedContacts);
    final userIDList = invitees.map((e) => e.userID).toList();
    if (userIDList.isEmpty) return;
    final V2TimValueCallback<List<V2TimGroupMemberOperationResult>> result;
    try {
      result = await contactPresenter.inviteUserToGroup(
          groupID: widget.groupInfo.groupID, userList: userIDList);
    } catch (e) {
      _notifyInvite(-1, tL10n.inviteRequestFailed);
      return;
    }
    if (result.code != 0) {
      _notifyInvite(result.code,
          groupActionFailureText(result.code, tL10n.inviteRequestFailed));
      return;
    }
    final failedIDs = <String>[];
    var pending = false;
    final ops = result.data ?? const <V2TimGroupMemberOperationResult>[];
    for (var i = 0; i < userIDList.length; i++) {
      final id = userIDList[i];
      V2TimGroupMemberOperationResult? op;
      for (final candidate in ops) {
        if (candidate.memberID == id) op = candidate;
      }
      // Positional fallback for results that carry no member id.
      op ??= (i < ops.length && ops[i].memberID == null) ? ops[i] : null;
      switch (op?.result) {
        case 1: // SUCC
        case null: // no per-user verdict: the call itself succeeded
          break;
        case 3: // PENDING
          pending = true;
          break;
        default: // FAIL (0), INVALID (2), OVERLIMIT (4)
          failedIDs.add(id);
      }
    }
    if (pending) {
      _notifyInvite(0, tL10n.requestWait);
    }
    if (failedIDs.isNotEmpty) {
      final names = failedIDs
          .map((id) => _inviteeName(invitees.firstWhere((f) => f.userID == id)))
          .join(', ');
      _notifyInvite(-1, tL10n.inviteMembersFailed(names));
    }
  }

  static String _inviteeName(V2TimFriendInfo friend) {
    final name = TencentCloudChatUtils.checkString(friend.friendRemark) ??
        TencentCloudChatUtils.checkString(friend.userProfile?.nickName);
    if (name != null) return name;
    final id = friend.userID;
    return id.length > 12 ? '${id.substring(0, 12)}…' : id;
  }

  static void _notifyInvite(int code, String text) {
    TencentCloudChat.instance.callbacks.onUserNotificationEvent(
        TencentCloudChatComponentsEnum.contact,
        TencentCloudChatUserNotificationEvent(eventCode: code, text: text));
  }

  List<V2TimFriendInfo> selectedContacts = [];
  bool _submitting = false;

  onChanged(selected) {
    selectedContacts = selected;
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => popDialogIfCurrent(context),
                icon: const Icon(Icons.arrow_back_ios_rounded),
                color: colorTheme.primaryColor,
              ),
              title: Text(
                tL10n.addMembers,
                style: TextStyle(
                    fontSize: textStyle.fontsize_16,
                    fontWeight: FontWeight.w600,
                    color: colorTheme.contactItemFriendNameColor),
              ),
              centerTitle: true,
              actions: [
                // Key on a KeyedSubtree wrapper, NOT the TextButton: this
                // onPressed both invites and POPS, and flutter_skill's tap would
                // otherwise fire it twice (synthetic pointer + the
                // _tryInvokeCallback fallback that directly calls TextButton
                // .onPressed) → a double Navigator.pop that blanks the app and a
                // duplicate invite. A KeyedSubtree isn't a type
                // _tryInvokeCallback invokes, so the harness fires it exactly
                // once via the synthetic tap.
                KeyedSubtree(
                  key: const ValueKey('group_member_invite_confirm_button'),
                  child: TextButton(
                    // Await the invite so its per-user outcome is reported,
                    // then pop. `_submitting` makes a second fire (double tap
                    // or harness fallback) a no-op instead of a duplicate
                    // invite; popDialogIfCurrent never pops a route above us.
                    onPressed: () async {
                      if (_submitting) return;
                      _submitting = true;
                      try {
                        await submitAdd();
                      } catch (_) {
                        // Never an unhandled async error from a tap: report
                        // it like a failed invite and still close the page.
                        _notifyInvite(-1, tL10n.inviteRequestFailed);
                      } finally {
                        _submitting = false;
                      }
                      if (!mounted) return;
                      popDialogIfCurrent(context);
                    },
                    child: Text(
                      tL10n.confirm,
                      style: TextStyle(
                        fontSize: textStyle.fontsize_16,
                      ),
                    ),
                  ),
                )
              ],
              scrolledUnderElevation: 0.0,
            ),
            body: TencentCloudChatGroupProfileAddMemberList(
              contactList: widget.contactList,
              memberList: widget.memberList,
              onSelectedMemberItemChange: onChanged,
            )));
  }
}

class TencentCloudChatGroupProfileAddMemberList extends StatefulWidget {
  final List<V2TimGroupMemberFullInfo> memberList;
  final List<V2TimFriendInfo>? contactList;
  final Function onSelectedMemberItemChange;

  const TencentCloudChatGroupProfileAddMemberList({
    Key? key,
    required this.memberList,
    this.contactList,
    required this.onSelectedMemberItemChange,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatGroupProfileAddMemberListState();
}

class TencentCloudChatGroupProfileAddMemberListState
    extends TencentCloudChatState<TencentCloudChatGroupProfileAddMemberList> {
  List<ISuspensionBeanImpl> list = [];
  List<V2TimFriendInfo> selectedMember = [];
  List<V2TimGroupMemberFullInfo> selectedSilencedMember = [];

  @override
  initState() {
    super.initState();
    list = _getListTag();
  }

  _getShowName(V2TimFriendInfo item) {
    final friendRemark = item.friendRemark ?? "";
    final nickName = item.userProfile?.nickName ?? "";
    final userID = item.userID;
    final showName = nickName != "" ? nickName : userID;
    return friendRemark != "" ? friendRemark : showName;
  }

  List<ISuspensionBeanImpl> _getListTag() {
    final List<ISuspensionBeanImpl> showList = List.empty(growable: true);
    if (widget.contactList != null) {
      for (var i = 0; i < widget.contactList!.length; i++) {
        final item = widget.contactList![i];
        final name = TencentCloudChatUtils.checkString(
                widget.contactList![i].userProfile?.nickName) ??
            widget.contactList![i].userID;
        String tag = name.substring(0, 1).toUpperCase();
        if (RegExp("[A-Z]").hasMatch(tag)) {
          showList.add(ISuspensionBeanImpl(memberInfo: item, tagIndex: tag));
        } else {
          tag = "#";
          showList.add(ISuspensionBeanImpl(memberInfo: item, tagIndex: "#"));
        }
      }
    } else {
      for (var i = 0; i < widget.memberList.length; i++) {
        final item = widget.memberList[i];
        final name =
            TencentCloudChatUtils.checkString(item.nameCard) ?? item.userID;
        String tag = name.substring(0, 1).toUpperCase();
        if (RegExp("[A-Z]").hasMatch(tag)) {
          showList.add(ISuspensionBeanImpl(memberInfo: item, tagIndex: tag));
        } else {
          tag = "#";
          showList.add(ISuspensionBeanImpl(memberInfo: item, tagIndex: "#"));
        }
      }
    }

    SuspensionUtil.sortListBySuspensionTag(showList);
    SuspensionUtil.setShowSuspensionStatus(showList);
    return showList;
  }

  Widget _buildItem(V2TimFriendInfo item) {
    final showName = _getShowName(item);
    final faceUrl = item.userProfile?.faceUrl ?? "";

    bool disabled = false;
    if (widget.memberList != null && widget.memberList.isNotEmpty) {
      disabled = ((widget.memberList
              .indexWhere((element) => element.userID == item.userID))) >
          -1;
    }

    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Container(
              padding: EdgeInsets.symmetric(
                vertical: getHeight(8),
                horizontal: getWidth(16),
              ),
              color: colorTheme.backgroundColor,
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 12, bottom: 8),
                    child: CheckBoxButton(
                      disabled: disabled,
                      isChecked: selectedMember.contains(item),
                      onChanged: (isChecked) {
                        if (isChecked) {
                          selectedMember.add(item);
                        } else {
                          selectedMember.remove(item);
                        }
                        if (widget.onSelectedMemberItemChange != null) {
                          widget.onSelectedMemberItemChange(selectedMember);
                        }
                        setState(() {});
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(bottom: 12),
                    margin: const EdgeInsets.only(right: 12),
                    child: TencentCloudChatAvatar(
                      imageList: [TencentCloudChatUtils.checkString(faceUrl)],
                      scene: TencentCloudChatAvatarScene.groupProfile,
                    ),
                  ),
                  Expanded(
                      child: Container(
                    alignment: Alignment.centerLeft,
                    padding:
                        const EdgeInsets.only(top: 10, bottom: 20, right: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          showName,
                          style: TextStyle(
                              color: colorTheme.groupProfileTextColor,
                              fontSize: textStyle.fontsize_14),
                        ),
                        // A Tox group invite is delivered over a live friend
                        // connection; flag friends known to be offline so a
                        // delayed (pending) invite is expected.
                        if (!disabled && _isKnownOffline(item.userID))
                          Text(
                            tL10n.offline,
                            key: ValueKey(
                                'add_member_contact_offline:${item.userID}'),
                            style: TextStyle(
                                color: colorTheme.secondaryTextColor,
                                fontSize: textStyle.fontsize_12),
                          ),
                      ],
                    ),
                  )),
                ],
              ),
            ));
  }

  /// True only when the contact status list HAS an entry for [userID] and it
  /// is not online (toxee publishes friend presence as 1 online / 0 offline;
  /// upstream uses 2/3). No entry = presence unknown = not flagged. Same
  /// "anything but 1 is not online" reading as getOnlineStatusByUserId.
  static bool _isKnownOffline(String userID) {
    for (final status
        in TencentCloudChat.instance.dataInstance.contact.userStatus) {
      if (status.userID == userID) return status.statusType != 1;
    }
    return false;
  }

  Widget _buildMemberSilencedItem(V2TimGroupMemberFullInfo item) {
    bool disabled = false;
    final currentTimeStamp = DateTime.now().millisecondsSinceEpoch;
    if (item.muteUntil != null && item.muteUntil! > 0) {
      disabled = item.muteUntil! * 1000 > currentTimeStamp;
    }
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Container(
              padding: EdgeInsets.symmetric(
                vertical: getHeight(8),
                horizontal: getWidth(16),
              ),
              color: colorTheme.backgroundColor,
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 12, bottom: 8),
                    child: CheckBoxButton(
                      disabled: disabled,
                      isChecked: selectedSilencedMember.contains(item),
                      onChanged: (isChecked) {
                        if (isChecked) {
                          selectedSilencedMember.add(item);
                        } else {
                          selectedSilencedMember.remove(item);
                        }
                        if (widget.onSelectedMemberItemChange != null) {
                          widget.onSelectedMemberItemChange(
                              selectedSilencedMember);
                        }
                        setState(() {});
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(bottom: 12),
                    margin: const EdgeInsets.only(right: 12),
                    child: TencentCloudChatAvatar(
                      imageList: [
                        TencentCloudChatUtils.checkString(item.faceUrl)
                      ],
                      scene: TencentCloudChatAvatarScene.groupProfile,
                    ),
                  ),
                  Expanded(
                      child: Container(
                    alignment: Alignment.centerLeft,
                    padding:
                        const EdgeInsets.only(top: 10, bottom: 20, right: 28),
                    child: Text(
                      TencentCloudChatUtils.checkString(item.nameCard) ??
                          item.userID,
                      style: TextStyle(
                          color: colorTheme.groupProfileTextColor,
                          fontSize: textStyle.fontsize_14),
                    ),
                  )),
                ],
              ),
            ));
  }

  Widget _buildTag(String tag) {
    return Container(
        height: getSquareSize(40),
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.only(left: 16.0, bottom: 5),
        // color: Color.fromARGB(255, 255, 255, 255),
        alignment: Alignment.bottomLeft,
        child: TencentCloudChatThemeWidget(
            build: (context, colorTheme, textStyle) => Text(
                  tag,
                  style: TextStyle(
                    fontSize: textStyle.fontsize_14,
                    fontWeight: FontWeight.w600,
                    color: colorTheme.contactItemFriendNameColor,
                  ),
                )));
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    if (widget.contactList != null) {
      return LayoutBuilder(builder: (context, constraints) {
        final indexBar = TencentCloudChatIndexBarFit.fit(
            SuspensionUtil.getTagIndexList(list)
                .where((element) => element != "@")
                .toList(),
            constraints.maxHeight,
            textScale: MediaQuery.textScalerOf(context).scale(1.0));
        return Scrollbar(
          child: AzListView(
        data: list,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index].memberInfo;
          // The selection key lives on a KeyedSubtree WRAPPER, not on the
          // InkWell itself, on purpose. flutter_skill's tap both dispatches a
          // synthetic pointer AND directly invokes InkWell.onTap as a fallback
          // (_tryInvokeCallback). For a *toggle* onTap that double-fire would
          // select-then-deselect (net empty selection → empty invite). A
          // KeyedSubtree is not one of the widget types _tryInvokeCallback
          // invokes, so the harness fires the toggle exactly once (the
          // synthetic pointer hit-tests through to the InkWell), landing on a
          // deterministic SELECTED state. element.renderObject descends to the
          // InkWell's RenderBox, so the tap still centers correctly.
          return KeyedSubtree(
            key: ValueKey('add_member_contact_item:${item.userID}'),
            child: InkWell(
              onTap: () {
                if (selectedMember.contains(item)) {
                  selectedMember.remove(item);
                } else {
                  selectedMember.add(item);
                }
                if (widget.onSelectedMemberItemChange != null) {
                  widget.onSelectedMemberItemChange(selectedMember);
                }
                setState(() {});
                return;
              },
              child: _buildItem(item),
            ),
          );
        },
        indexBarData: indexBar.tags,
        indexBarItemHeight: indexBar.itemHeight,
        indexBarOptions: indexBar.options,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        susItemHeight: getSquareSize(30),
        susItemBuilder: (context, index) {
          ISuspensionBeanImpl tag = list[index];
          if (tag.getSuspensionTag() == "@") {
            return Container();
          }
          return _buildTag(tag.getSuspensionTag());
        },
      ));
      });
    }
    return LayoutBuilder(builder: (context, constraints) {
      final indexBar = TencentCloudChatIndexBarFit.fit(
          SuspensionUtil.getTagIndexList(list)
              .where((element) => element != "@")
              .toList(),
          constraints.maxHeight,
          textScale: MediaQuery.textScalerOf(context).scale(1.0));
      return Scrollbar(
        child: AzListView(
      data: list,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index].memberInfo;
        return InkWell(
          onTap: () {
            if (selectedSilencedMember.contains(item)) {
              selectedSilencedMember.remove(item);
            } else {
              selectedSilencedMember.add(item);
            }
            widget.onSelectedMemberItemChange(selectedSilencedMember);
            setState(() {});
            return;
          },
          child: _buildMemberSilencedItem(item),
        );
      },
      indexBarData: indexBar.tags,
      indexBarItemHeight: indexBar.itemHeight,
      indexBarOptions: indexBar.options,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      susItemHeight: getSquareSize(30),
      susItemBuilder: (context, index) {
        ISuspensionBeanImpl tag = list[index];
        if (tag.getSuspensionTag() == "@") {
          return Container();
        }
        return _buildTag(tag.getSuspensionTag());
      },
    ));
    });
  }
}

class CheckBoxButton extends StatelessWidget {
  final bool isChecked;
  final Function(bool isChecked)? onChanged;
  final bool disabled;
  final bool onlyShow;
  final double? size;

  const CheckBoxButton(
      {this.disabled = false,
      Key? key,
      this.size,
      this.onlyShow = false,
      required this.isChecked,
      this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TencentCloudChatThemeWidget(build: (context, colorTheme, textStyle) {
      BoxDecoration boxDecoration = !isChecked
          ? BoxDecoration(
              border: Border.all(color: colorTheme.secondaryTextColor),
              shape: BoxShape.circle,
              color: colorTheme.backgroundColor)
          : BoxDecoration(shape: BoxShape.circle, color: colorTheme.primaryColor);

      if (disabled) {
        boxDecoration =
            BoxDecoration(shape: BoxShape.circle, color: colorTheme.dividerColor);
      }
      return Center(
          child: onlyShow
              ? Container(
                  height: size ?? 22,
                  width: size ?? 22,
                  decoration: boxDecoration,
                  child: Icon(
                    Icons.check,
                    size: size != null ? (size! / 2) : 11,
                    color: colorTheme.onPrimary,
                  ),
                )
              : InkWell(
                  onTap: () {
                    if (onChanged != null && !disabled) {
                      onChanged!(!isChecked);
                    }
                  },
                  child: Container(
                    height: size ?? 22,
                    width: size ?? 22,
                    decoration: boxDecoration,
                    child: Icon(
                      Icons.check,
                      size: size != null ? (size! / 2) : 11,
                      color: colorTheme.onPrimary,
                    ),
                  ),
                ));
    });
  }
}
