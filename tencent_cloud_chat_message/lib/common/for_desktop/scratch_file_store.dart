import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:tencent_cloud_chat_common/external/chat_message_provider.dart';

class TencentCloudChatScratchFileStore implements ChatScratchFileProvider {
  TencentCloudChatScratchFileStore({
    Directory? ownedRoot,
    this.ttl = const Duration(days: 1),
    DateTime Function()? clock,
    FutureOr<void> Function(File stagingFile, File finalFile)? beforeCommit,
  })  : ownedRoot = ownedRoot ?? defaultOwnedRoot,
        _clock = clock ?? DateTime.now,
        _beforeCommit = beforeCommit;

  static Directory get defaultOwnedRoot => Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}toxee_uikit_scratch',
      );

  static final TencentCloudChatScratchFileStore shared =
      TencentCloudChatScratchFileStore();

  final Directory ownedRoot;
  final Duration ttl;
  final DateTime Function() _clock;
  final FutureOr<void> Function(File stagingFile, File finalFile)?
      _beforeCommit;

  @override
  Future<String> writeScratchBytes({
    required String category,
    required String suggestedFileName,
    required Uint8List bytes,
  }) async {
    final safeCategory = _sanitizeSegment(category, 'category');
    final safeFileName =
        _sanitizeSegment(suggestedFileName, 'suggestedFileName');
    await _cleanupExpiredBestEffort();

    final resolvedRoot = await _prepareOwnedRoot();
    final categoryDirectory = Directory(
      '${ownedRoot.path}${Platform.pathSeparator}$safeCategory',
    );
    final existingCategoryType = await FileSystemEntity.type(
      categoryDirectory.path,
      followLinks: false,
    );
    if (existingCategoryType == FileSystemEntityType.link) {
      throw FileSystemException(
        'Scratch category must not be a link',
        categoryDirectory.path,
      );
    }
    await categoryDirectory.create(recursive: true);
    final resolvedCategory = await categoryDirectory.resolveSymbolicLinks();
    if (!_isWithinRoot(resolvedCategory, resolvedRoot)) {
      throw FileSystemException(
        'Scratch category resolved outside the owned root',
        categoryDirectory.path,
      );
    }
    final file = await _availableFile(categoryDirectory, safeFileName);
    await _writeAtomically(file, bytes);
    return file.path;
  }

  @override
  Future<void> deleteScratchFile(String path) async {
    if (!await ownedRoot.exists()) {
      return;
    }
    await _validateOwnedRoot();
    final normalizedRoot = _normalizedAbsolutePath(ownedRoot.path);
    final normalizedCandidate = _normalizedAbsolutePath(path);
    if (!_isWithinRoot(normalizedCandidate, normalizedRoot)) {
      throw ArgumentError.value(
          path, 'path', 'Must be inside the scratch root');
    }

    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return;
    }
    if (type != FileSystemEntityType.file) {
      throw ArgumentError.value(path, 'path', 'Must identify a scratch file');
    }

    final resolvedRoot = await ownedRoot.resolveSymbolicLinks();
    final resolvedCandidate = await File(path).resolveSymbolicLinks();
    if (!_isWithinRoot(resolvedCandidate, resolvedRoot)) {
      throw ArgumentError.value(
          path, 'path', 'Must resolve inside the scratch root');
    }
    await File(path).delete();
  }

  Future<void> cleanupExpired() async {
    if (!await ownedRoot.exists()) {
      return;
    }
    await _validateOwnedRoot();
    final resolvedRoot = await ownedRoot.resolveSymbolicLinks();
    final cutoff = _clock().subtract(ttl);
    await for (final entity
        in ownedRoot.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      try {
        final resolvedFile = await entity.resolveSymbolicLinks();
        if (!_isWithinRoot(resolvedFile, resolvedRoot)) {
          continue;
        }
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } on FileSystemException {
        // A concurrent cleanup or writer may have already moved the file.
      }
    }
  }

  Future<void> _cleanupExpiredBestEffort() async {
    try {
      await cleanupExpired();
    } on FileSystemException {
      // Scratch cleanup must not prevent a new clipboard paste.
    }
  }

  Future<File> _availableFile(
    Directory categoryDirectory,
    String suggestedFileName,
  ) async {
    var candidate = File(
      '${categoryDirectory.path}${Platform.pathSeparator}$suggestedFileName',
    );
    if (await FileSystemEntity.type(candidate.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return candidate;
    }

    final dotIndex = suggestedFileName.lastIndexOf('.');
    final hasExtension = dotIndex > 0;
    final stem = hasExtension
        ? suggestedFileName.substring(0, dotIndex)
        : suggestedFileName;
    final extension = hasExtension ? suggestedFileName.substring(dotIndex) : '';
    var suffix = _clock().microsecondsSinceEpoch;
    do {
      candidate = File(
        '${categoryDirectory.path}${Platform.pathSeparator}${stem}_$suffix$extension',
      );
      suffix++;
    } while (await FileSystemEntity.type(candidate.path, followLinks: false) !=
        FileSystemEntityType.notFound);
    return candidate;
  }

  Future<void> _writeAtomically(File finalFile, Uint8List bytes) async {
    File? stagingFile;
    RandomAccessFile? stagingHandle;
    try {
      stagingFile = await _createExclusiveStagingFile(finalFile);
      stagingHandle = await stagingFile.open(mode: FileMode.writeOnly);
      await stagingHandle.writeFrom(bytes);
      await stagingHandle.flush();
      await stagingHandle.close();
      stagingHandle = null;
      await _beforeCommit?.call(stagingFile, finalFile);
      await stagingFile.rename(finalFile.path);
    } catch (_) {
      if (stagingHandle != null) {
        try {
          await stagingHandle.close();
        } catch (_) {
          // Preserve the original write failure.
        }
      }
      if (stagingFile != null) {
        try {
          final type = await FileSystemEntity.type(
            stagingFile.path,
            followLinks: false,
          );
          if (type != FileSystemEntityType.notFound) {
            await stagingFile.delete();
          }
        } catch (_) {
          // Preserve the original write failure.
        }
      }
      rethrow;
    }
  }

  Future<File> _createExclusiveStagingFile(File finalFile) async {
    var suffix = _clock().microsecondsSinceEpoch;
    for (var attempt = 0; attempt < 100; attempt++, suffix++) {
      final stagingFile = File('${finalFile.path}.staging-$suffix');
      try {
        await stagingFile.create(exclusive: true);
        return stagingFile;
      } on FileSystemException {
        final type = await FileSystemEntity.type(
          stagingFile.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) {
          rethrow;
        }
      }
    }
    throw FileSystemException(
      'Unable to reserve an exclusive scratch staging file',
      finalFile.path,
    );
  }

  Future<String> _prepareOwnedRoot() async {
    await ownedRoot.create(recursive: true);
    await _validateOwnedRoot();
    return ownedRoot.resolveSymbolicLinks();
  }

  Future<void> _validateOwnedRoot() async {
    final type = await FileSystemEntity.type(
      ownedRoot.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Scratch root must be an owned directory',
        ownedRoot.path,
      );
    }
  }

  static String _sanitizeSegment(String value, String argumentName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        trimmed.contains('/') ||
        trimmed.contains('\\') ||
        trimmed.contains('\u0000')) {
      throw ArgumentError.value(
          value, argumentName, 'Must be one path segment');
    }
    final sanitized = trimmed.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      throw ArgumentError.value(value, argumentName, 'Has no safe characters');
    }
    return sanitized;
  }

  static String _normalizedAbsolutePath(String path) {
    return File(path).absolute.uri.normalizePath().toFilePath();
  }

  static bool _isWithinRoot(String path, String root) {
    final comparablePath = Platform.isWindows ? path.toLowerCase() : path;
    final comparableRoot = Platform.isWindows ? root.toLowerCase() : root;
    return comparablePath == comparableRoot ||
        comparablePath.startsWith(
          '$comparableRoot${Platform.pathSeparator}',
        );
  }
}

ChatScratchFileProvider resolveChatScratchFileProvider({
  ChatScratchFileProvider? fallbackProvider,
}) {
  final provider = ChatMessageProviderRegistry.provider;
  if (provider is ChatScratchFileProvider) {
    return provider as ChatScratchFileProvider;
  }
  return fallbackProvider ?? TencentCloudChatScratchFileStore.shared;
}
