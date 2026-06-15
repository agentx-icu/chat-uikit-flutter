import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';

class TencentCloudChatSearchInput extends StatefulWidget{
  final TextEditingController textEditingController;
  const TencentCloudChatSearchInput({super.key, required this.textEditingController});

  @override
  State<TencentCloudChatSearchInput> createState() => _TencentCloudChatSearchInputState();
}

class _TencentCloudChatSearchInputState extends TencentCloudChatState<TencentCloudChatSearchInput> {
  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) => TextField(
        maxLines: 1,
        controller: widget.textEditingController,
        style: TextStyle(fontSize: 14, color: colorTheme.primaryTextColor),
        cursorColor: colorTheme.primaryColor,
        decoration: InputDecoration(
          hintText: tL10n.search,
          filled: true,
          isDense: true,
          fillColor: colorTheme.contactSearchBackgroundColor,
          hintStyle: TextStyle(fontSize: 14, color: colorTheme.secondaryTextColor),
          prefixIcon: Icon(Icons.search, size: 20, color: colorTheme.secondaryTextColor),
          suffixIcon: widget.textEditingController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18, color: colorTheme.secondaryTextColor),
                  onPressed: () {
                    setState(() {
                      widget.textEditingController.clear();
                    });
                  },
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colorTheme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colorTheme.primaryColor),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colorTheme.dividerColor),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }
}
