import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:whynot_mobile/models/profile_draft.dart';
import 'package:whynot_mobile/infrastructure/repositories/file_profile_draft_store.dart';

const draft = ProfileDraft(
  name: 'Ana',
  ageText: '2',
  gender: 'Female',
  categoryId: 'fashion',
  cityId: 'bogota',
  cityText: 'Bogotá',
);

void main() {
  late Directory directory;
  late FileProfileDraftStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('profile_draft_');
    store = FileProfileDraftStore(directory: () async => directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'JSON file survives store recreation and preserves incomplete edits',
    () async {
      await store.save('user', draft);
      store = FileProfileDraftStore(directory: () async => directory);
      final restored = (await store.load('user'))!;
      expect(restored.name, 'Ana');
      expect(restored.ageText, '2');
      expect(restored.cityText, 'Bogotá');
      final file =
          (await directory
                      .list(recursive: true)
                      .where((f) => f.path.endsWith('.json'))
                      .toList())
                  .single
              as File;
      final json = jsonDecode(await file.readAsString()) as Map;
      expect(
        json.keys,
        unorderedEquals([
          'version',
          'userId',
          'name',
          'ageText',
          'gender',
          'categoryId',
          'cityId',
          'cityText',
        ]),
      );
    },
  );

  test('account paths cannot collide or escape the draft directory', () async {
    for (final id in ['a/b', 'a_b', 'A', 'a', '../outside']) {
      await store.save(
        id,
        ProfileDraft(
          name: id,
          ageText: '',
          gender: null,
          categoryId: null,
          cityId: null,
          cityText: '',
        ),
      );
    }
    for (final id in ['a/b', 'a_b', 'A', 'a', '../outside']) {
      expect((await store.load(id))!.name, id);
    }
    await store.clear('A');
    expect(await store.load('A'), isNull);
    expect((await store.load('a'))!.name, 'a');
  });

  test('serialized writes and clear cannot resurrect an older draft', () async {
    final first = store.save('u', draft);
    final second = store.save(
      'u',
      const ProfileDraft(
        name: 'Latest',
        ageText: '',
        gender: null,
        categoryId: null,
        cityId: null,
        cityText: '',
      ),
    );
    await Future.wait([first, second]);
    expect((await store.load('u'))!.name, 'Latest');
    await Future.wait([store.save('u', draft), store.clear('u')]);
    expect(await store.load('u'), isNull);
    await expectLater(store.save('', draft), throwsArgumentError);
    await store.save('u', draft);
    expect(await store.load('u'), isNotNull);
  });

  test(
    'corrupt, other-account, oversized and unknown-version JSON are ignored',
    () {
      expect(ProfileDraft.decode('{', 'u'), isNull);
      expect(ProfileDraft.decode(draft.encode('v'), 'u'), isNull);
      expect(
        ProfileDraft.decode(
          draft.encode('u').replaceFirst('"version":1', '"version":99'),
          'u',
        ),
        isNull,
      );
      expect(ProfileDraft.decode('x' * 17000, 'u'), isNull);
      expect(
        ProfileDraft.decode('{"version":1,"userId":"u","name":5}', 'u'),
        isNull,
      );
    },
  );
}
