import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

void main() {
  group('CachePolicy', () {
    test('should have correct default values', () {
      const policy = CachePolicy();

      expect(policy.strategy, CacheStrategy.cacheFirst);
      expect(policy.ttlSeconds, 300);
      expect(policy.methods, ['GET']);
      expect(policy.forceRefresh, isFalse);
      expect(policy.keySuffix, isNull);
    });

    test('CachePolicy.none should have networkOnly strategy', () {
      expect(CachePolicy.none.strategy, CacheStrategy.networkOnly);
    });

    test('CachePolicy.aggressive should have 3600 ttl', () {
      expect(CachePolicy.aggressive.ttlSeconds, 3600);
      expect(CachePolicy.aggressive.strategy, CacheStrategy.cacheFirst);
    });

    test(
        'CachePolicy.staleWhileRevalidate should have correct strategy and 600 ttl',
        () {
      expect(CachePolicy.staleWhileRevalidate.strategy,
          CacheStrategy.staleWhileRevalidate);
      expect(CachePolicy.staleWhileRevalidate.ttlSeconds, 600);
    });

    test('copyWith should override only specified fields', () {
      const original = CachePolicy();
      final copied = original.copyWith(ttlSeconds: 600, forceRefresh: true);

      expect(copied.ttlSeconds, 600);
      expect(copied.forceRefresh, isTrue);
      expect(copied.strategy, CacheStrategy.cacheFirst);
      expect(copied.methods, ['GET']);
    });
  });
}
