import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat_common.dart';

class TencentCloudChatDesktopStickerPanel extends StatefulWidget {
  /// messageList widget scroll controller

  final double desktopStickerBoxPositionX;
  final double desktopStickerBoxPositionY;
  final TencentCloudChatPlugin stickerPluginInstance;
  // final TextFieldWebController textFieldWebController;
  const TencentCloudChatDesktopStickerPanel( // this.textFieldWebController,
      {
    Key? key,
    required this.desktopStickerBoxPositionX,
    required this.desktopStickerBoxPositionY,
    required this.stickerPluginInstance,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _TencentCloudChatDesktopStickerPanelState();
  }
}

class _TencentCloudChatDesktopStickerPanelState extends TencentCloudChatState<TencentCloudChatDesktopStickerPanel> {
  Future<Widget> getPanelFromStickerPlugin() async {
    Widget? wid = await widget.stickerPluginInstance.getWidget(methodName: "stickerPanel");
    if (wid != null) {
      return wid;
    }
    return Container();
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    double width = 440;
    double height = 300;
    final double positionX = widget.desktopStickerBoxPositionX;
    final double positionY = widget.desktopStickerBoxPositionY + 10;
    return Positioned(
      left: positionX,
      bottom: positionY,
      child: TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Container(
          // Stable automation handle for the desktop emoji/sticker panel. The
          // box mounts synchronously when the panel opens (its content is behind
          // a ~60ms FutureBuilder), so real-UI tests detect "panel opened" via
          // this key (resolveKeyCenter walks the Positioned overlay). Was
          // missing, so chat_emoji/chat_sticker could never observe the panel.
          key: const ValueKey('desktop_sticker_panel'),
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: colorTheme.appBarBackgroundColor,
            border: Border.all(color: colorTheme.inputFieldBorderColor),
            boxShadow: [
              // Subtle neutral elevation (no shadow-color theme slot); softer
              // than the previous heavy grey to match the flat reference design.
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: FutureBuilder(
              future: getPanelFromStickerPlugin(),
              builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return snapshot.data!;
                }
                return Container();
              }),
        ),
      ),
    );
  }
}
