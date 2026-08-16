import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/components/component_config/tencent_cloud_chat_message_common_defines.dart';
import 'package:tencent_cloud_chat_common/components/components_definition/tencent_cloud_chat_component_builder_definitions.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_screen_adapter.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_builders.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:flutter_svg/flutter_svg.dart';

@immutable
class AttachmentOverlayLayoutInput {
  const AttachmentOverlayLayoutInput({
    required this.viewportSize,
    required this.safeArea,
    required this.viewInsets,
    required this.tapGlobalDx,
    required this.maxContentWidth,
    this.preferredBottom = 80,
    this.edgeMargin = 16,
  });

  final Size viewportSize;
  final EdgeInsets safeArea;
  final EdgeInsets viewInsets;
  final double tapGlobalDx;
  final double maxContentWidth;
  final double preferredBottom;
  final double edgeMargin;
}

@immutable
class AttachmentOverlayPlacement {
  const AttachmentOverlayPlacement({
    required this.left,
    required this.bottom,
    required this.maxWidth,
    required this.maxHeight,
  });

  final double left;
  final double bottom;
  final double maxWidth;
  final double maxHeight;
}

AttachmentOverlayPlacement computeAttachmentOverlayPlacement(
  AttachmentOverlayLayoutInput input,
) {
  final double usableWidth = math.max<double>(
    0.0,
    input.viewportSize.width -
        input.safeArea.left -
        input.safeArea.right -
        input.edgeMargin * 2,
  );
  final double maxWidth = math.min<double>(
    usableWidth,
    math.max<double>(0.0, input.maxContentWidth - input.edgeMargin * 2),
  );
  final minLeft = input.safeArea.left + input.edgeMargin;
  final double maxLeft = math.max<double>(
    minLeft,
    input.viewportSize.width -
        input.safeArea.right -
        input.edgeMargin -
        maxWidth,
  );
  final double bottom = math.max<double>(
    input.preferredBottom + input.safeArea.bottom,
    input.viewInsets.bottom + input.edgeMargin,
  );
  final double maxHeight = math.max<double>(
    0.0,
    input.viewportSize.height - input.safeArea.top - input.edgeMargin - bottom,
  );
  return AttachmentOverlayPlacement(
    left: input.tapGlobalDx.clamp(minLeft, maxLeft).toDouble(),
    bottom: bottom,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
}

class TencentCloudChatMessageAttachmentOptions {
  OverlayEntry? _overlayEntry;
  late AnimationController _attachmentOptionsAnimationController;
  late Animation<double> _attachmentOptionsAnimation;

  void init({required TickerProvider vsync, required BuildContext context}) {
    _attachmentOptionsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: vsync,
    );
    _attachmentOptionsAnimation = CurvedAnimation(
      parent: _attachmentOptionsAnimationController,
      curve: Curves.easeInOut,
    );
  }

  void dispose() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }

    _attachmentOptionsAnimationController.dispose();
  }

  Widget _buildAttachmentOptions(
      {required BoxConstraints constraints,
      required double maxHeight,
      required BuildContext context,
      required MAOInternalBuilder? messageAttachmentOptionsBuilder,
      required List<TencentCloudChatMessageGeneralOptionItem>
          attachmentOptions}) {
    final isMobile = TencentCloudChatScreenAdapter.deviceScreenType ==
        DeviceScreenType.mobile;
    final isArabic =
        TencentCloudChat.instance.cache.getCachedLocale()?.languageCode == 'ar';
    return SlideTransition(
      position: _attachmentOptionsAnimation.drive(Tween<Offset>(
        begin: isMobile
            ? (isArabic ? const Offset(0, 0) : const Offset(-1, 0))
            : const Offset(0, 0),
        end: isArabic ? const Offset(-1, 0) : const Offset(0, 0),
      )),
      child: SizeTransition(
        sizeFactor: _attachmentOptionsAnimation,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth,
            maxHeight: maxHeight,
          ),
          child: messageAttachmentOptionsBuilder?.call(
            data: MessageAttachmentOptionsBuilderData(
              attachmentOptions: attachmentOptions,
            ),
            methods: MessageAttachmentOptionsBuilderMethods(
              onActionFinish: _removeEntry,
            ),
          ),
        ),
      ),
    );
  }

  void toggleAttachmentOptionsOverlay(
      {required BoxConstraints constraints,
      required BuildContext context,
      required MAOInternalBuilder? messageAttachmentOptionsBuilder,
      required TapDownDetails tapDownDetails,
      required List<TencentCloudChatMessageGeneralOptionItem>
          attachmentOptions}) {
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: (BuildContext context) {
        final mediaQuery = MediaQuery.of(context);
        final placement = computeAttachmentOverlayPlacement(
          AttachmentOverlayLayoutInput(
            viewportSize: mediaQuery.size,
            safeArea: mediaQuery.padding,
            viewInsets: mediaQuery.viewInsets,
            tapGlobalDx: tapDownDetails.globalPosition.dx,
            maxContentWidth: constraints.maxWidth,
          ),
        );
        return GestureDetector(
          onTap: () {
            _removeEntry();
          },
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned(
                  bottom: placement.bottom,
                  left: placement.left,
                  child: GestureDetector(
                    onTap: () {},
                    child: _buildAttachmentOptions(
                        constraints: BoxConstraints(
                          maxWidth: placement.maxWidth,
                        ),
                        maxHeight: placement.maxHeight,
                        context: context,
                        messageAttachmentOptionsBuilder:
                            messageAttachmentOptionsBuilder,
                        attachmentOptions: attachmentOptions),
                  ),
                ),
              ],
            ),
          ),
        );
      });

      Overlay.of(context).insert(_overlayEntry!);
      _attachmentOptionsAnimationController.forward();
    } else {
      _removeEntry();
    }
  }

  void _removeEntry() {
    _attachmentOptionsAnimationController.reverse().then((value) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }
}

class TencentCloudChatMessageAttachmentOptionsWidget extends StatefulWidget {
  final MessageAttachmentOptionsBuilderWidgets? widgets;
  final MessageAttachmentOptionsBuilderData data;
  final MessageAttachmentOptionsBuilderMethods methods;

  const TencentCloudChatMessageAttachmentOptionsWidget({
    super.key,
    this.widgets,
    required this.data,
    required this.methods,
  });

  @override
  State<TencentCloudChatMessageAttachmentOptionsWidget> createState() =>
      _TencentCloudChatMessageAttachmentOptionsWidgetState();
}

class _TencentCloudChatMessageAttachmentOptionsWidgetState
    extends TencentCloudChatState<
        TencentCloudChatMessageAttachmentOptionsWidget> {
  /// toxee automation anchor for a mobile attachment-panel entry.
  ///
  /// The panel is DATA-driven (`attachmentOptions` is a plain list built by the
  /// app), so there is no per-entry slot to hang a key on — the key is derived
  /// from the option's `IconData`, exactly the contract
  /// `lib/ui/testing/ui_keys.dart` documents. Only the icons toxee actually
  /// injects are mapped (`buildToxeeMobileAttachmentOptions`: File + Camera);
  /// an unmapped option returns null and renders exactly as before, so this
  /// cannot introduce duplicate sibling keys.
  ///
  /// `Icons.attach_file` intentionally reuses the DESKTOP toolbar's
  /// `message_attachment_file_button` string: the two surfaces are never
  /// mounted at the same time (platform-exclusive composers), and sharing it
  /// lets one real-UI case cover both.
  static Key? _attachmentOptionKey(
      TencentCloudChatMessageGeneralOptionItem item) {
    final IconData? icon = item.icon;
    if (icon == null) return null;
    if (icon == Icons.attach_file) {
      return const ValueKey('message_attachment_file_button');
    }
    if (icon == Icons.camera_alt_outlined) {
      return const ValueKey('message_attachment_camera_button');
    }
    return null;
  }

  Widget _buildAttachmentOptionsItem(
      TencentCloudChatMessageGeneralOptionItem item) {
    return TencentCloudChatThemeWidget(build: (context, colorTheme, textStyle) {
      return InkWell(
        key: _attachmentOptionKey(item),
        onTap: () {
          widget.methods.onActionFinish();
          item.onTap();
        },
        child: SizedBox(
          width: 62,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorTheme.primaryColor,
                  border: Border.all(color: colorTheme.primaryColor, width: 12),
                ),
                child: () {
                  if (item.iconAsset != null) {
                    final type = item.iconAsset!.path
                        .split(".")[item.iconAsset!.path.split(".").length - 1];
                    if (type == "svg") {
                      return SvgPicture.asset(
                        item.iconAsset!.path,
                        package: item.iconAsset!.package,
                        width: 16,
                        height: 16,
                        colorFilter: ui.ColorFilter.mode(
                          colorTheme.backgroundColor,
                          ui.BlendMode.srcIn,
                        ),
                      );
                    }
                    return Image.asset(
                      item.iconAsset!.path,
                      package: item.iconAsset!.package,
                      color: colorTheme.inputAreaIconColor.withOpacity(0.6),
                      width: 16,
                      height: 16,
                    );
                  }
                  if (item.icon != null) {
                    return Icon(
                      item.icon,
                      color: colorTheme.backgroundColor,
                      size: textStyle.standardLargeText,
                    );
                  }
                }(),
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                item.label,
                style: TextStyle(
                    color: colorTheme.secondaryTextColor,
                    fontSize: textStyle.standardSmallText),
              )
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Container(
              decoration: BoxDecoration(
                color: colorTheme.inputAreaBackground,
                border: Border.all(color: colorTheme.dividerColor, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Material(
                  color: colorTheme.inputAreaBackground,
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: widget.data.attachmentOptions
                        .map((e) => _buildAttachmentOptionsItem(e))
                        .toList(),
                  ),
                ),
              ),
            ));
  }
}
