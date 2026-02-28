import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

CacheEntry createEntry(
  String data, {
  int ttlSeconds = 300,
  DateTime? createdAt,
}) {
  return CacheEntry(
    data: data,
    statusCode: 200,
    createdAt: createdAt ?? DateTime.now(),
    ttlSeconds: ttlSeconds,
  );
}

void main() {
  group('EvictionManager', () {
    late MemoryCacheStorage storage;

    setUp(() async {
      storage = MemoryCacheStorage(maxEntries: 100);
      await storage.init();
    });

    test('should evict expired entries', () async {
      final expired1 = createEntry(
        'expired1',
        ttlSeconds: 1,
        createdAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      final expired2 = createEntry(
        'expired2',
        ttlSeconds: 1,
        createdAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      final valid = createEntry('valid', ttlSeconds: 300);

      await storage.put('exp1', expired1);
      await storage.put('exp2', expired2);
      await storage.put('valid', valid);

      final manager = EvictionManager(
        storage: storage,
        config: const CacheConfig(maxEntries: 100),
      );

      final evicted = await manager.evict();

      expect(evicted, 2);
      expect(await storage.containsKey('valid'), isTrue);
      expect(await storage.containsKey('exp1'), isFalse);
      expect(await storage.containsKey('exp2'), isFalse);
    });

    test('should evict LRU entries when over maxEntries', () async {
      for (int i = 0; i < 5; i++) {
        await storage.put('key$i', createEntry('data$i'));
      }

      final manager = EvictionManager(
        storage: storage,
        config: const CacheConfig(maxEntries: 3),
      );

      await manager.evict();

      expect(await storage.length, 3);
    });

    test('should evict by size when over maxSizeBytes', () async {
      // Each entry data is 10 bytes of ASCII text.
      await storage.put('key1', createEntry('aaaaaaaaaa')); // 10 bytes
      await storage.put('key2', createEntry('bbbbbbbbbb')); // 10 bytes
      await storage.put('key3', createEntry('cccccccccc')); // 10 bytes

      final manager = EvictionManager(
        storage: storage,
        config: const CacheConfig(maxSizeBytes: 20),
      );

      await manager.evict();

      final size = await storage.sizeInBytes;
      expect(size, lessThanOrEqualTo(20));
    });

    test('should not evict when within limits', () async {
      await storage.put('key1', createEntry('data1'));
      await storage.put('key2', createEntry('data2'));

      final manager = EvictionManager(
        storage: storage,
        config: const CacheConfig(maxEntries: 10),
      );

      final evicted = await manager.evict();

      expect(evicted, 0);
      expect(await storage.containsKey('key1'), isTrue);
      expect(await storage.containsKey('key2'), isTrue);
    });
  });
}
