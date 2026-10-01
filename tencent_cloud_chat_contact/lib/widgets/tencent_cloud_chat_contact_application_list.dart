// ignore_for_file: public_member_api_docs, sort_constructors_first, unused_import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_platform_adapter.dart';
import 'package:tencent_cloud_chat_common/data/theme/color/color_base.dart';
import 'package:tencent_cloud_chat_common/data/theme/text_style/text_style.dart';
import 'package:tencent_cloud_chat_common/models/tencent_cloud_chat_models.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_common/builders/tencent_cloud_chat_common_builders.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat_common.dart';
import 'package:tencent_cloud_chat_contact/widgets/tencent_cloud_chat_contact_application_info.dart';
import 'package:tencent_cloud_chat_contact/widgets/tencent_cloud_chat_friend_application_operation.dart';

class TencentCloudChatContactApplicationList extends StatefulWidget {
  final List<V2TimFriendApplication> applicationList;

  const TencentCloudChatContactApplicationList(
      {super.key, required this.applicationList});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactApplicationListState();
}

class TencentCloudChatContactApplicationListState
    extends TencentCloudChatState<TencentCloudChatContactApplicationList> {
  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, fontSize) =>
            widget.applicationList.isNotEmpty
                ? ListView.builder(
                    itemBuilder: (context, index) {
                      var application = widget.applicationList[index];
                      return TencentCloudChatContactApplicationItem(
                          application: application);
                    },
                    itemCount: widget.applicationList.length,
                  )
                : Center(
                    child: Container(
                      key: const ValueKey('contact_applications_list_empty'),
                      child: Text(
                        tL10n.noNewApplication,
                        style: TextStyle(
                          fontSize: fontSize.fontsize_12,
                          color: colorTheme.secondaryTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ));
  }
}

class TencentCloudChatContactApplicationItem extends StatefulWidget {
  final V2TimFriendApplication application;

  const TencentCloudChatContactApplicationItem(
      {super.key, required this.application});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactApplicationItemState();
}

class TencentCloudChatContactApplicationItemState
    extends TencentCloudChatState<TencentCloudChatContactApplicationItem>
    with
        TencentCloudChatFriendApplicationOperation<
            TencentCloudChatContactApplicationItem> {
  @override
  V2TimFriendApplication get friendApplication => widget.application;

  ContactApplicationResult applicationResult =
      ContactApplicationResult(result: "", userID: "");

  void getApplicationResultFromButton(ContactApplicationResult result) {
    safeSetState(() {
      applicationResult = result;
    });
  }

  gotoApplicationInfoPage() async {
    // ApplicationResult applicationResult2 = (await navigateToNewContactApplicationDetail<ApplicationResult>(
    //     context: context, options: TencentCloudChatContactApplicationInfoData(application: widget.application, applicationResult: applicationResult)))!;
    final applicationResult2 = await Navigator.push<ContactApplicationResult>(
        context,
        MaterialPageRoute(
            builder: (context) => TencentCloudChatContactApplicationInfo(
                  application: widget.application,
                  applicationResult: applicationResult,
                )));
    if (!mounted || applicationResult2 == null) return;
    safeSetState(() {
      applicationResult = applicationResult2;
    });
  }

  Future<void> _acceptFromMenu() => _respondFromMenu(true);

  Future<void> _refuseFromMenu() => _respondFromMenu(false);

  Future<void> _respondFromMenu(bool accept) => respondToFriendApplication(
        accept: accept,
        onSuccess: getApplicationResultFromButton,
      );

  Future<void> _copyApplicantId() async {
    await Clipboard.setData(ClipboardData(text: widget.application.userID));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(tL10n.toxIdCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showDesktopContextMenu(Offset globalPosition) async {
    if (applicationOperationPending) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final colorTheme = TencentCloudChat.instance.dataInstance.theme.colorTheme;
    // Accept → success green (reference design success token). No generic
    // "success" theme slot exists, so the sampled hex is inlined here. Reject →
    // themed error color.
    const Color acceptColor = Color(0xFF2BB344);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay == null
            ? globalPosition.dx
            : overlay.size.width - globalPosition.dx,
        overlay == null
            ? globalPosition.dy
            : overlay.size.height - globalPosition.dy,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'accept',
          child: ListTile(
            leading: const Icon(Icons.check, color: acceptColor),
            title: Text(tL10n.accept),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'reject',
          child: ListTile(
            leading: Icon(Icons.close, color: colorTheme.error),
            title: Text(tL10n.reject),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: Text(tL10n.viewToxId),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case 'accept':
        await _acceptFromMenu();
        break;
      case 'reject':
        await _refuseFromMenu();
        break;
      case 'copy':
        await _copyApplicantId();
        break;
    }
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    final platformIsDesktop = TencentCloudChatPlatformAdapter().isDesktop;
    return GestureDetector(
        key: ValueKey('contact_application_item:${widget.application.userID}'),
        onTap: applicationOperationPending ? null : gotoApplicationInfoPage,
        onSecondaryTapDown: platformIsDesktop && !applicationOperationPending
            ? (TapDownDetails details) {
                _showDesktopContextMenu(details.globalPosition);
              }
            : null,
        child: TencentCloudChatThemeWidget(
            build: (context, colorTheme, textStyle) => Container(
                  color: colorTheme.backgroundColor,
                  margin: EdgeInsets.only(top: getHeight(16)),
                  padding: EdgeInsets.symmetric(
                    vertical: getHeight(8),
                    horizontal: getWidth(8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        TencentCloudChat
                            .instance.dataInstance.contact.contactBuilder
                            ?.getContactApplicationItemAvatarBuilder(
                                widget.application),
                        TencentCloudChat
                            .instance.dataInstance.contact.contactBuilder
                            ?.getContactApplicationItemContentBuilder(
                                widget.application),
                        // Bounded to half the row (not Flexible: a loose flex
                        // child would still take a fixed 50% share away from
                        // the Expanded name column). The pair keeps its
                        // natural width and wraps when the cap is reached.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth / 2),
                          child: TencentCloudChat
                                  .instance.dataInstance.contact.contactBuilder
                                  ?.getContactApplicationItemButtonBuilder(
                                      widget.application,
                                      applicationResult,
                                      getApplicationResultFromButton) ??
                              const SizedBox.shrink(),
                        )
                      ],
                    ),
                  ),
                )));
  }
}

class TencentCloudChatContactApplicationItemAvatar extends StatefulWidget {
  final V2TimFriendApplication application;

  const TencentCloudChatContactApplicationItemAvatar(
      {super.key, required this.application});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactApplicationItemAvatarState();
}

class TencentCloudChatContactApplicationItemAvatarState
    extends TencentCloudChatState<
        TencentCloudChatContactApplicationItemAvatar> {
  @override
  Widget defaultBuilder(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(right: getWidth(8)),
        child: TencentCloudChatCommonBuilders.getCommonAvatarBuilder(
          scene: TencentCloudChatAvatarScene.contacts,
          imageList: [widget.application.faceUrl],
          width: getSquareSize(40),
          height: getSquareSize(40),
          // Friend application (person) → circle (radius = size / 2).
          borderRadius: getSquareSize(20),
        ));
  }
}

class TencentCloudChatContactApplicationItemContent extends StatefulWidget {
  final V2TimFriendApplication application;

  const TencentCloudChatContactApplicationItemContent(
      {super.key, required this.application});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatApplicationContentItemState();
}

class TencentCloudChatApplicationContentItemState extends TencentCloudChatState<
    TencentCloudChatContactApplicationItemContent> {
  Widget getAddWording(TencentCloudChatThemeColors colorTheme,
      TencentCloudChatTextStyle textStyle) {
    String addwording = "";
    if (widget.application.addWording != null) {
      addwording = widget.application.addWording!;
    }
    Widget w = addwording.isEmpty
        ? Container()
        : Text(
            key: ValueKey(
              'contact_application_addwording:${widget.application.userID}',
            ),
            addwording,
            style: TextStyle(
                color: colorTheme.contactItemTabItemNameColor,
                fontSize: textStyle.fontsize_12,
                fontWeight: FontWeight.w400),
          );
    return w;
  }

  String getName() {
    if (widget.application.nickname != null &&
        widget.application.nickname!.isNotEmpty) {
      return widget.application.nickname ?? "";
    }
    return widget.application.userID;
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return Expanded(
        child: TencentCloudChatThemeWidget(
            build: (context, colorTheme, textStyle) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      getName(),
                      style: TextStyle(
                          fontSize: textStyle.fontsize_14,
                          fontWeight: FontWeight.w400,
                          color: colorTheme.contactItemFriendNameColor),
                    ),
                    getAddWording(colorTheme, textStyle)
                  ],
                )));
  }
}

class TencentCloudChatApplicationItemButton extends StatefulWidget {
  final V2TimFriendApplication application;
  final ContactApplicationResult? applicationResult;
  final Function? sendApplicationResult;

  const TencentCloudChatApplicationItemButton(
      {Key? key,
      required this.application,
      this.applicationResult,
      this.sendApplicationResult})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatApplicationItemButtonState();
}

class TencentCloudChatApplicationItemButtonState
    extends TencentCloudChatState<TencentCloudChatApplicationItemButton>
    with
        TencentCloudChatFriendApplicationOperation<
            TencentCloudChatApplicationItemButton> {
  @override
  V2TimFriendApplication get friendApplication => widget.application;

  ContactApplicationResult? _result;

  Future<void> onAcceptApplication() => _respond(true);

  Future<void> onRefuseApplication() => _respond(false);

  Future<void> _respond(bool accept) => respondToFriendApplication(
        accept: accept,
        onSuccess: (result) {
          safeSetState(() {
            _result = result;
            widget.applicationResult?.result = result.result;
            widget.applicationResult?.userID = result.userID;
          });
          widget.sendApplicationResult?.call(result);
        },
      );

  @override
  Widget defaultBuilder(BuildContext context) {
    final result = _result ?? widget.applicationResult;
    if (result?.userID == widget.application.userID &&
        (result?.result.isNotEmpty ?? false)) {
      return TencentCloudChatThemeWidget(
          build: (context, colorTheme, textStyle) => Container(
                padding: EdgeInsets.symmetric(
                    horizontal: getWidth(16), vertical: getHeight(5)),
                child: Text(
                  result!.result,
                  style: TextStyle(
                      color: colorTheme.contactItemTabItemNameColor,
                      fontSize: textStyle.fontsize_12,
                      fontWeight: FontWeight.w400),
                ),
              ));
    }

    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          FilledButton(
            key: ValueKey(
                'contact_application_accept_button:${widget.application.userID}'),
            onPressed: applicationOperationPending ? null : onAcceptApplication,
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: colorTheme.contactAgreeButtonColor,
              foregroundColor: colorTheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TencentCloudChat.instance.dataInstance.theme.themeModel.visualStyle.controlRadius)),
              textStyle: TextStyle(
                  fontSize: textStyle.fontsize_14, fontWeight: FontWeight.w400),
            ),
            child: Text(tL10n.accept),
          ),
          OutlinedButton(
            key: ValueKey(
                'contact_application_decline_button:${widget.application.userID}'),
            onPressed: applicationOperationPending ? null : onRefuseApplication,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              foregroundColor: colorTheme.contactRefuseButtonColor,
              backgroundColor: colorTheme.contactBackgroundColor,
              side: BorderSide(color: colorTheme.contactTabItemIconColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TencentCloudChat.instance.dataInstance.theme.themeModel.visualStyle.controlRadius)),
              textStyle: TextStyle(
                  fontSize: textStyle.fontsize_14, fontWeight: FontWeight.w400),
            ),
            child: Text(tL10n.refuse),
          ),
        ],
      ),
    );
  }
}
