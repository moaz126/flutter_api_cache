import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

CacheEntry createEntry(String data, {int ttlSeconds = 300}) {
  return CacheEntry(
    data: data,
    statusCode: 200,
    createdAt: DateTime.now(),
    ttlSeconds: ttlSeconds,
  );
}

void main() {
  group('MemoryCacheStorage', () {
    late MemoryCacheStorage storage;

    setUp(() async {
      storage = MemoryCacheStorage(maxEntries: 10);
      await storage.init();
    });

    test('should store and retrieve an entry', () async {
      final entry = createEntry('{"id":1}');
      await storage.put('key1', entry);

      final result = await storage.get('key1');
      expect(result, isNotNull);
      expect(result!.data, '{"id":1}');
    });

    test('should return null for non-existent key', () async {
      final result = await storage.get('nonexistent');
      expect(result, isNull);
    });

    test('should remove an entry', () async {
      final entry = createEntry('{"id":1}');
      await storage.put('key1', entry);
      await storage.remove('key1');

      final result = await storage.get('key1');
      expect(result, isNull);
      expect(await storage.containsKey('key1'), isFalse);
    });

    test('should evict LRU entry when maxEntries exceeded', () async {
      storage = MemoryCacheStorage(maxEntries: 3);
      await storage.init();

      await storage.put('key1', createEntry('data1'));
      await storage.put('key2', createEntry('data2'));
      await storage.put('key3', createEntry('data3'));
      await storage.put('key4', createEntry('data4'));

      expect(await storage.containsKey('key1'), isFalse);
      expect(await storage.containsKey('key2'), isTrue);
      expect(await storage.containsKey('key3'), isTrue);
      expect(await storage.containsKey('key4'), isTrue);
    });

    test('should update LRU order on get', () async {
      storage = MemoryCacheStorage(maxEntries: 3);
      await storage.init();

      await storage.put('key1', createEntry('data1'));
      await storage.put('key2', createEntry('data2'));
      await storage.put('key3', createEntry('data3'));

      // Access key1 to make it most recently used.
      await storage.get('key1');

      // Adding key4 should evict key2 (now the LRU), not key1.
      await storage.put('key4', createEntry('data4'));

      expect(await storage.containsKey('key1'), isTrue);
      expect(await storage.containsKey('key2'), isFalse);
      expect(await storage.containsKey('key3'), isTrue);
      expect(await storage.containsKey('key4'), isTrue);
    });

    test('should return all keys', () async {
      await storage.put('key1', createEntry('data1'));
      await storage.put('key2', createEntry('data2'));
      await storage.put('key3', createEntry('data3'));

      final keys = await storage.getAllKeys();
      expect(keys, containsAll(['key1', 'key2', 'key3']));
      expect(keys.length, 3);
    });

    test('should return correct length', () async {
      await storage.put('key1', createEntry('data1'));
      await storage.put('key2', createEntry('data2'));
      await storage.put('key3', createEntry('data3'));

      expect(await storage.length, 3);

      await storage.remove('key1');
      expect(await storage.length, 2);
    });

    test('should clear all entries', () async {
      await storage.put('key1', createEntry('data1'));
      await storage.put('key2', createEntry('data2'));
      await storage.put('key3', createEntry('data3'));

      await storage.clear();
      expect(await storage.length, 0);
    });

    test('should calculate sizeInBytes', () async {
      await storage.put('key1', createEntry('hello'));

      final size = await storage.sizeInBytes;
      expect(size, 5);
    });
  });
}
