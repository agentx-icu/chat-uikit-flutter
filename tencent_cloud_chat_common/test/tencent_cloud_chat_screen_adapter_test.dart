import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/cross_platforms_adapter/tencent_cloud_chat_screen_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TencentCloudChatScreenAdapter.deviceScreenType = null;
    TencentCloudChatScreenAdapter.hasInitialized = false;
  });

  tearDown(() {
    TencentCloudChatScreenAdapter.deviceScreenType = null;
    TencentCloudChatScreenAdapter.hasInitialized = false;
  });

  testWidgets(
    'screen classification and builder follow MediaQuery size changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const _TestApp());

      expect(
        TencentCloudChatScreenAdapter.deviceScreenType,
        DeviceScreenType.desktop,
      );
      expect(find.text('desktop'), findsOneWidget);

      tester.view.physicalSize = const Size(500, 900);
      await tester.pump();

      expect(
        TencentCloudChatScreenAdapter.deviceScreenType,
        DeviceScreenType.mobile,
      );
      expect(find.text('mobile'), findsOneWidget);

      tester.view.physicalSize = const Size(1024, 700);
      await tester.pump();

      expect(
        TencentCloudChatScreenAdapter.deviceScreenType,
        DeviceScreenType.desktop,
      );
      expect(find.text('desktop'), findsOneWidget);
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: _DispatchProbe());
  }
}

class _DispatchProbe extends StatefulWidget {
  const _DispatchProbe();

  @override
  State<_DispatchProbe> createState() => _DispatchProbeState();
}

class _DispatchProbeState extends TencentCloudChatState<_DispatchProbe> {
  @override
  Widget defaultBuilder(BuildContext context) => const Text('default');

  @override
  Widget mobileBuilder(BuildContext context) => const Text('mobile');

  @override
  Widget desktopBuilder(BuildContext context) => const Text('desktop');
}
