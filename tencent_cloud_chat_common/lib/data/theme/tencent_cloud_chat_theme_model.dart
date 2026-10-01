import 'package:flutter/material.dart';
// ignore_for_file: unnecessary_getters_setters

import 'package:tencent_cloud_chat_common/data/theme/color/color_base.dart';
import 'package:tencent_cloud_chat_common/data/theme/color/dark.dart';
import 'package:tencent_cloud_chat_common/data/theme/color/light.dart';
import 'package:tencent_cloud_chat_common/data/theme/text_style/text_style.dart';

/// A class that contains the core theme model for TencentCloudChat .
class TencentCloudChatThemeModel {
  TencentCloudChatThemeColors _lightTheme;
  TencentCloudChatThemeColors _darkTheme;
  TencentCloudChatTextStyle _textStyle;
  final TencentCloudChatVisualStyle visualStyle;

  /// Creates a new TencentCloudChatThemeModel with the given light and dark theme colors, and text styles.
  TencentCloudChatThemeModel({
    TencentCloudChatThemeColors? lightTheme,
    TencentCloudChatThemeColors? darkTheme,
    TencentCloudChatTextStyle? textStyle,
    this.visualStyle = const TencentCloudChatVisualStyle(),
  })  : _textStyle = textStyle ?? TencentCloudChatTextStyle(),
        _darkTheme = darkTheme ?? DarkTencentCloudChatColors(),
        _lightTheme = lightTheme ?? LightTencentCloudChatColors();

  /// Getter for the light theme colors.
  TencentCloudChatThemeColors get lightTheme => _lightTheme;

  /// Setter for the light theme colors.
  set lightTheme(TencentCloudChatThemeColors value) {
    _lightTheme = value;
  }

  /// Getter for the dark theme colors.
  TencentCloudChatThemeColors get darkTheme => _darkTheme;

  /// Setter for the dark theme colors.
  set darkTheme(TencentCloudChatThemeColors value) {
    _darkTheme = value;
  }

  /// Getter for the text styles.
  TencentCloudChatTextStyle get textStyle => _textStyle;

  /// Setter for the text styles.
  set textStyle(TencentCloudChatTextStyle value) {
    _textStyle = value;
  }
}

/// Geometry shared by native UIKit widgets; defaults preserve host compatibility.
@immutable
class TencentCloudChatVisualStyle {
  final double panelRadius, controlRadius, bubbleRadius, bubbleTailRadius;
  final double outlineWidth, shadowOffset;
  const TencentCloudChatVisualStyle(
      {this.panelRadius = 12,
      this.controlRadius = 8,
      this.bubbleRadius = 12,
      this.bubbleTailRadius = 12,
      this.outlineWidth = 0,
      this.shadowOffset = 0});

  BorderRadius bubbleBorderRadius(bool sentFromSelf) => BorderRadius.only(
        topLeft: Radius.circular(bubbleRadius),
        topRight: Radius.circular(bubbleRadius),
        bottomLeft:
            Radius.circular(sentFromSelf ? bubbleRadius : bubbleTailRadius),
        bottomRight:
            Radius.circular(sentFromSelf ? bubbleTailRadius : bubbleRadius),
      );
}
