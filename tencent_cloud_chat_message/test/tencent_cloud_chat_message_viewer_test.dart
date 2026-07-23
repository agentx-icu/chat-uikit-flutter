import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_intl/localizations/tencent_cloud_chat_localizations.dart';
import 'package:tencent_cloud_chat_intl/tencent_cloud_chat_intl.dart'
    as chat_intl;
import 'package:tencent_cloud_chat_message/tencent_cloud_chat_message_viewer/tencent_cloud_chat_message_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late File imageFile;
  late File videoFile;

  setUp(() {
    chat_intl.TencentCloudChatIntl(locale: const Locale('en')).setLocale(
      const Locale('en'),
    );
    tempDirectory = Directory.systemTemp.createTempSync('message-viewer-test-');
    imageFile = File('${tempDirectory.path}/image.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
    videoFile = File('${tempDirectory.path}/video.mp4')
      ..writeAsBytesSync(const <int>[0]);
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  testWidgets('local image supports pinch zoom', (tester) async {
    await _pumpViewer(
      tester,
      _imageMessage(imageFile.path),
    );

    final zoomable = find.descendant(
      of: find.byKey(const ValueKey('message_viewer_root')),
      matching: find.byType(InteractiveViewer),
    );
    expect(zoomable, findsOneWidget);

    final interactiveViewer = tester.widget<InteractiveViewer>(zoomable);
    final transformationController = interactiveViewer.transformationController;
    expect(transformationController, isNotNull);

    final center = tester.getCenter(zoomable);
    final firstFinger = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final secondFinger = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump();
    await firstFinger.moveTo(center - const Offset(100, 0));
    await secondFinger.moveTo(center + const Offset(100, 0));
    await tester.pump();

    expect(
      transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );

    await firstFinger.up();
    await secondFinger.up();
  });

  testWidgets('local image exposes a visible save action', (tester) async {
    await _pumpViewer(tester, _imageMessage(imageFile.path));

    expect(
      find.byKey(const ValueKey('message_viewer_save_button')),
      findsOneWidget,
    );
  });

  testWidgets('local video exposes a visible save action', (tester) async {
    await _pumpViewer(tester, _videoMessage(videoFile.path));

    expect(
      find.byKey(const ValueKey('message_viewer_save_button')),
      findsOneWidget,
    );
  });

  testWidgets('remote image exposes a visible save action', (tester) async {
    await _pumpViewer(
        tester, _remoteImageMessage('https://cdn.test/image.png'));

    expect(
      find.byKey(const ValueKey('message_viewer_save_button')),
      findsOneWidget,
    );
  });

  testWidgets('remote video exposes a visible save action', (tester) async {
    await _pumpViewer(
        tester, _remoteVideoMessage('https://cdn.test/video.mp4'));

    expect(
      find.byKey(const ValueKey('message_viewer_save_button')),
      findsOneWidget,
    );
  });

  test('mobile save writes bytes through the platform save dialog', () async {
    var directoryPickerCalled = false;
    String? savedFileName;
    List<int>? savedBytes;
    final saver = MessageViewerMediaSaver(
      pickDirectory: () async {
        directoryPickerCalled = true;
        return tempDirectory.path;
      },
      saveFile: ({required fileName, required bytes}) async {
        savedFileName = fileName;
        savedBytes = bytes;
        return '/mobile/$fileName';
      },
    );

    final result = await saver.save(
      filePath: imageFile.path,
      useMobileSave: true,
    );

    expect(result, MessageViewerMediaSaveResult.saved);
    expect(directoryPickerCalled, isFalse);
    expect(savedFileName, endsWith('_image.png'));
    expect(savedBytes, imageFile.readAsBytesSync());
  });

  test('mobile save cancellation is not treated as failure', () async {
    final saver = MessageViewerMediaSaver(
      saveFile: ({required fileName, required bytes}) async => null,
    );

    final result = await saver.save(
      filePath: imageFile.path,
      useMobileSave: true,
    );

    expect(result, MessageViewerMediaSaveResult.canceled);
  });

  test('mobile remote save fetches bytes before opening save dialog', () async {
    Uri? fetchedUri;
    String? savedFileName;
    List<int>? savedBytes;
    final saver = MessageViewerMediaSaver(
      httpGet: (uri) async {
        fetchedUri = uri;
        return http.Response.bytes(const <int>[1, 2, 3], 200);
      },
      saveFile: ({required fileName, required bytes}) async {
        savedFileName = fileName;
        savedBytes = bytes;
        return '/mobile/$fileName';
      },
    );

    final result = await saver.save(
      filePath: 'https://cdn.test/path/clip.mp4',
      useMobileSave: true,
    );

    expect(result, MessageViewerMediaSaveResult.saved);
    expect(fetchedUri, Uri.parse('https://cdn.test/path/clip.mp4'));
    expect(savedFileName, endsWith('_clip.mp4'));
    expect(savedBytes, const <int>[1, 2, 3]);
  });

  test('desktop save keeps directory copy behavior', () async {
    final saveDirectory = Directory('${tempDirectory.path}/desktop-save')
      ..createSync();
    var saveFileCalled = false;
    final saver = MessageViewerMediaSaver(
      pickDirectory: () async => saveDirectory.path,
      saveFile: ({required fileName, required bytes}) async {
        saveFileCalled = true;
        return '/unexpected/$fileName';
      },
    );

    final result = await saver.save(
      filePath: imageFile.path,
      useMobileSave: false,
    );

    expect(result, MessageViewerMediaSaveResult.saved);
    expect(saveFileCalled, isFalse);
    final savedFiles = saveDirectory.listSync().whereType<File>().toList();
    expect(savedFiles, hasLength(1));
    expect(savedFiles.single.path, endsWith('_image.png'));
    expect(savedFiles.single.readAsBytesSync(), imageFile.readAsBytesSync());
  });
}

V2TimMessage _imageMessage(String path) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_conv_type': ConversationType.V2TIM_C2C,
    'message_conv_id': 'friend',
    'message_sender': 'friend',
    'message_client_time': now,
    'message_server_time': now,
    'message_msg_id': 'image-message',
    'message_risk_type_identified': 0,
    'message_elem_array': <Map<String, dynamic>>[
      V2TimTextElem(text: 'fixture').toJson(),
    ],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
  message.imageElem = V2TimImageElem(path: path);
  return message;
}

V2TimMessage _remoteImageMessage(String url) {
  final message = _imageMessage('');
  message.imageElem = V2TimImageElem(
    imageList: <V2TimImage?>[
      V2TimImage(type: 0, url: url),
    ],
  );
  return message;
}

V2TimMessage _videoMessage(String path) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_conv_type': ConversationType.V2TIM_C2C,
    'message_conv_id': 'friend',
    'message_sender': 'friend',
    'message_client_time': now,
    'message_server_time': now,
    'message_msg_id': 'video-message',
    'message_risk_type_identified': 0,
    'message_elem_array': <Map<String, dynamic>>[
      V2TimTextElem(text: 'fixture').toJson(),
    ],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
  message.videoElem = V2TimVideoElem(
    localVideoUrl: path,
    snapshotWidth: 16,
    snapshotHeight: 9,
  );
  return message;
}

V2TimMessage _remoteVideoMessage(String url) {
  final message = _videoMessage('');
  message.videoElem = V2TimVideoElem(
    videoUrl: url,
    snapshotWidth: 16,
    snapshotHeight: 9,
  );
  return message;
}

Future<void> _pumpViewer(
  WidgetTester tester,
  V2TimMessage message,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates:
          TencentCloudChatLocalizations.localizationsDelegates,
      supportedLocales: TencentCloudChatLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          chat_intl.TencentCloudChatIntl().init(context);
          return TencentCloudChatMessageViewer(
            convKey: 'c2c_friend',
            message: message,
            convType: ConversationType.V2TIM_C2C,
            isSending: true,
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
