import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:whynot_mobile/infrastructure/repositories/firebase_profile_photo_repository.dart';
import 'package:whynot_mobile/infrastructure/repositories/profile_photo_thumbnail.dart';

class _Picker extends Fake implements ImagePicker {
  Uint8List? bytes;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    expect((maxWidth, maxHeight, imageQuality), (1024.0, 1024.0, 80));
    return bytes == null ? null : XFile.fromData(bytes!);
  }
}

class _Storage extends Fake implements FirebaseStorage {
  String? path;
  final reference = _Reference();

  @override
  Reference ref([String? path]) {
    this.path = path;
    return reference;
  }
}

class _Reference extends Fake implements Reference {
  Uint8List? bytes;
  String? contentType;

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    bytes = data;
    contentType = metadata?.contentType;
    return _Upload();
  }
}

class _Upload extends Fake implements UploadTask {
  @override
  Future<T> then<T>(
    FutureOr<T> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => Future<TaskSnapshot>.value(_Snapshot()).then(onValue, onError: onError);
}

class _Snapshot extends Fake implements TaskSnapshot {}

({SendPort port, Uint8List? bytes}) _runThumbnailAndIdentifyIsolate(
  Uint8List bytes,
) => (
  port: Isolate.current.controlPort,
  bytes: createProfilePhotoThumbnail((bytes: bytes, jpeg: true)),
);

Uint8List _largeJpeg() {
  final source = image.Image(width: 1024, height: 768);
  for (final pixel in source) {
    if (pixel.x < 128 || pixel.x >= 896) {
      pixel.r = 255;
    } else {
      pixel.g = 255;
    }
  }
  return image.encodeJpg(source, quality: 80);
}

void main() {
  late _Picker picker;
  late _Storage storage;
  late FirebaseProfilePhotoRepository repository;

  setUp(() {
    picker = _Picker();
    storage = _Storage();
    repository = FirebaseProfilePhotoRepository(
      picker: picker,
      storage: storage,
    );
  });

  test(
    'creates a centered JPEG avatar and uploads the full picker bytes',
    () async {
      final original = picker.bytes = _largeJpeg();
      final photo = (await repository.pick())!;
      expect(photo.bytes, orderedEquals(original));
      expect(photo.contentType, 'image/jpeg');
      expect(photo.extension, 'jpg');
      if (kIsWeb) {
        expect(photo.thumbnailBytes, isNull);
        expect(photo.avatarBytes, same(photo.bytes));
      } else {
        final avatar = image.decodeJpg(photo.avatarBytes)!;
        expect((avatar.width, avatar.height), (384, 384));
        expect(avatar.getPixel(0, 192).g, greaterThan(230));
        expect(avatar.getPixel(383, 192).g, greaterThan(230));
        expect(photo.avatarBytes.length, lessThan(original.length));
      }

      final path = await repository.upload('alice', photo);
      expect(path, matches(r'^profilePhotos/alice/\d+-\d+\.jpg$'));
      expect(storage.path, path);
      expect(storage.reference.bytes, same(photo.bytes));
      expect(storage.reference.contentType, 'image/jpeg');
    },
  );

  test('keeps format and transparency for a PNG avatar', () async {
    final source = image.Image(width: 512, height: 768, numChannels: 4);
    image.fill(source, color: image.ColorRgba8(40, 60, 80, 127));
    final original = picker.bytes = image.encodePng(source);
    final photo = (await repository.pick())!;
    final avatar = image.decodePng(photo.avatarBytes)!;
    expect((avatar.width, avatar.height), kIsWeb ? (512, 768) : (384, 384));
    expect(avatar.getPixel(200, 200).a, 127);

    expect(await repository.upload('alice', photo), endsWith('.png'));
    expect(storage.reference.bytes, orderedEquals(original));
    expect(storage.reference.contentType, 'image/png');
  });

  test(
    'cancellation and an already-small image use the existing path',
    () async {
      expect(await repository.pick(), isNull);
      picker.bytes = image.encodePng(image.Image(width: 128, height: 96));
      final photo = (await repository.pick())!;
      expect(photo.thumbnailBytes, isNull);
      expect(photo.avatarBytes, same(photo.bytes));
      expect(storage.path, isNull);
    },
  );

  test('rejects empty, oversized and unsupported picker bytes', () async {
    for (final invalid in [
      Uint8List(0),
      Uint8List(FirebaseProfilePhotoRepository.maxBytes + 1),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      picker.bytes = invalid;
      await expectLater(repository.pick(), throwsFormatException);
    }
    expect(storage.path, isNull);
  });

  test(
    'rejects a truncated JPEG after its signature and accepts the next pick',
    () async {
      picker.bytes = Uint8List.fromList([0xff, 0xd8, 0xff]);
      await expectLater(repository.pick(), throwsFormatException);
      expect(storage.path, isNull);

      picker.bytes = image.encodeJpg(image.Image(width: 90, height: 60));
      expect(await repository.pick(), isNotNull);
    },
    skip: kIsWeb,
  );

  test('bounds the decoded pixel count even for a compact PNG', () async {
    final oversized = image.Image(width: 2049, height: 2048);
    picker.bytes = image.encodePng(oversized);
    expect(
      picker.bytes!.length,
      lessThan(FirebaseProfilePhotoRepository.maxBytes),
    );
    await expectLater(repository.pick(), throwsFormatException);
    expect(storage.path, isNull);
  }, skip: kIsWeb);

  test('runs the photo worker in a separate native Dart isolate', () async {
    final mainPort = Isolate.current.controlPort;
    final result = await compute(
      _runThumbnailAndIdentifyIsolate,
      _largeJpeg(),
      debugLabel: 'profile-photo-thumbnail-isolate-test',
    );
    expect(result.port, isNot(mainPort));
    final avatar = image.decodeJpg(result.bytes!)!;
    expect((avatar.width, avatar.height), (384, 384));
  }, skip: kIsWeb);
}
