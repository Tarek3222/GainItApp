import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainit/core/services/id_generator.dart';
import 'package:gainit/core/services/local_media_store.dart';

void main() {
  late Directory root;
  late Directory media;
  late LocalMediaStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('media_store_test');
    media = Directory('${root.path}${Platform.pathSeparator}media')
      ..createSync();
    store = LocalMediaStore(const IdGenerator(), directory: media.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  File fileIn(Directory dir, String name) =>
      File('${dir.path}${Platform.pathSeparator}$name')..writeAsStringSync('x');

  test('resolves a stored file name inside the media folder', () {
    final photo = fileIn(media, 'me.jpg');

    expect(store.resolve('me.jpg'), photo.path);
    expect(store.resolve('missing.jpg'), isNull);
  });

  test('an old absolute path still resolves by its file name', () {
    final photo = fileIn(media, 'me.jpg');

    expect(
      store.resolve('/var/old-container/Documents/media/me.jpg'),
      photo.path,
    );
  });

  test('delete never leaves the media folder', () async {
    final outside = fileIn(root, 'keep.txt');

    await store.delete('../keep.txt');
    await store.delete(outside.path);

    expect(outside.existsSync(), isTrue);
  });

  test('clearAll removes every stored file', () async {
    fileIn(media, 'a.jpg');
    fileIn(media, 'b.jpg');

    final result = await store.clearAll();

    expect(result.isSuccess, isTrue);
    expect(media.existsSync(), isFalse);
  });
}
