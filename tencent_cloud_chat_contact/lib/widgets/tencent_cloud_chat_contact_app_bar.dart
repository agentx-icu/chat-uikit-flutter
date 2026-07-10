import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';
import 'package:tencent_cloud_chat_contact/widgets/tencent_cloud_chat_contact_add_contacts.dart';
import 'package:tencent_cloud_chat_contact/widgets/tencent_cloud_chat_contact_add_group.dart';

enum AddContact { addFriend, addGroup }

class TencentCloudChatContactAppBar extends StatefulWidget {
  final String? title;

  const TencentCloudChatContactAppBar({super.key, this.title});

  @override
  State<StatefulWidget> createState() => TencentCloudChatContactAppBarState();
}

class TencentCloudChatContactAppBarState
    extends TencentCloudChatState<TencentCloudChatContactAppBar> {
  @override
  Widget tabletAppBuilder(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: desktopBuilder(context),
    );
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return Column(
      children: [
        TencentCloudChat.instance.dataInstance.contact.contactBuilder
            ?.getContactAppBarNameBuilder(),
        const SizedBox(height: 12),
        const TencentCloudChatAppBarSearchItem()
      ],
    );
  }

  @override
  Widget desktopBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) => Container(
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
            width: 1,
            color: colorTheme.dividerColor,
          )),
        ),
        padding: EdgeInsets.symmetric(
          vertical: getHeight(11.4),
          horizontal: getWidth(16),
        ),
        child: Column(
          children: [
            TencentCloudChat.instance.dataInstance.contact.contactBuilder
                ?.getContactAppBarNameBuilder(
              title: widget.title,
            ),
            const SizedBox(height: 12),
            const TencentCloudChatAppBarSearchItem()
          ],
        ),
      ),
    );
  }
}

class TencentCloudChatContactAppBarName extends StatefulWidget {
  final String? title;

  const TencentCloudChatContactAppBarName({super.key, this.title});

  /// Host-injected trailing "new entry" affordance. When set, it REPLACES the
  /// built-in `maps_ugc` MenuAnchor whose "Add Contact" / "Add Group" items open
  /// the search-by-userID panel (Tencent-IM oriented; the picker is empty on
  /// Tox). toxee injects its own `NewEntryButton` (Add Contact by Tox ID /
  /// Create Group / Join IRC) here so this default name widget — the FALLBACK
  /// used whenever the `contactAppBarNameBuilder` override is momentarily unset
  /// (early startup / a destructive `setBuilders`) — matches the Chats-tab "+"
  /// instead of surfacing the native panel. Mirrors
  /// [TencentCloudChatConversationAppBarName.trailingBuilder].
  static Widget Function(BuildContext context)? trailingBuilder;

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatContactAppBarNameState();
}

class TencentCloudChatContactAppBarNameState
    extends TencentCloudChatState<TencentCloudChatContactAppBarName> {
  AddContact? selectedMenu;

  // Present an add-panel (contact / group). On wide viewports (tablet /
  // desktop — the iPad "desktop layout" tier) show it as a centered dialog so
  // it doesn't render as a near-fullscreen bottom sheet with a large empty
  // dark background; on phones keep the familiar bottom sheet. The panel widget
  // itself (AddContacts/AddGroup) sizes to a bounded height on wide screens.
  void _presentAddPanel(Widget child) {
    final wide = MediaQuery.of(context).size.width >= 720;
    if (wide) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24),
          child: child,
        ),
      );
    } else {
      showModalBottomSheet<void>(
          // A visible scrim so the sheet reads as a distinct surface over the
          // contacts page (the old fully-transparent barrier made the sheet look
          // like it was floating on / blending into the page on iOS dark mode).
          barrierColor: Colors.black.withValues(alpha: 0.4),
          backgroundColor: Colors.transparent,
          context: context,
          isScrollControlled: true,
          builder: (context) => child);
    }
  }

  addContacts() {
    _presentAddPanel(const TencentCloudChatContactAddContacts());
  }

  addGroup() {
    _presentAddPanel(const TencentCloudChatContactAddGroup());
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) => Row(
        children: [
          Expanded(
              child: Text(widget.title ?? tL10n.contacts,
                  style: TextStyle(
                      color: colorTheme.contactItemFriendNameColor,
                      fontSize: textStyle.fontsize_34,
                      fontWeight: FontWeight.w600))),
          if (TencentCloudChatContactAppBarName.trailingBuilder != null)
            TencentCloudChatContactAppBarName.trailingBuilder!(context)
          else
            MenuAnchor(
            builder: (BuildContext context, MenuController controller,
                Widget? child) {
              return IconButton(
                key: const ValueKey('contact_app_bar_menu_button'),
                icon: Icon(Icons.maps_ugc_outlined,
                    size: getSquareSize(20),
                    color: colorTheme.contactAppBarIconColor),
                onPressed: () {
                  // toxee fallback path: if the custom trailing NewEntryButton
                  // is missing after a builder reset, this default UIKit icon
                  // becomes the only visible "new contact" affordance. Opening
                  // the Tox-aware Add Contact dialog directly is more stable
                  // than relying on MenuAnchor state here.
                  addContacts();
                },
                tooltip: 'Add Contact',
              );
            },
            menuChildren: [
              MenuItemButton(
                key: const ValueKey('contact_app_bar_add_contact_item'),
                onPressed: addContacts,
                child: Text(tL10n.addContact),
              ),
              MenuItemButton(
                key: const ValueKey('contact_app_bar_add_group_item'),
                onPressed: addGroup,
                child: Text(tL10n.addGroup),
              )
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget desktopBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) => Row(
        children: [
          Expanded(
              child: Text(
            widget.title ?? tL10n.contacts,
            style: TextStyle(
                color: colorTheme.contactItemFriendNameColor,
                fontSize: textStyle.fontsize_24 + 4,
                fontWeight: FontWeight.w600),
          )),
          if (TencentCloudChatContactAppBarName.trailingBuilder != null)
            TencentCloudChatContactAppBarName.trailingBuilder!(context)
          else
            MenuAnchor(
            builder: (BuildContext context, MenuController controller,
                Widget? child) {
              return IconButton(
                key: const ValueKey('contact_app_bar_menu_button'),
                icon: Icon(Icons.maps_ugc_outlined,
                    size: getSquareSize(20),
                    color: colorTheme.contactAppBarIconColor),
                onPressed: () {
                  addContacts();
                },
                tooltip: 'Add Contact',
              );
            },
            menuChildren: [
              MenuItemButton(
                key: const ValueKey('contact_app_bar_add_contact_item'),
                onPressed: addContacts,
                child: Text(tL10n.addContact),
              ),
              MenuItemButton(
                key: const ValueKey('contact_app_bar_add_group_item'),
                onPressed: addGroup,
                child: Text(tL10n.addGroup),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class TencentCloudChatAppBarSearchItem extends StatefulWidget {
  const TencentCloudChatAppBarSearchItem({super.key});

  @override
  State<StatefulWidget> createState() =>
      TencentCloudChatAppBarSearchItemState();
}

class TencentCloudChatAppBarSearchItemState
    extends TencentCloudChatState<TencentCloudChatAppBarSearchItem> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onChanged);
  }

  void _onChanged() {
    // Drive the AZ-list filter via the shared query notifier, and rebuild so the
    // clear-button suffix appears/disappears.
    TencentCloudChat.instance.dataInstance.contact.contactSearchQuery.value =
        _searchController.text;
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onChanged);
    _searchController.dispose();
    _focusNode.dispose();
    // Reset the filter so the contact list isn't left filtered after the bar is gone.
    TencentCloudChat.instance.dataInstance.contact.contactSearchQuery.value =
        '';
    super.dispose();
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TextField(
      key: const ValueKey('contact_search_field'),
      focusNode: _focusNode,
      maxLines: 1,
      controller: _searchController,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: tL10n.search,
        filled: true,
        isDense: true,
        hintStyle: const TextStyle(fontSize: 14),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _focusNode.unfocus();
                },
              )
            : null,
        border: const OutlineInputBorder(borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(0),
      ),
    );
  }
}
