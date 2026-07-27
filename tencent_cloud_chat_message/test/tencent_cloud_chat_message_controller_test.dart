// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_common/models/tencent_cloud_chat_callbacks.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_controller.dart';
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TencentCloudChatSdkPlatform previousPlatform;

  setUp(() {
    previousPlatform = TencentCloudChatSdkPlatform.instance;
  });

  tearDown(() {
    TencentCloudChatSdkPlatform.instance = previousPlatform;
  });

  test('setDraft absorbs an unimplemented routed platform preview', () async {
    TencentCloudChatSdkPlatform.instance = _UnimplementedDraftPlatform();
    final failures = <({String apiName, int code, String description})>[];
    final probe = TencentCloudChatCallbacks(
      onTencentCloudChatSDKFailedCallback: (apiName, code, description) {
        failures.add((
          apiName: apiName,
          code: code,
          description: description,
        ));
      },
    );
    TencentCloudChat.instance.callbacks.addCallback(probe);
    addTearDown(
      () => TencentCloudChat.instance.callbacks.removeCallback(probe),
    );

    await TencentCloudChatMessageControllerGenerator.getInstance().setDraft(
      'group_test',
      'preview',
    );

    expect(failures, hasLength(1));
    expect(failures.single.apiName, 'setConversationDraft');
    expect(failures.single.code, -1);
    expect(failures.single.description, contains('UnimplementedError'));
  });

  test('setDraft reports and absorbs a failed SDK callback', () async {
    TencentCloudChatSdkPlatform.instance = _FailedDraftPlatform();
    final failures = <({String apiName, int code, String description})>[];
    final probe = TencentCloudChatCallbacks(
      onTencentCloudChatSDKFailedCallback: (apiName, code, description) {
        failures.add((
          apiName: apiName,
          code: code,
          description: description,
        ));
      },
    );
    TencentCloudChat.instance.callbacks.addCallback(probe);
    addTearDown(
      () => TencentCloudChat.instance.callbacks.removeCallback(probe),
    );

    await TencentCloudChatMessageControllerGenerator.getInstance().setDraft(
      'c2c_test',
      'preview',
    );

    expect(failures, [
      (
        apiName: 'setConversationDraft',
        code: 701,
        description: 'preview rejected',
      ),
    ]);
  });
}

class _UnimplementedDraftPlatform extends TencentCloudChatSdkPlatform {
  @override
  bool get isCustomPlatform => true;
}

class _FailedDraftPlatform extends TencentCloudChatSdkPlatform {
  @override
  bool get isCustomPlatform => true;

  @override
  Future<V2TimCallback> setConversationDraft({
    required String conversationID,
    String? draftText,
  }) async {
    return V2TimCallback(code: 701, desc: 'preview rejected');
  }
}
