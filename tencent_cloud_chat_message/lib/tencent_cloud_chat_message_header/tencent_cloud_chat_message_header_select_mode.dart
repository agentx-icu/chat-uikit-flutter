import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';

class TencentCloudChatMessageHeaderSelectMode extends StatefulWidget {
  final int selectAmount;
  final VoidCallback onCancelSelect;
  final VoidCallback onClearSelect;

  const TencentCloudChatMessageHeaderSelectMode({
    super.key,
    required this.selectAmount,
    required this.onCancelSelect,
    required this.onClearSelect,
  });

  @override
  State<TencentCloudChatMessageHeaderSelectMode> createState() =>
      _TencentCloudChatMessageHeaderSelectModeState();
}

class _TencentCloudChatMessageHeaderSelectModeState
    extends TencentCloudChatState<TencentCloudChatMessageHeaderSelectMode> {
  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) => Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // toxee: automation anchors for the multi-select header bar.
                  // The three keys below are the ONLY handles on this surface —
                  // it renders no icons and every label is localized, so a
                  // real-UI case had to tap raw text before. Automation-only:
                  // no behaviour/layout/callback change.
                  //   message_select_clear_button   clears the selection
                  //   message_select_count_text     "<n> selected" live count
                  //   message_select_cancel_button  leaves select mode
                  TextButton(
                    key: const ValueKey('message_select_clear_button'),
                    onPressed: widget.onClearSelect,
                    child: Text(
                      tL10n.clear,
                      style: TextStyle(fontSize: textStyle.fontsize_14),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                key: const ValueKey('message_select_count_text'),
                tL10n.numSelect(widget.selectAmount),
                style: TextStyle(
                  fontSize: textStyle.fontsize_16,
                  // Semibold (600) to match the chat header title weight.
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('message_select_cancel_button'),
                    onPressed: widget.onCancelSelect,
                    child: Text(
                      tL10n.cancel,
                      style: TextStyle(fontSize: textStyle.fontsize_14),
                    ),
                  )
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
