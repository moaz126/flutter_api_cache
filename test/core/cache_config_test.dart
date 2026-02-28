import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

void main() {
  group('CacheConfig', () {
    test('should have correct default values', () {
      const config = CacheConfig();

      expect(config.defaultTtlSeconds, 300);
      expect(config.maxEntries, 500);
      expect(config.maxSizeBytes, 0);
      expect(config.encrypt, isFalse);
      expect(config.encryptionKey, isNull);
      expect(config.enableLogging, isFalse);
      expect(config.boxName, 'flutter_api_cache');
      expect(config.useMemoryCache, isTrue);
      expect(config.maxMemoryEntries, 100);
    });

    test('should accept custom values', () {
      const config = CacheConfig(
        defaultTtlSeconds: 600,
        maxEntries: 1000,
        maxSizeBytes: 5242880,
        encrypt: true,
        encryptionKey: 'my-secret-key',
        enableLogging: true,
        boxName: 'custom_box',
        useMemoryCache: false,
        maxMemoryEntries: 50,
      );

      expect(config.defaultTtlSeconds, 600);
      expect(config.maxEntries, 1000);
      expect(config.maxSizeBytes, 5242880);
      expect(config.encrypt, isTrue);
      expect(config.encryptionKey, 'my-secret-key');
      expect(config.enableLogging, isTrue);
      expect(config.boxName, 'custom_box');
      expect(config.useMemoryCache, isFalse);
      expect(config.maxMemoryEntries, 50);
    });
  });
}
