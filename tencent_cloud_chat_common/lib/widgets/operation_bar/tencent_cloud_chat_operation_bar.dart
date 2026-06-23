import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';

enum OperationBarType { labelButton, switchControl, stringValue }

class TencentCloudChatOperationBar<T> extends StatefulWidget {
  final String label;
  final T value;
  final ValueChanged<T>? onChange;
  final OperationBarType operationBarType;

  /// Optional key applied to the inner control (Switch/TextButton) rather
  /// than the whole bar, so test/automation can target the control directly.
  /// The bar's own `key` lands on the centered Row (the label region), so a
  /// key-tap there would miss the right-aligned switch — this puts the anchor
  /// on the actual interactive widget. Mirrors how the conversation-mute
  /// switch is directly keyed in the user-profile body.
  final Key? controlKey;

  const TencentCloudChatOperationBar({
    Key? key,
    required this.label,
    required this.value,
    this.onChange,
    required this.operationBarType,
    this.controlKey,
  }) : super(key: key);

  @override
  State<TencentCloudChatOperationBar> createState() =>
      _TencentCloudChatOperationBarState<T>();
}

class _TencentCloudChatOperationBarState<T>
    extends TencentCloudChatState<TencentCloudChatOperationBar<T>> {
  @override
  Widget defaultBuilder(BuildContext context) {
    WidgetStateProperty<Color?> getTrackColor(colorTheme) {
      final WidgetStateProperty<Color?> trackColor =
          WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          // Track color when the switch is selected.
          if (states.contains(WidgetState.selected)) {
            return colorTheme.contactAddContactFriendInfoStateButtonActiveColor;
          }
          // Otherwise return null to set default track color
          // for remaining states such as when the switch is
          // hovered, focused, or disabled.
          return null;
        },
      );
      return trackColor;
    }

    return TencentCloudChatThemeWidget(
        build: (context, colorTheme, textStyle) => Material(
              color: colorTheme.groupProfileTabBackground,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: getWidth(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                            color: colorTheme.secondaryTextColor, fontSize: 16),
                      ),
                    ),
                    if (widget.operationBarType == OperationBarType.labelButton)
                      TextButton(
                        key: widget.controlKey,
                        onPressed: () => widget.onChange?.call(widget.value),
                        child: Text(widget.label),
                      )
                    else if (widget.operationBarType ==
                        OperationBarType.switchControl)
                      Switch(
                        key: widget.controlKey,
                        value: widget.value as bool,
                        onChanged: (bool newValue) =>
                            widget.onChange?.call(newValue as T),
                        trackColor: getTrackColor(colorTheme),
                        thumbColor: WidgetStatePropertyAll<Color>(
                            colorTheme.backgroundColor),
                        trackOutlineColor: WidgetStatePropertyAll<Color>(colorTheme
                            .contactAddContactFriendInfoStateButtonBackgroundColor),
                        inactiveThumbColor: colorTheme.backgroundColor,
                      )
                    else if (widget.operationBarType ==
                        OperationBarType.stringValue)
                      Row(
                        children: [
                          Text(widget.value.toString()),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () =>
                                widget.onChange?.call(widget.value),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ));
  }
}
