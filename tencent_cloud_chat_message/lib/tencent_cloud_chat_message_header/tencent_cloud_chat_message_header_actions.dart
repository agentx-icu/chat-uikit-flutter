import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';

class TencentCloudChatMessageHeaderActions extends StatelessWidget {
  final VoidCallback? startVoiceCall;
  final VoidCallback? startVideoCall;
  final bool useCallKit;

  /// Video-specific gate on top of [useCallKit]: platforms without a camera
  /// capture backend (Windows/Linux) keep voice calling but must not offer a
  /// video button that would place a call with no outgoing frames.
  final bool useVideoCall;
  final bool callActionsEnabled;

  const TencentCloudChatMessageHeaderActions(
      {super.key,
      this.startVoiceCall,
      this.startVideoCall,
      required this.useCallKit,
      this.useVideoCall = true,
      this.callActionsEnabled = true});

  @override
  Widget build(BuildContext context) {
    final voiceCallHandler = callActionsEnabled ? startVoiceCall : null;
    final videoCallHandler = callActionsEnabled ? startVideoCall : null;

    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Row(
              children: [
                if (startVoiceCall != null && useCallKit)
                  IconButton(
                    // Automation anchor (toxee UiKeys.chatCallVoiceButton). The
                    // fork can't import toxee, so the key string is inlined.
                    key: const ValueKey('chat_call_voice_button'),
                    onPressed: voiceCallHandler,
                    icon: Icon(
                      Icons.call,
                      color: callActionsEnabled
                          ? colorTheme.primaryColor
                          : colorTheme.primaryTextColor.withValues(alpha: 0.35),
                      size: textStyle.inputAreaIcon,
                    ),
                  ),
                if (startVideoCall != null && useCallKit && useVideoCall)
                  IconButton(
                    // Automation anchor (toxee UiKeys.chatCallVideoButton).
                    key: const ValueKey('chat_call_video_button'),
                    onPressed: videoCallHandler,
                    icon: Icon(
                      Icons.videocam,
                      color: callActionsEnabled
                          ? colorTheme.primaryColor
                          : colorTheme.primaryTextColor.withValues(alpha: 0.35),
                      size: textStyle.inputAreaIcon,
                    ),
                  ),
              ],
            ));
  }
}
