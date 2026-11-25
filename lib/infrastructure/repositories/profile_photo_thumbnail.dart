import 'dart:developer' show Timeline;
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const _maxThumbnailSide = 384;
const _maxDecodePixels = 4 * 1024 * 1024;

// Santiago Casasbuenas: Decode, crop, resize, and encode in a pure Dart worker.
Uint8List? createProfilePhotoThumbnail(
  ({Uint8List bytes, bool jpeg}) input,
) => Timeline.timeSync('Prepare profile avatar', () {
  final image.Image? source;
  try {
    final decoder = input.jpeg
        ? image.JpegDecoder(maxPixels: _maxDecodePixels)
        : image.PngDecoder(maxPixels: _maxDecodePixels);
    source = decoder.decode(input.bytes, frame: 0);
  } on image.ImageException {
    throw const FormatException(
      'Could not read this JPEG or PNG. Choose a smaller or different image.',
    );
  }
  if (source == null) {
    throw const FormatException('Could not read this JPEG or PNG.');
  }
  if (max(source.width, source.height) <= _maxThumbnailSide) return null;

  // Match the center crop of the circular avatar without enlarging small photos.
  final thumbnail = image.copyResizeCropSquare(
    source,
    size: min(_maxThumbnailSide, min(source.width, source.height)),
    interpolation: image.Interpolation.linear,
  );
  return input.jpeg
      ? image.encodeJpg(thumbnail, quality: 85)
      : image.encodePng(thumbnail);
});
