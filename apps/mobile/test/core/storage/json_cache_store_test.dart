import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dailio/core/storage/json_cache_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dailio-json-cache-test-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('returns cached JSON first and replaces it after background refresh',
      () async {
    final store = JsonCacheStore(directoryProvider: () async => root)
      ..setUserId('user-1');
    var fetchCount = 0;
    final freshValues = <String>[];
    final refreshed = Completer<void>();
    final refreshGate = Completer<String>();

    Future<String> load() => store.load<String>(
          key: store.scopedKey('members:branch-1'),
          scope: 'branch:branch-1',
          fetch: () async {
            fetchCount += 1;
            return fetchCount == 1 ? 'first' : refreshGate.future;
          },
          decode: (payload) => payload.toString(),
          onFresh: (value) {
            freshValues.add(value);
            if (!refreshed.isCompleted) refreshed.complete();
          },
        );

    expect(await load(), 'first');
    expect(fetchCount, 1);

    expect(await load(), 'first');
    refreshGate.complete('fresh');
    await refreshed.future.timeout(const Duration(seconds: 1));
    expect(fetchCount, 2);
    expect(freshValues, ['fresh']);
    expect(
      (await store.read(store.scopedKey('members:branch-1')))?.payload,
      'fresh',
    );
  });

  test('scopes keys by user and clears the complete cache', () async {
    final store = JsonCacheStore(directoryProvider: () async => root)
      ..setUserId('user-1');
    final userOneKey = store.scopedKey('organizations');
    await store.write(userOneKey, {'name': 'one'}, scope: 'user');

    store.setUserId('user-2');
    final userTwoKey = store.scopedKey('organizations');
    expect(userTwoKey, isNot(userOneKey));
    expect(await store.read(userTwoKey), isNull);
    store.setUserId('user-1');
    expect((await store.read(userOneKey))?.payload, {'name': 'one'});

    await store.clearAll();
    expect(await store.read(userOneKey), isNull);
  });

  test('does not restore stale data after a key is invalidated', () async {
    final store = JsonCacheStore(directoryProvider: () async => root)
      ..setUserId('user-1');
    final key = store.scopedKey('feed-posts:feed-1');
    await store.write(key, 'old', scope: 'branch:branch-1');
    final refreshGate = Completer<String>();

    final cachedLoad = store.load<String>(
      key: key,
      scope: 'branch:branch-1',
      fetch: () => refreshGate.future,
      decode: (payload) => payload.toString(),
    );
    expect(await cachedLoad, 'old');
    await store.clearKey(key);
    refreshGate.complete('stale');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await store.read(key), isNull);
  });
}
