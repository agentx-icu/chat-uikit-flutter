import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_platform_adapter.dart';

class TencentCloudChatGestureColors {
  Color? focusColor;
  Color? hoverColor;
  Color? highlightColor;
  Color? splashColor;
  TencentCloudChatGestureColors({
    this.focusColor,
    this.highlightColor,
    this.hoverColor,
    this.splashColor,
  });
}

typedef OnTap = void Function();

class TencentCloudChatGesture extends StatefulWidget {
  final Widget child;
  final TencentCloudChatGestureColors? gestureColors;
  final OnTap? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureLongPressCallback? onLongPress;
  // Prefer this over [onLongPress] when callers need the exact press location
  // (e.g. to anchor a context menu). Desktop mouse long-press does not always
  // fire `onTapDown` first, so caching `_lastPrimaryTapDownDetails` is
  // unreliable — `onLongPressStart` delivers `globalPosition` directly.
  final GestureLongPressStartCallback? onLongPressStart;
  final Function(TapDownDetails)? onSecondaryTapDown;
  const TencentCloudChatGesture({
    super.key,
    required this.child,
    this.gestureColors,
    this.onTap,
    this.onTapDown,
    this.onLongPress,
    this.onLongPressStart,
    this.onSecondaryTapDown,
  });

  @override
  State<StatefulWidget> createState() => TencentCloudChatGestureState();
}

class TencentCloudChatGestureState extends State<TencentCloudChatGesture> {
  TencentCloudChatGestureColors getDefaultColors() {
    Color focusColor =
        widget.gestureColors?.focusColor ?? const Color.fromARGB(8, 0, 0, 0);
    Color hoverColor =
        widget.gestureColors?.focusColor ?? const Color.fromARGB(8, 0, 0, 0);
    Color highlightColor =
        widget.gestureColors?.focusColor ?? const Color.fromARGB(8, 0, 0, 0);
    Color splashColor =
        widget.gestureColors?.focusColor ?? const Color.fromARGB(8, 0, 0, 0);
    return TencentCloudChatGestureColors(
      focusColor: focusColor,
      hoverColor: hoverColor,
      highlightColor: highlightColor,
      splashColor: splashColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    TencentCloudChatGestureColors colors = getDefaultColors();

    // Material's `InkWell` does not expose `onLongPressStart` (Material's
    // long-press contract is a zero-arg callback). To get the press location
    // we layer a `GestureDetector` *above* the `InkWell`:
    //   - InkWell still handles ripple/feedback, onTap, onTapDown,
    //     onSecondaryTapDown, hover/focus colors.
    //   - GestureDetector intercepts long-press to deliver
    //     `LongPressStartDetails` (carries globalPosition reliably on both
    //     touch and desktop mouse). When a caller supplies
    //     `onLongPressStart`, we route through the detector and disable
    //     InkWell's own `onLongPress` to avoid a double-fire.
    final inkwell = InkWell(
      onTap: widget.onTap,
      onTapDown: widget.onTapDown,
      onLongPress: widget.onLongPressStart != null ? null : widget.onLongPress,
      onSecondaryTapDown: widget.onSecondaryTapDown,
      focusColor: colors.focusColor,
      hoverColor: colors.hoverColor,
      highlightColor: colors.highlightColor,
      splashColor: !TencentCloudChatPlatformAdapter().isWeb && TencentCloudChatPlatformAdapter().isAndroid
          ? colors.splashColor
          : Colors.transparent, // this field on used on android
      child: widget.child,
    );

    if (widget.onLongPressStart == null) {
      return inkwell;
    }
    // Extend the long-press deadline so a slow horizontal pan (e.g.
    // `SwipeActionCell`'s swipe-to-reveal) has more time to drift past the
    // default ~18 px `preAcceptSlopTolerance` and win the gesture arena before
    // the long-press fires.
    //
    // Approach 2 from the gesture review: bump the long-press deadline from
    // Flutter's default 500 ms to 650 ms. We picked this over Approach 3
    // (tighten `preAcceptSlopTolerance`) because `LongPressGestureRecognizer`
    // does not forward that field through its constructor and the underlying
    // parent field is `final`, so the cleaner path is closed.
    //
    // TODO(gesture): long-press vs SwipeActionCell competition would be more
    // robustly solved by a `Listener`-based motion guard or a custom recognizer
    // that overrides `handleEvent` to reject on smaller drift — see the
    // gesture review report.
    return RawGestureDetector(
      // Translucent so taps still reach the underlying InkWell for ripple.
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: const Duration(milliseconds: 650),
          ),
          (recognizer) {
            recognizer.onLongPressStart = widget.onLongPressStart;
          },
        ),
      },
      child: inkwell,
    );
  }
}
