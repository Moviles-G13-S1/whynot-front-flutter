import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Santiago Casasbuenas: Sprint 4 micro-optimization.
///
/// Decodes [image] just large enough to fill a [size] x [size] box with
/// [BoxFit.cover]: the shorter side becomes [size] pixels and the aspect ratio
/// is kept. `ResizeImage`/`memCacheWidth` can only fix one side, which leaves
/// landscape photos blurry (or portrait ones too large) under `cover`.
/// Images already smaller than the box are decoded as they are.
class CoverResizeImage extends ImageProvider<CoverResizeKey> {
  const CoverResizeImage(this.image, {required this.size}) : assert(size > 0);

  final ImageProvider<Object> image;

  /// Physical pixels of the box's side.
  final int size;

  @override
  Future<CoverResizeKey> obtainKey(ImageConfiguration configuration) async =>
      CoverResizeKey(await image.obtainKey(configuration), size);

  @override
  ImageStreamCompleter loadImage(
    CoverResizeKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeCover(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) => decode(
      buffer,
      getTargetSize: (width, height) {
        final target = coverDecodeSize(width, height, size);
        return ui.TargetImageSize(width: target.width, height: target.height);
      },
    );
    return image.loadImage(key.imageKey, decodeCover);
  }
}

/// The decode size that covers a [box] x [box] square, keeping the ratio.
({int width, int height}) coverDecodeSize(int width, int height, int box) {
  final shortest = math.min(width, height);
  if (shortest <= box) return (width: width, height: height);
  final scale = box / shortest;
  return (
    width: math.max(box, (width * scale).round()),
    height: math.max(box, (height * scale).round()),
  );
}

@immutable
class CoverResizeKey {
  const CoverResizeKey(this.imageKey, this.size);

  final Object imageKey;
  final int size;

  @override
  bool operator ==(Object other) =>
      other is CoverResizeKey &&
      other.imageKey == imageKey &&
      other.size == size;

  @override
  int get hashCode => Object.hash(imageKey, size);
}
