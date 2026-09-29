import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat_common.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_safe_dialog_pop.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_screen_adapter.dart';

class TencentCloudChatContactLeading extends StatefulWidget {
  const TencentCloudChatContactLeading({super.key});

  /// toxee(L11): the app-bar `leadingWidth` for a "‹ Back" leading: 100, or
  /// what the label needs at the system text scale when that is more (a fixed
  /// 100 cut it to "Ba…"). Measured rather than scaled, so the title keeps
  /// its room on a narrow phone; capped at 40% of the width, where the label
  /// ellipsizes.
  static double width(BuildContext context) {
    final base = TencentCloudChatScreenAdapter.getWidth(100);
    final painter = TextPainter(
      text: TextSpan(
        text: tL10n.back,
        style: TextStyle(
          fontSize:
              TencentCloudChat.instance.dataInstance.theme.textStyle.fontsize_14,
        ),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // Row padding + icon + gap (see the build below), plus a hair of slack.
    final needed = TencentCloudChatScreenAdapter.getWidth(10) +
        TencentCloudChatScreenAdapter.getSquareSize(24) +
        TencentCloudChatScreenAdapter.getWidth(8) +
        painter.width +
        4;
    painter.dispose();
    final cap = MediaQuery.sizeOf(context).width * 0.4;
    return needed <= base ? base : (needed < cap ? needed : (cap > base ? cap : base));
  }

  @override
  State<StatefulWidget> createState() => TencentCloudChatContactLeadingState();
}

class TencentCloudChatContactLeadingState
    extends TencentCloudChatState<TencentCloudChatContactLeading> {
  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => GestureDetector(
              key: const ValueKey('contact_detail_back'),
              onTap: () => popDialogIfCurrent(context),
              child: Row(children: [
                Padding(padding: EdgeInsets.only(left: getWidth(10))),
                Icon(
                  Icons.arrow_back_ios_outlined,
                  color: colorTheme.contactBackButtonColor,
                  size: getSquareSize(24),
                ),
                Padding(padding: EdgeInsets.only(left: getWidth(8))),
                // Flexible: hosts give this a fixed leadingWidth (100 px);
                // long locales / large text would overflow it.
                Flexible(
                  child: Text(
                    tL10n.back,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorTheme.contactBackButtonColor,
                      fontSize: textStyle.fontsize_14,
                    ),
                  ),
                )
              ]),
            ));
  }
}
