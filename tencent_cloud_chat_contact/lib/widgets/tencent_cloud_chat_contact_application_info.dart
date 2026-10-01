// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/data/theme/color/color_base.dart';
import 'package:tencent_cloud_chat_common/data/theme/text_style/text_style.dart';
import 'package:tencent_cloud_chat_common/models/tencent_cloud_chat_models.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_safe_dialog_pop.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_common/builders/tencent_cloud_chat_common_builders.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat_common.dart';
import 'package:tencent_cloud_chat_contact/widgets/tencent_cloud_chat_contact_leading.dart';
import 'package:tencent_cloud_chat_contact/widgets/tencent_cloud_chat_friend_application_operation.dart';

class TencentCloudChatContactApplicationInfo extends StatefulWidget {
  final V2TimFriendApplication application;
  final ContactApplicationResult? applicationResult;

  const TencentCloudChatContactApplicationInfo({
    Key? key,
    required this.application,
    this.applicationResult,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactApplicationInfoState();
}

class TencentCloudChatContactApplicationInfoState
    extends TencentCloudChatState<TencentCloudChatContactApplicationInfo> {
  ContactApplicationResult? _result;

  void getActionFromApplication(ContactApplicationResult result) {
    safeSetState(() => _result = result);
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Scaffold(
            appBar: AppBar(
              leadingWidth: TencentCloudChatContactLeading.width(context),
              leading: TencentCloudChatThemeWidget(
                  build: (context, colorTheme, textStyle) => GestureDetector(
                        key: const ValueKey('contact_detail_back'),
                        onTap: () => popDialogIfCurrent(
                            context, _result ?? widget.applicationResult),
                        child: Row(children: [
                          Padding(padding: EdgeInsets.only(left: getWidth(10))),
                          Icon(
                            Icons.arrow_back_ios_outlined,
                            color: colorTheme.contactBackButtonColor,
                            size: getSquareSize(24),
                          ),
                          Padding(padding: EdgeInsets.only(left: getWidth(8))),
                          Text(
                            tL10n.back,
                            style: TextStyle(
                              color: colorTheme.contactBackButtonColor,
                              fontSize: textStyle.fontsize_14,
                            ),
                          )
                        ]),
                      )),
              title: Text(
                tL10n.info,
                style: TextStyle(
                    fontSize: textStyle.fontsize_16,
                    fontWeight: FontWeight.w600,
                    color: colorTheme.contactItemFriendNameColor),
              ),
              centerTitle: true,
              backgroundColor: colorTheme.contactBackgroundColor,
            ),
            body: Container(
              color: colorTheme.contactApplicationBackgroundColor,
              child: Center(
                child: TencentCloudChatContactApplicationInfoBody(
                    application: widget.application,
                    resultFunction: getActionFromApplication,
                    applicationResult: _result ?? widget.applicationResult),
              ),
            )));
  }
}

class TencentCloudChatContactApplicationInfoBody extends StatefulWidget {
  final V2TimFriendApplication application;
  final Function? resultFunction;
  final ContactApplicationResult? applicationResult;

  const TencentCloudChatContactApplicationInfoBody({
    Key? key,
    required this.application,
    this.resultFunction,
    this.applicationResult,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactApplicationInfoBodyState();
}

class TencentCloudChatContactApplicationInfoBodyState
    extends TencentCloudChatState<TencentCloudChatContactApplicationInfoBody> {
  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: getHeight(28)),
                  padding: EdgeInsets.symmetric(
                      vertical: getHeight(10), horizontal: getWidth(16)),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                      width: 1,
                      color: colorTheme.contactItemTabItemBorderColor,
                    )),
                    color: colorTheme.contactBackgroundColor,
                  ),
                  child: Row(children: [
                    TencentCloudChat
                        .instance.dataInstance.contact.contactBuilder
                        ?.getContactApplicationInfoAvatarBuilder(
                            widget.application),
                    TencentCloudChat
                        .instance.dataInstance.contact.contactBuilder
                        ?.getContactApplicationInfoContentBuilder(
                            widget.application)
                  ]),
                ),
                Container(
                  color: colorTheme.contactBackgroundColor,
                  padding: EdgeInsets.symmetric(
                      vertical: getHeight(12), horizontal: getWidth(16)),
                  child: TencentCloudChat
                      .instance.dataInstance.contact.contactBuilder
                      ?.getContactApplicationInfoAddWordingBuilder(
                          widget.application),
                ),
                Row(
                  children: [
                    // Expanded: the buttons fill the row from bounded
                    // constraints instead of sizing to the screen width.
                    Expanded(
                      child: TencentCloudChat
                              .instance.dataInstance.contact.contactBuilder
                              ?.getContactApplicationInfoButtonBuilder(
                                  widget.application,
                                  widget.resultFunction,
                                  widget.applicationResult) ??
                          const SizedBox.shrink(),
                    )
                  ],
                )
              ],
            ));
  }
}

class TencentCloudChatContactApplicationInfoAvatar extends StatefulWidget {
  final V2TimFriendApplication application;

  const TencentCloudChatContactApplicationInfoAvatar(
      {super.key, required this.application});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactApplicationInfoAvatarState();
}

class TencentCloudChatContactApplicationInfoAvatarState
    extends TencentCloudChatState<
        TencentCloudChatContactApplicationInfoAvatar> {
  @override
  Widget defaultBuilder(BuildContext context) {
    // Tox friend applications carry no avatar URL, so faceUrl is null here.
    // The upstream `faceUrl!` null-asserts and throws ("Null check operator used
    // on a null value") during build, which replaces this avatar with an
    // ErrorWidget whose unbounded intrinsic size then overflows the parent
    // Row/Column by ~99k px. Treat null as empty so the default-avatar branch
    // renders. (Shared UIKit code → fixes desktop + mobile alike.)
    if ((widget.application.faceUrl ?? '').isEmpty) {
      return Padding(
          padding: EdgeInsets.symmetric(horizontal: getWidth(13)),
          child: TencentCloudChatCommonBuilders.getCommonAvatarBuilder(
            scene: TencentCloudChatAvatarScene.contacts,
            imageList: [widget.application.faceUrl],
            width: getSquareSize(43),
            height: getSquareSize(43),
            // Friend application (person) → circle (radius = size / 2).
            borderRadius: getSquareSize(21.5),
          ));
    }
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: getWidth(13)),
        child: TencentCloudChatCommonBuilders.getCommonAvatarBuilder(
          scene: TencentCloudChatAvatarScene.contacts,
          imageList: [widget.application.faceUrl],
          width: getSquareSize(43),
          height: getSquareSize(43),
          borderRadius: getSquareSize(38),
        ));
  }
}

class TencentCloudChatContactApplicationInfoContent extends StatefulWidget {
  final V2TimFriendApplication application;

  const TencentCloudChatContactApplicationInfoContent(
      {super.key, required this.application});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactApplicationInfoContentState();
}

class TencentCloudChatContactApplicationInfoContentState
    extends TencentCloudChatState<
        TencentCloudChatContactApplicationInfoContent> {
  @override
  Widget defaultBuilder(BuildContext context) {
    return Expanded(
        child: TencentCloudChatThemeWidget(
            build: (context, colorTheme, textStyle) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      widget.application.nickname ?? widget.application.userID,
                      style: TextStyle(
                          fontSize: textStyle.fontsize_16,
                          fontWeight: FontWeight.w600,
                          color: colorTheme.contactItemFriendNameColor),
                    ),
                    Text(
                      "ID: ${widget.application.userID}",
                      style: TextStyle(
                          color: colorTheme.contactItemFriendNameColor,
                          fontSize: textStyle.fontsize_12,
                          fontWeight: FontWeight.w400),
                    )
                  ],
                )));
  }
}

class TencentCloudChatContentApplicationInfoAddwording extends StatefulWidget {
  final V2TimFriendApplication application;

  const TencentCloudChatContentApplicationInfoAddwording(
      {super.key, required this.application});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContentApplicationInfoAddwordingState();
}

class TencentCloudChatContentApplicationInfoAddwordingState
    extends TencentCloudChatState<
        TencentCloudChatContentApplicationInfoAddwording> {
  Widget getAddWording(TencentCloudChatThemeColors colorTheme,
      TencentCloudChatTextStyle textStyle) {
    String addwording = "hello";
    if (widget.application.addWording != null) {
      addwording = widget.application.addWording!;
    }
    Widget w = addwording.isEmpty
        ? Container()
        : Text(
            addwording,
            style: TextStyle(
                color: colorTheme.contactItemFriendNameColor,
                fontSize: textStyle.fontsize_16,
                fontWeight: FontWeight.w400),
          );
    return w;
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Container(
            padding: EdgeInsets.symmetric(horizontal: getWidth(16)),
            child: Row(
              children: [
                Expanded(
                    child: Text(
                  tL10n.validationMessages,
                  style: TextStyle(
                    color: colorTheme.contactItemTabItemNameColor,
                    fontSize: textStyle.fontsize_16,
                    fontWeight: FontWeight.w400,
                  ),
                )),
                getAddWording(colorTheme, textStyle)
              ],
            )));
  }
}

class TencentCloudChatContactApplicationInfoButton extends StatefulWidget {
  final V2TimFriendApplication application;
  final Function? resultFunction;
  final ContactApplicationResult? applicationResult;

  const TencentCloudChatContactApplicationInfoButton(
      {super.key,
      required this.application,
      this.resultFunction,
      this.applicationResult});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactApplicationInfoButtonState();
}

class TencentCloudChatContactApplicationInfoButtonState
    extends TencentCloudChatState<TencentCloudChatContactApplicationInfoButton>
    with
        TencentCloudChatFriendApplicationOperation<
            TencentCloudChatContactApplicationInfoButton> {
  @override
  V2TimFriendApplication get friendApplication => widget.application;

  ContactApplicationResult? _result;

  Future<void> onAcceptApplication() => _respond(true);

  Future<void> onRefuseApplication() => _respond(false);

  Future<void> _respond(bool accept) => respondToFriendApplication(
        accept: accept,
        onSuccess: (result) {
          safeSetState(() => _result = result);
          widget.applicationResult?.result = result.result;
          widget.applicationResult?.userID = result.userID;
          widget.resultFunction?.call(result);
        },
      );

  @override
  Widget defaultBuilder(BuildContext context) {
    final result = _result ?? widget.applicationResult;
    if (result?.userID == widget.application.userID &&
        (result?.result.isNotEmpty ?? false)) {
      return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Container(
          width: double.infinity,
          color: colorTheme.contactBackgroundColor,
          margin: EdgeInsets.only(top: getHeight(20)),
          padding: EdgeInsets.symmetric(
              horizontal: getWidth(20), vertical: getHeight(10)),
          child: Text(result!.result,
              style: TextStyle(
                  color: colorTheme.contactItemTabItemNameColor,
                  fontSize: textStyle.fontsize_12)),
        ),
      );
    }
    return Container(
      margin: EdgeInsets.only(top: getHeight(20)),
      child: TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              key: ValueKey(
                  'contact_application_detail_accept_button:${widget.application.userID}'),
              onPressed:
                  applicationOperationPending ? null : onAcceptApplication,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                backgroundColor: colorTheme.backgroundColor,
                foregroundColor: colorTheme.contactAgreeButtonColor,
                alignment: AlignmentDirectional.centerStart,
                shape: const RoundedRectangleBorder(),
                textStyle: TextStyle(
                    fontSize: textStyle.fontsize_16,
                    fontWeight: FontWeight.w400),
              ),
              child: Text(tL10n.agree),
            ),
            Divider(
                height: 1,
                thickness: 1,
                color: colorTheme.contactItemTabItemBorderColor),
            TextButton(
              key: ValueKey(
                  'contact_application_detail_decline_button:${widget.application.userID}'),
              onPressed:
                  applicationOperationPending ? null : onRefuseApplication,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                backgroundColor: colorTheme.backgroundColor,
                foregroundColor: colorTheme.contactRefuseButtonColor,
                alignment: AlignmentDirectional.centerStart,
                shape: const RoundedRectangleBorder(),
                textStyle: TextStyle(
                    fontSize: textStyle.fontsize_16,
                    fontWeight: FontWeight.w400),
              ),
              child: Text(tL10n.refuse),
            ),
          ],
        ),
      ),
    );
  }
}

class TencentCloudChatContactApplicationInfoData {
  final V2TimFriendApplication application;
  final ContactApplicationResult? applicationResult;

  TencentCloudChatContactApplicationInfoData(
      {required this.application, this.applicationResult});

  Map<String, dynamic> toMap() {
    return {'application': application.toString()};
  }

  static TencentCloudChatContactApplicationInfoData fromMap(
      Map<String, dynamic> map) {
    return TencentCloudChatContactApplicationInfoData(
        application: map['application'] as V2TimFriendApplication,
        applicationResult:
            map['applicationResult'] as ContactApplicationResult);
  }
}
