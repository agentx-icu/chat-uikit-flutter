import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';

/// Resolves the skeleton block color for the current brightness, so shimmer
/// placeholders read as a subtle themed grey in both light and dark mode
/// (instead of a hardcoded white that glows on a dark scaffold).
Color _skeletonBlockColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2E3033) // dark divider tone
      : const Color(0xFFE5E6EB); // light divider tone
}

class TitlePlaceholder extends StatelessWidget {
  final double width;

  const TitlePlaceholder({
    Key? key,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blockColor = _skeletonBlockColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: width,
            height: 12.0,
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          const SizedBox(height: 8.0),
          Container(
            width: width,
            height: 12.0,
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
        ],
      ),
    );
  }
}

enum ContentLineType {
  twoLines,
  threeLines,
}

class ContentPlaceholder extends StatelessWidget {
  final ContentLineType lineType;

  const ContentPlaceholder({
    Key? key,
    required this.lineType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blockColor = _skeletonBlockColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56.0,
            height: 56.0,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28.0),
              color: blockColor,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 10.0,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  margin: const EdgeInsets.only(bottom: 8.0),
                ),
                if (lineType == ContentLineType.threeLines)
                  Container(
                    width: double.infinity,
                    height: 10.0,
                    decoration: BoxDecoration(
                      color: blockColor,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    margin: const EdgeInsets.only(bottom: 8.0),
                  ),
                Container(
                  width: 100.0,
                  height: 10.0,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class BannerPlaceholder extends StatelessWidget {
  const BannerPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200.0,
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: _skeletonBlockColor(context),
      ),
    );
  }
}

class TencentCloudChatListShimmer extends StatelessWidget {
  const TencentCloudChatListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    var list = List<Widget>.generate(
      10,
      (index) => const Column(
        children: [
          ContentPlaceholder(
            lineType: ContentLineType.twoLines,
          ),
          SizedBox(
            height: 16.0,
          )
        ],
      ),
    );
    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        // Subtle base/highlight pair so the sweep reads as a gentle shimmer on
        // both surfaces rather than a high-contrast flash.
        final baseColor =
            isDark ? const Color(0xFF262829) : const Color(0xFFEFF0F2);
        final highlightColor =
            isDark ? const Color(0xFF34373B) : const Color(0xFFF7F8FA);
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          enabled: true,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: list,
            ),
          ),
        );
      },
    );
  }
}
