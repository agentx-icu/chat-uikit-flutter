import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How [TencentCloudChatBoundedImage] fits the decoded raster to its box.
enum TencentCloudChatBoundedImageMode {
  /// Smallest raster whose BOTH sides still cover `width × height` (for
  /// `BoxFit.cover`, e.g. avatars). Keeps the aspect ratio — unlike
  /// `ResizeImage`'s exact policy, which squashes a non-square image.
  cover,

  /// Largest raster that fits inside `width × height` (for a viewer showing
  /// the whole image). With only one side given, that side is the bound.
  fit,
}

/// Decode-size bound for local media (checklist M6: large images must not be
/// decoded at full resolution on a low-memory phone).
///
/// Flutter decodes a `FileImage` at the file's full resolution unless a
/// `ResizeImage` bounds it — a 12 MP photo is ~48 MB of RGBA, a 48 MP one
/// ~190 MB, and images on screen are not limited by the `ImageCache` budget.
/// Received images and peer avatars are untrusted in size.
///
/// This provider scales the decode (never up) to what the box needs, and then
/// applies a hard ceiling of [maxPixels] (4 bytes each) whatever the aspect
/// ratio, so a 500×16 000 strip or a 1×1 000 000 line cannot blow the budget.
/// When the ceiling wins, the raster is smaller than the box and `BoxFit`
/// upscales it (soft, never distorted — except that a side is never below
/// 1 px).
///
/// Cache identity: the resolved key carries the inner provider's key, every
/// sizing parameter, and — for a [FileImage] — the file's length and
/// modification time, so a file rewritten at the same path is a new cache
/// entry and a re-resolution (new widget key / new provider) can never be
/// served a stale decode. A failed decode evicts its key (as `ResizeImage`
/// does), so a half-written file can be retried.
@immutable
class TencentCloudChatBoundedImage
    extends ImageProvider<TencentCloudChatBoundedImageKey> {
  const TencentCloudChatBoundedImage(
    this.imageProvider, {
    this.width,
    this.height,
    this.mode = TencentCloudChatBoundedImageMode.cover,
    required this.maxPixels,
  }) : assert(width == null || width > 0),
       assert(height == null || height > 0),
       assert(maxPixels > 0);

  /// A bounded provider for a local file, sized for a box of
  /// [logicalWidth] × [logicalHeight] logical px at [devicePixelRatio].
  factory TencentCloudChatBoundedImage.file(
    String path, {
    double? logicalWidth,
    double? logicalHeight,
    required double devicePixelRatio,
    TencentCloudChatBoundedImageMode mode =
        TencentCloudChatBoundedImageMode.cover,
    int? maxPixels,
  }) {
    int? px(double? v) => v == null || !v.isFinite || v <= 0
        ? null
        : math.max(1, (v * devicePixelRatio).ceil());
    final w = px(logicalWidth);
    final h = px(logicalHeight);
    return TencentCloudChatBoundedImage(
      FileImage(File(path)),
      width: w,
      height: h,
      mode: mode,
      maxPixels: maxPixels ?? defaultMaxPixelsFor(w, h),
    );
  }

  /// Default ceiling for a box: 4× its area (room for the cover crop of a
  /// non-square image), at least 64 K px, at most 4 MP.
  static int defaultMaxPixelsFor(int? width, int? height) {
    final area = (width ?? height ?? 256) * (height ?? width ?? 256);
    return math.min(4 * 1024 * 1024, math.max(64 * 1024, 4 * area));
  }

  final ImageProvider<Object> imageProvider;
  final int? width;
  final int? height;
  final TencentCloudChatBoundedImageMode mode;
  final int maxPixels;

  /// The decode size for an image of [intrinsicWidth] × [intrinsicHeight]
  /// under these bounds. Pure; exposed for tests.
  static ui.TargetImageSize targetSize({
    required int intrinsicWidth,
    required int intrinsicHeight,
    int? width,
    int? height,
    TencentCloudChatBoundedImageMode mode =
        TencentCloudChatBoundedImageMode.cover,
    required int maxPixels,
  }) {
    final iw = intrinsicWidth;
    final ih = intrinsicHeight;
    if (iw <= 0 || ih <= 0) return const ui.TargetImageSize();
    double s;
    if (width != null && height != null) {
      final sx = width / iw;
      final sy = height / ih;
      s = mode == TencentCloudChatBoundedImageMode.cover
          ? math.max(sx, sy)
          : math.min(sx, sy);
    } else if (width != null) {
      s = width / iw;
    } else if (height != null) {
      s = height / ih;
    } else {
      s = 1;
    }
    s = math.min(s, 1); // never upscale
    if (iw * s * ih * s > maxPixels) {
      s = math.sqrt(maxPixels / (iw * ih));
    }
    var tw = math.max(1, (iw * s).floor());
    var th = math.max(1, (ih * s).floor());
    if (tw * th > maxPixels) {
      // Only reachable when a side was clamped up to 1 px: shrink the longer
      // side so the ceiling always holds (the aspect ratio cannot).
      if (tw >= th) {
        tw = math.max(1, maxPixels ~/ th);
      } else {
        th = math.max(1, maxPixels ~/ tw);
      }
    }
    if (tw == iw && th == ih) return const ui.TargetImageSize();
    return ui.TargetImageSize(width: tw, height: th);
  }

  @override
  Future<TencentCloudChatBoundedImageKey> obtainKey(
    ImageConfiguration configuration,
  ) {
    // Synchronous whenever the inner key is (FileImage's is), exactly like
    // ResizeImage: an async key would make every re-resolution — e.g. a list
    // row recycled while scrolling — paint one empty frame even on a cache hit.
    // The file stamp is therefore read with a (cheap) synchronous stat.
    TencentCloudChatBoundedImageKey wrap(Object innerKey) {
      int? length;
      int? modifiedMs;
      final inner = imageProvider;
      if (inner is FileImage) {
        try {
          final stat = inner.file.statSync();
          if (stat.type != FileSystemEntityType.notFound) {
            length = stat.size;
            modifiedMs = stat.modified.millisecondsSinceEpoch;
          }
        } catch (_) {
          // Unreadable: the decode will fail and evict itself.
        }
      }
      return TencentCloudChatBoundedImageKey._(
        innerKey,
        width,
        height,
        mode,
        maxPixels,
        length,
        modifiedMs,
      );
    }

    Completer<TencentCloudChatBoundedImageKey>? completer;
    SynchronousFuture<TencentCloudChatBoundedImageKey>? result;
    imageProvider.obtainKey(configuration).then((Object innerKey) {
      final pending = completer;
      if (pending == null) {
        result = SynchronousFuture<TencentCloudChatBoundedImageKey>(
          wrap(innerKey),
        );
      } else {
        pending.complete(wrap(innerKey));
      }
    }, onError: (Object e, StackTrace st) {
      (completer ??= Completer<TencentCloudChatBoundedImageKey>())
          .completeError(e, st);
    });
    final sync = result;
    if (sync != null) return sync;
    return (completer ??= Completer<TencentCloudChatBoundedImageKey>()).future;
  }

  @override
  ImageStreamCompleter loadImage(
    TencentCloudChatBoundedImageKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeBounded(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      assert(
        getTargetSize == null,
        'TencentCloudChatBoundedImage cannot wrap a provider that applies '
        'getTargetSize itself.',
      );
      return decode(
        buffer,
        getTargetSize: (int intrinsicWidth, int intrinsicHeight) => targetSize(
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
          width: width,
          height: height,
          mode: mode,
          maxPixels: maxPixels,
        ),
      );
    }

    // ignore: invalid_use_of_protected_member
    final completer = imageProvider.loadImage(key._innerKey, decodeBounded);
    // Same as ResizeImage: a failed decode must not stay cached under the
    // wrapper key, or a half-written / missing file could never recover.
    completer.addEphemeralErrorListener((Object _, StackTrace? __) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    return completer;
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is TencentCloudChatBoundedImage &&
        other.imageProvider == imageProvider &&
        other.width == width &&
        other.height == height &&
        other.mode == mode &&
        other.maxPixels == maxPixels;
  }

  @override
  int get hashCode =>
      Object.hash(imageProvider, width, height, mode, maxPixels);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'TencentCloudChatBoundedImage')}'
      '($imageProvider, ${width}x$height, ${mode.name}, max $maxPixels px)';
}

/// Cache key of [TencentCloudChatBoundedImage]; see its class doc.
@immutable
class TencentCloudChatBoundedImageKey {
  const TencentCloudChatBoundedImageKey._(
    this._innerKey,
    this._width,
    this._height,
    this._mode,
    this._maxPixels,
    this._length,
    this._modifiedMs,
  );

  final Object _innerKey;
  final int? _width;
  final int? _height;
  final TencentCloudChatBoundedImageMode _mode;
  final int _maxPixels;
  final int? _length;
  final int? _modifiedMs;

  @override
  bool operator ==(Object other) =>
      other is TencentCloudChatBoundedImageKey &&
      other._innerKey == _innerKey &&
      other._width == _width &&
      other._height == _height &&
      other._mode == _mode &&
      other._maxPixels == _maxPixels &&
      other._length == _length &&
      other._modifiedMs == _modifiedMs;

  @override
  int get hashCode => Object.hash(
    _innerKey,
    _width,
    _height,
    _mode,
    _maxPixels,
    _length,
    _modifiedMs,
  );
}
