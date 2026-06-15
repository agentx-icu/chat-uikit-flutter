import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_robot/tencent_cloud_chat_robot_model.dart';
import 'package:tencent_cloud_chat_robot/tencent_cloud_chat_robot_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

class TencentCloudChatRobotCardMessage extends StatefulWidget {
  final TencentCloudChatRobotData robotData;
  const TencentCloudChatRobotCardMessage({
    super.key,
    required this.robotData,
  });

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatRobotCardMessageState();
}

class TencentCloudChatRobotCardMessageState
    extends State<TencentCloudChatRobotCardMessage> {
  sendMessage(String content) async {
    V2TimValueCallback<V2TimMsgCreateInfoResult> createRes =
        await TencentImSDKPlugin.v2TIMManager
            .getMessageManager()
            .createTextMessage(text: content);
    bool? sendFailed;
    if (createRes.code == 0) {
      if (createRes.data != null) {
        if (createRes.data!.id != null) {
          var id = createRes.data!.id!;
          TencentCloudChatRobotUtils.emitPluginEvent(
            TencentCloudChatRobotPluginEventType.onCreateMessageSuccess,
            Map<String, dynamic>.from({
              "desc": "ok",
              "data": json.encode(createRes.data!.messageInfo?.toJson()),
            }),
          );
          var sendRes = await TencentImSDKPlugin.v2TIMManager
              .getMessageManager()
              .sendMessage(
                  id: id, receiver: widget.robotData.robotID, groupID: "");
          if (sendRes.code == 0 && sendRes.data != null) {
            TencentCloudChatRobotUtils.emitPluginEvent(
              TencentCloudChatRobotPluginEventType.onSendMessageToRobotSuccess,
              Map<String, dynamic>.from({
                "desc": "ok",
                "data": json.encode(sendRes.data!.toJson()),
              }),
            );
            return;
          } else {
            sendFailed = false;
          }
        }
      }
    }
    TencentCloudChatRobotUtils.emitPluginEvent(
      TencentCloudChatRobotPluginEventType.onError,
      Map<String, dynamic>.from({
        "desc": "sendmessage to robot error",
        "dara": json.encode(createRes.toJson()),
        "sendFailed": sendFailed,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The robot plugin has no tencent_cloud_chat_common dependency, so it reads
    // Flutter's own theme — the toxee app wires the ColorScheme to the design
    // tokens, so these slots stay mode-correct (was hardcoded white/black/grey).
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color secondaryColor = scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      width: 290,
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: scheme.surface,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.question_answer_outlined, color: scheme.onSurface),
                      const SizedBox(
                        width: 6,
                      ),
                      Expanded(
                        child: Text(
                          widget.robotData.content.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.robotData.content.content.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.robotData.content.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  Divider(
                    color: scheme.outlineVariant,
                  ),
                  ...widget.robotData.content.items
                      .map(
                        (e) => InkWell(
                          onTap: () async {
                            sendMessage(e.content);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(3),
                                  ),
                                  color: secondaryColor,
                                ),
                              ),
                              const SizedBox(
                                width: 6,
                              ),
                              Expanded(
                                child: Text(
                                  e.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: secondaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_sharp,
                                color: secondaryColor,
                              )
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  // ListTile(
                  //   title: Text(widget.robotData.content.title),
                  //   subtitle: Text(widget.robotData.content.content),
                  //   leading: const Icon(Icons.question_answer_rounded),
                  // ),
                  // const Divider(),
                  // ...widget.robotData.content.items
                  //     .map(
                  //       (e) => ListTile(
                  //         subtitle: Text(e.content),
                  //       ),
                  //     )
                  //     .toList(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
