import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_common/components/tencent_cloud_chat_components_utils.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_code_info.dart';

class TencentCloudChatTranslate extends StatefulWidget {
  final String msgID;
  final String language;
  final BoxDecoration? decoration;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final Function()? onTranslateSuccess;
  final Function()? onTranslateFailed;
  const TencentCloudChatTranslate(
      {super.key,
      this.decoration,
      this.textStyle,
      this.padding,
      this.onTranslateSuccess,
      this.onTranslateFailed,
      required this.msgID,
      this.language = ""});

  @override
  State<TencentCloudChatTranslate> createState() =>
      _TencentCloudChatTranslateState();
}

class _TencentCloudChatTranslateState extends State<TencentCloudChatTranslate> {
  String translatedText = '';
  bool isTranslating = false;
  bool isError = false;
  bool isInvisible = false;

  @override
  initState() {
    translateText();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (isInvisible) {
      return const SizedBox();
    }
    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
                decoration: widget.decoration ??
                    BoxDecoration(
                        color: colorTheme.primaryColor.withOpacity(0.06),
                        borderRadius: const BorderRadius.all(Radius.circular(8))),
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isTranslating
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              color: colorTheme.secondaryTextColor,
                            ))
                        : Text(
                            translatedText,
                            style: widget.textStyle ??
                                TextStyle(fontSize: 14, color: colorTheme.primaryTextColor),
                          ),
                    if (!isTranslating) ...[
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: Transform.scale(
                              scale: 0.6,
                              child: Checkbox(
                                mouseCursor: SystemMouseCursors.basic,
                                splashRadius: 0,
                                shape: const CircleBorder(),
                                activeColor: colorTheme.secondaryTextColor,
                                value: true,
                                onChanged: (bool? value) {},
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 4,
                          ),
                          Text(
                            tL10n.translatedBy,
                            style: TextStyle(fontSize: 10, color: colorTheme.secondaryTextColor),
                          ),
                        ],
                      )
                    ]
                  ],
                )),
          ),
          if (isError) ...[
            const SizedBox(
              width: 4,
            ),
            InkWell(
                onTap: () {
                  translateText();
                },
                child: Icon(
                  size: 20,
                  Icons.refresh_outlined,
                  color: colorTheme.secondaryTextColor,
                ))
          ]
        ],
      ),
    );
  }

  translateText() async {
    setState(() {
      if (mounted) {
        isTranslating = true;
        isError = false;
        isInvisible = false;
      }
    });
    print("【【【msgID: ${widget.msgID}】】】${widget.language}");
    final translateResult = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .convertVoiceToText(msgID: widget.msgID, language: widget.language);

    isTranslating = false;
    if (translateResult.code == 0 && translateResult.data != null && translateResult.data!.isNotEmpty) {
      setState(() {
        translatedText = translateResult.data!;
      });
      if (widget.onTranslateSuccess != null) {
        widget.onTranslateSuccess!();
      }
    } else {
      if (mounted) {
        TencentCloudChat.instance.callbacks.onUserNotificationEvent(
          TencentCloudChatComponentsEnum.contact,
          TencentCloudChatUserNotificationEvent(
            eventCode: translateResult.code,
            text: tL10n.convertTextFailed,
        ));

        setState(() {
          isInvisible = true;
          isError = true;
          translatedText = translateResult.desc;
        });
      }
      if (widget.onTranslateFailed != null) {
        widget.onTranslateFailed!();
      }
    }
  }
}
