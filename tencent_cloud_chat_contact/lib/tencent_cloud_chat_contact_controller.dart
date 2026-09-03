import 'package:flutter/widgets.dart';
// ItemScrollController comes from the list package AzListView is built on;
// reached through azlistview's own dependency so this package does not add
// a direct one for a single type.
import 'package:scrollable_positioned_list_for_us/scrollable_positioned_list_for_us.dart';
import 'package:tencent_cloud_chat_common/components/components_definition/tencent_cloud_chat_component_base_controller.dart';

class TencentCloudChatContactControllerGenerator {
  static TencentCloudChatContactController getInstance() {
    return TencentCloudChatContactController._();
  }
}

class TencentCloudChatContactController extends TencentCloudChatComponentBaseController {
  TencentCloudChatContactController._();

  /// Scroll controller of the mounted contacts A-Z list.
  ///
  /// Exposed so the host app can implement the platform convention of
  /// re-tapping the active bottom-nav tab to jump back to the top — the same
  /// affordance [TencentCloudChatConversationController] already offers for the
  /// conversation list, so the host can dispatch by tab index without reaching
  /// into widget internals with a GlobalKey.
  ///
  /// It is an [ItemScrollController], not a [ScrollController], because the
  /// contacts list is an `AzListView` (scrollable_positioned_list) and that is
  /// the only controller type it accepts.
  ///
  /// PER-STATE, not a singleton field: `ItemScrollController` is single-attach,
  /// so one shared instance bound by every mounted contacts list asserts in
  /// debug the moment two exist (master-detail, a route pushed over the tab)
  /// and can detach the wrong one in release. Each list registers its OWN
  /// controller while mounted; the newest registration wins, and unregistering
  /// is identity-guarded so a disposing older list cannot revoke it.
  /// A STACK, not one slot: either list can disappear first. A route pushed
  /// over the tab registers on top and, when it pops, the older list
  /// underneath is on screen again and must become the target once more — a
  /// single slot cleared on dispose would orphan it and make scrollToTop
  /// silently dead.
  final List<ItemScrollController> _scrollControllers = [];

  /// Called by a mounted contacts list. [controller] must belong to that
  /// list's State.
  void registerScrollController(ItemScrollController controller) {
    _scrollControllers
      ..removeWhere((c) => identical(c, controller))
      ..add(controller);
    // Bound the stack. Entries are normally removed on dispose, but a State
    // that never runs dispose would otherwise leak one forever. Pruning is
    // deliberately NOT "drop everything unattached": a list registers in
    // initState and only attaches when it first builds, so an eager prune
    // would throw away a list that is about to appear. Only once the stack is
    // implausibly deep do we drop the OLDEST detached entries — by then they
    // cannot be lists a user is looking at.
    const maxTrackedLists = 8;
    while (_scrollControllers.length > maxTrackedLists) {
      final stale = _scrollControllers.indexWhere((c) => !c.isAttached);
      if (stale < 0 || identical(_scrollControllers[stale], controller)) break;
      _scrollControllers.removeAt(stale);
    }
  }

  /// Called when a contacts list disposes. Removes only that list's entry, so
  /// whichever list is still mounted keeps (or regains) the target.
  void unregisterScrollController(ItemScrollController controller) {
    _scrollControllers.removeWhere((c) => identical(c, controller));
  }

  /// Animates the contacts list back to the top. A no-op when no list is
  /// mounted — the bottom-nav can be re-tapped before the tab has ever been
  /// built.
  Future<void> scrollToTop({
    Duration duration = const Duration(milliseconds: 220),
    Curve curve = Curves.easeOut,
  }) async {
    // Walk from the newest and take the first ATTACHED controller: attachment
    // is the ground truth for "this list is really on screen", so a stale entry
    // (a State that never ran dispose) self-heals instead of swallowing the
    // gesture.
    for (final controller in _scrollControllers.reversed) {
      if (!controller.isAttached) continue;
      await controller.scrollTo(
        index: 0,
        duration: duration,
        curve: curve,
      );
      return;
    }
  }
}
