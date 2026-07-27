import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_common/external/chat_message_provider.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_message/common/for_desktop/scratch_file_store.dart';

void main() {
  late Directory sandbox;
  late Directory ownedRoot;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('uikit-scratch-test-');
    ownedRoot = Directory(_join(sandbox.path, 'owned'));
    ChatMessageProviderRegistry.provider = null;
  });

  tearDown(() async {
    ChatMessageProviderRegistry.provider = null;
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('registered scratch provider handles writes', () async {
    final provider = _ScratchMessageProvider();
    ChatMessageProviderRegistry.provider = provider;

    final resolved = resolveChatScratchFileProvider(
      fallbackProvider: TencentCloudChatScratchFileStore(ownedRoot: ownedRoot),
    );
    final path = await resolved.writeScratchBytes(
      category: 'clipboard_images',
      suggestedFileName: 'paste.png',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(identical(resolved, provider), isTrue);
    expect(path, '/provider/paste.png');
    expect(provider.writes.single.category, 'clipboard_images');
    expect(provider.writes.single.bytes, [1, 2, 3]);
    expect(await ownedRoot.exists(), isFalse);
  });

  test('fallback root is dedicated system temp directory', () {
    final store = TencentCloudChatScratchFileStore();
    final expected = Directory(
      _join(Directory.systemTemp.path, 'toxee_uikit_scratch'),
    );

    expect(store.ownedRoot.absolute.path, expected.absolute.path);
  });

  test('resolver fallback atomically commits complete content', () async {
    final bytes = Uint8List.fromList([7, 8, 9]);
    var beforeCommitCalled = false;
    late File stagingFile;
    final fallback = TencentCloudChatScratchFileStore(
      ownedRoot: ownedRoot,
      beforeCommit: (staging, finalFile) async {
        beforeCommitCalled = true;
        stagingFile = staging;
        expect(staging.parent.path, finalFile.parent.path);
        expect(await finalFile.exists(), isFalse);
        expect(await staging.readAsBytes(), bytes);
      },
    );
    final resolved = resolveChatScratchFileProvider(
      fallbackProvider: fallback,
    );

    final path = await resolved.writeScratchBytes(
      category: 'clipboard_images',
      suggestedFileName: 'paste.png',
      bytes: bytes,
    );

    expect(identical(resolved, fallback), isTrue);
    expect(beforeCommitCalled, isTrue);
    expect(path, _join(ownedRoot.path, 'clipboard_images', 'paste.png'));
    expect(await File(path).readAsBytes(), bytes);
    expect(await stagingFile.exists(), isFalse);
  });

  test('injected commit failure leaves no final or staging file', () async {
    final store = TencentCloudChatScratchFileStore(
      ownedRoot: ownedRoot,
      beforeCommit: (stagingFile, finalFile) {
        throw StateError('injected commit failure');
      },
    );
    final finalPath = _join(
      ownedRoot.path,
      'clipboard_images',
      'failed.png',
    );

    await expectLater(
      store.writeScratchBytes(
        category: 'clipboard_images',
        suggestedFileName: 'failed.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
      throwsStateError,
    );

    expect(await File(finalPath).exists(), isFalse);
    final categoryDirectory = Directory(
      _join(ownedRoot.path, 'clipboard_images'),
    );
    final remainingPaths = await categoryDirectory
        .list(followLinks: false)
        .map((entity) => entity.path)
        .toList();
    expect(remainingPaths, isEmpty);
  });

  test('fallback sanitizes basenames and rejects traversal', () async {
    final store = TencentCloudChatScratchFileStore(ownedRoot: ownedRoot);
    final path = await store.writeScratchBytes(
      category: 'clipboard images',
      suggestedFileName: 'pasted image.png',
      bytes: Uint8List.fromList([4, 5, 6]),
    );

    expect(
      path,
      _join(ownedRoot.path, 'clipboard_images', 'pasted_image.png'),
    );
    expect(await File(path).readAsBytes(), [4, 5, 6]);
    await expectLater(
      store.writeScratchBytes(
        category: '../outside',
        suggestedFileName: 'paste.png',
        bytes: Uint8List(0),
      ),
      throwsArgumentError,
    );
    await expectLater(
      store.writeScratchBytes(
        category: 'clipboard_images',
        suggestedFileName: '../outside.png',
        bytes: Uint8List(0),
      ),
      throwsArgumentError,
    );

    final outsideFile = File(_join(sandbox.path, 'outside.txt'))
      ..writeAsStringSync('sentinel');
    await expectLater(
      store.deleteScratchFile(outsideFile.path),
      throwsArgumentError,
    );
    expect(await outsideFile.readAsString(), 'sentinel');
  });

  test('TTL cleanup deletes only expired files inside owned root', () async {
    final now = DateTime.now();
    final store = TencentCloudChatScratchFileStore(
      ownedRoot: ownedRoot,
      ttl: const Duration(hours: 1),
      clock: () => now,
    );
    final expiredPath = await store.writeScratchBytes(
      category: 'clipboard_images',
      suggestedFileName: 'expired.png',
      bytes: Uint8List.fromList([1]),
    );
    final freshPath = await store.writeScratchBytes(
      category: 'clipboard_images',
      suggestedFileName: 'fresh.png',
      bytes: Uint8List.fromList([2]),
    );
    final outsideFile = File(_join(sandbox.path, 'outside-sentinel.txt'))
      ..writeAsStringSync('outside');
    final downloadsDirectory = Directory(_join(sandbox.path, 'Downloads'))
      ..createSync();
    final downloadsSentinel =
        File(_join(downloadsDirectory.path, 'downloads-sentinel.txt'))
          ..writeAsStringSync('downloads');
    final expiredAt = now.subtract(const Duration(hours: 2));
    await File(expiredPath).setLastModified(expiredAt);
    await File(freshPath).setLastModified(now);
    await outsideFile.setLastModified(expiredAt);
    await downloadsSentinel.setLastModified(expiredAt);

    await store.cleanupExpired();

    expect(await File(expiredPath).exists(), isFalse);
    expect(await File(freshPath).exists(), isTrue);
    expect(await outsideFile.readAsString(), 'outside');
    expect(await downloadsSentinel.readAsString(), 'downloads');
  });
}

String _join(String parent, String child, [String? grandchild]) {
  final base = '$parent${Platform.pathSeparator}$child';
  return grandchild == null
      ? base
      : '$base${Platform.pathSeparator}$grandchild';
}

class _ScratchMessageProvider
    implements ChatMessageProvider, ChatScratchFileProvider {
  final List<({String category, String fileName, Uint8List bytes})> writes = [];

  @override
  Future<String> writeScratchBytes({
    required String category,
    required String suggestedFileName,
    required Uint8List bytes,
  }) async {
    writes.add((
      category: category,
      fileName: suggestedFileName,
      bytes: bytes,
    ));
    return '/provider/$suggestedFileName';
  }

  @override
  Future<void> deleteScratchFile(String path) async {}

  @override
  Future<void> deleteMessages({
    String? userID,
    String? groupID,
    required List<String> msgIDs,
  }) async {}

  @override
  Future<void> sendFile({
    String? userID,
    String? groupID,
    required String filePath,
    String? fileName,
  }) async {}

  @override
  Future<void> sendImage({
    String? userID,
    String? groupID,
    required String imagePath,
    String? imageName,
  }) async {}

  @override
  Future<void> sendText({
    String? userID,
    String? groupID,
    required String text,
  }) async {}

  @override
  Stream<List<V2TimMessage>> streamFor({String? userID, String? groupID}) {
    return const Stream<List<V2TimMessage>>.empty();
  }
}
