import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

void main() {
  group('CacheEntry', () {
    test('should create CacheEntry with correct values', () {
      final now = DateTime.now();
      final entry = CacheEntry(
        data: '{"name":"test"}',
        statusCode: 200,
        createdAt: now,
        ttlSeconds: 300,
      );

      expect(entry.data, '{"name":"test"}');
      expect(entry.statusCode, 200);
      expect(entry.createdAt, now);
      expect(entry.ttlSeconds, 300);
      expect(entry.accessCount, 0);
      expect(entry.lastAccessedAt, now);
    });

    test('should detect non-expired entry', () {
      final entry = CacheEntry(
        data: '{}',
        statusCode: 200,
        createdAt: DateTime.now(),
        ttlSeconds: 300,
      );

      expect(entry.isExpired, isFalse);
    });

    test('should detect expired entry', () {
      final entry = CacheEntry(
        data: '{}',
        statusCode: 200,
        createdAt: DateTime.now().subtract(const Duration(seconds: 400)),
        ttlSeconds: 300,
      );

      expect(entry.isExpired, isTrue);
    });

    test('should calculate remainingTtl correctly', () {
      final nonExpired = CacheEntry(
        data: '{}',
        statusCode: 200,
        createdAt: DateTime.now(),
        ttlSeconds: 300,
      );

      expect(nonExpired.remainingTtl, greaterThan(0));
      expect(nonExpired.remainingTtl, lessThanOrEqualTo(300));

      final expired = CacheEntry(
        data: '{}',
        statusCode: 200,
        createdAt: DateTime.now().subtract(const Duration(seconds: 400)),
        ttlSeconds: 300,
      );

      expect(expired.remainingTtl, 0);
    });

    test('should increment accessCount on markAccessed', () {
      final now = DateTime.now();
      final entry = CacheEntry(
        data: '{}',
        statusCode: 200,
        createdAt: now,
        ttlSeconds: 300,
      );

      entry.markAccessed();
      entry.markAccessed();
      entry.markAccessed();

      expect(entry.accessCount, 3);
      expect(entry.lastAccessedAt.isAfter(now), isTrue);
    });

    test('should serialize to JSON and deserialize back correctly', () {
      final now = DateTime.now();
      final entry = CacheEntry(
        data: '{"name":"test"}',
        statusCode: 200,
        headers: '{"content-type":["application/json"]}',
        createdAt: now,
        ttlSeconds: 300,
        accessCount: 5,
        lastAccessedAt: now.add(const Duration(seconds: 10)),
      );

      final json = entry.toJson();
      final restored = CacheEntry.fromJson(json);

      expect(restored.data, entry.data);
      expect(restored.statusCode, entry.statusCode);
      expect(restored.headers, entry.headers);
      expect(restored.createdAt, entry.createdAt);
      expect(restored.ttlSeconds, entry.ttlSeconds);
      expect(restored.accessCount, entry.accessCount);
      expect(restored.lastAccessedAt, entry.lastAccessedAt);
    });

    test('should handle null headers in fromJson', () {
      final json = {
        'data': '{}',
        'statusCode': 200,
        'headers': null,
        'createdAt': DateTime.now().toIso8601String(),
        'ttlSeconds': 300,
        'accessCount': 0,
        'lastAccessedAt': DateTime.now().toIso8601String(),
      };

      final entry = CacheEntry.fromJson(json);
      expect(entry.headers, isNull);
    });

    test('should handle null accessCount in fromJson defaulting to 0', () {
      final json = {
        'data': '{}',
        'statusCode': 200,
        'headers': null,
        'createdAt': DateTime.now().toIso8601String(),
        'ttlSeconds': 300,
        'lastAccessedAt': DateTime.now().toIso8601String(),
      };

      final entry = CacheEntry.fromJson(json);
      expect(entry.accessCount, 0);
    });
  });
}
