import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_common/components/component_config/tencent_cloud_chat_message_config.dart';
import 'package:tencent_cloud_chat_common/components/components_definition/tencent_cloud_chat_component_builder_definitions.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_screen_adapter.dart';
import 'package:tencent_cloud_chat_common/models/tencent_cloud_chat_models.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/widgets/desktop_popup/operation_key.dart';
import 'package:tencent_cloud_chat_common/widgets/desktop_popup/tencent_cloud_chat_desktop_popup.dart';
import 'package:tencent_cloud_chat_message/model/tencent_cloud_chat_message_separate_data.dart';
import 'package:tencent_cloud_chat_message/model/tencent_cloud_chat_message_separate_data_notifier.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_input/forward/tencent_cloud_chat_message_forward_container.dart';

class TencentCloudChatMessageInputSelectModeContainer extends StatefulWidget {
  const TencentCloudChatMessageInputSelectModeContainer({super.key});

  @override
  State<TencentCloudChatMessageInputSelectModeContainer> createState() =>
      _TencentCloudChatMessageInputSelectModeContainerState();
}

class _TencentCloudChatMessageInputSelectModeContainerState
    extends TencentCloudChatState<TencentCloudChatMessageInputSelectModeContainer> {
  TencentCloudChatMessageSeparateDataProvider? _subscribedProvider;

  // toxee: SUBSCRIBE to the provider instead of relying on the InheritedWidget.
  //
  // `TencentCloudChatMessageDataProviderInherited` is a plain InheritedWidget
  // whose `updateShouldNotify` compares the dataProvider INSTANCE — and that
  // instance never changes for the life of a conversation. So
  // `notifyListeners()` did NOT rebuild this container, and the
  // `messages: dataProvider.getSelectedMessages()` handed to the toolbar below
  // was frozen at first build.
  //
  // The live consequence (iPad, 2026-08-16): tapping the header's Clear
  // (`selectedMessages = []`, which assigns a NEW list) left this toolbar still
  // holding the OLD list, so the very next Delete deleted the supposedly
  // deselected message — the toolbar acted on a selection the user had
  // cleared. The header container already subscribes this way
  // (`tencent_cloud_chat_message_header_container.dart`); this brings the
  // bottom half of the same surface in line. Rebuild-only: no behaviour,
  // layout or callback change beyond reading fresh state.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = TencentCloudChatMessageDataProviderInherited.of(context);
    if (identical(provider, _subscribedProvider)) return;
    _subscribedProvider?.removeListener(_onProviderChanged);
    _subscribedProvider = provider..addListener(_onProviderChanged);
  }

  void _onProviderChanged() => safeSetState(() {});

  @override
  void dispose() {
    _subscribedProvider?.removeListener(_onProviderChanged);
    _subscribedProvider = null;
    super.dispose();
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    final dataProvider = TencentCloudChatMessageDataProviderInherited.of(context);
    final TencentCloudChatMessageConfig config = dataProvider.config;

    final defaultMessageSelectionOperationsConfig = dataProvider.config.defaultMessageSelectionOperationsConfig(
      userID: dataProvider.userID,
      topicID: dataProvider.topicID,
      groupID: dataProvider.groupID,
    );

    return TencentCloudChatMessageDataProviderInherited.of(context).messageBuilders?.getMessageInputSelectBuilder(
              data: MessageInputSelectBuilderData(
                enableMessageForwardIndividually:
                    defaultMessageSelectionOperationsConfig.enableMessageForwardIndividually,
                // toxee(P1-13): hidden until protocol design lands.
                // Merge/combined forward requires a Tox-side "merger" elem
                // (V2TIM_ELEM_TYPE_MERGER) representation we have not designed
                // yet; tapping the button would crash or silently fail.
                // Keep the underlying code paths intact so we can re-enable
                // by flipping this flag once the protocol is in place.
                enableMessageForwardCombined: false,
                enableMessageDeleteForSelf: defaultMessageSelectionOperationsConfig.enableMessageDeleteForSelf,
                messages: dataProvider.getSelectedMessages(),
              ),
              methods: MessageInputSelectBuilderMethods(
                onMessagesForward: (TencentCloudChatForwardType type) {
                  final messages = dataProvider.getSelectedMessages();
                  if (!dataProvider.checkMessagesForward(type, messages)) {
                    return;
                  }

                  final isDesktopScreen = TencentCloudChatScreenAdapter.deviceScreenType == DeviceScreenType.desktop;
                  if (isDesktopScreen) {
                    TencentCloudChatDesktopPopup.showPopupWindow(
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: MediaQuery.of(context).size.height * 0.6,
                      operationKey: TencentCloudChatPopupOperationKey.forward,
                      context: context,
                      child: (closeFunc) => TencentCloudChatMessageForwardContainer(
                        onCloseModal: closeFunc,
                        type: type,
                        context: context,
                        messages: messages,
                        messageForwardBuilder: TencentCloudChatMessageDataProviderInherited.of(context)
                            .messageBuilders
                            ?.getMessageForwardBuilder,
                      ),
                    );
                  } else {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (BuildContext _) {
                        return TencentCloudChatMessageForwardContainer(
                          type: type,
                          context: context,
                          messages: messages,
                          messageForwardBuilder: TencentCloudChatMessageDataProviderInherited.of(context)
                              .messageBuilders
                              ?.getMessageForwardBuilder,
                        );
                      },
                    );
                  }
                },
                onDeleteForMe: (messages) {
                  dataProvider.inSelectMode = false;
                  Future.delayed(const Duration(milliseconds: 10), () {
                    dataProvider.deleteMessagesForMe(messages: messages);
                  });
                },
              ),
            ) ??
        Container();
  }
}
