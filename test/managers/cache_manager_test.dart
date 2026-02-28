import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

void main() {
  group('ApiCacheManager', () {
    late ApiCacheManager cacheManager;
    late MemoryCacheStorage diskStorage;

    setUp(() {
      diskStorage = MemoryCacheStorage(maxEntries: 100);
      cacheManager = ApiCacheManager(
        config: const CacheConfig(useMemoryCache: false),
        diskStorage: diskStorage,
      );
    });

    test('should throw StateError if not initialized', () async {
      expect(() => cacheManager.clearAll(), throwsStateError);
    });

    test('should initialize successfully', () async {
      await cacheManager.init();
      // Calling init again should be idempotent.
      await cacheManager.init();
    });

    test('should cache and retrieve a response', () async {
      await cacheManager.init();

      final options = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final response = Response(
        requestOptions: options,
        data: '{"id":1}',
        statusCode: 200,
        headers: Headers.fromMap({
          'content-type': ['application/json'],
        }),
      );

      await cacheManager.cacheResponse(options, response);

      final entry = await cacheManager.getCachedResponse(
        options,
        policy: const CachePolicy(strategy: CacheStrategy.cacheFirst),
      );

      expect(entry, isNotNull);
      expect(entry!.data, '{"id":1}');
    });

    test('should return null for non-cached request', () async {
      await cacheManager.init();

      final options = RequestOptions(
        method: 'GET',
        path: '/nonexistent',
        baseUrl: 'https://api.example.com',
      );

      final entry = await cacheManager.getCachedResponse(options);
      expect(entry, isNull);
    });

    test('should return null when forceRefresh is true', () async {
      await cacheManager.init();

      final options = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final response = Response(
        requestOptions: options,
        data: '{"id":1}',
        statusCode: 200,
        headers: Headers.fromMap({
          'content-type': ['application/json'],
        }),
      );

      await cacheManager.cacheResponse(options, response);

      final entry = await cacheManager.getCachedResponse(
        options,
        policy: const CachePolicy(forceRefresh: true),
      );

      expect(entry, isNull);
    });

    test('should return null for networkOnly strategy', () async {
      await cacheManager.init();

      final options = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final response = Response(
        requestOptions: options,
        data: '{"id":1}',
        statusCode: 200,
        headers: Headers.fromMap({
          'content-type': ['application/json'],
        }),
      );

      await cacheManager.cacheResponse(options, response);

      final entry = await cacheManager.getCachedResponse(
        options,
        policy: const CachePolicy(strategy: CacheStrategy.networkOnly),
      );

      expect(entry, isNull);
    });

    test('should invalidate a cached entry', () async {
      await cacheManager.init();

      final options = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final response = Response(
        requestOptions: options,
        data: '{"id":1}',
        statusCode: 200,
        headers: Headers.fromMap({
          'content-type': ['application/json'],
        }),
      );

      await cacheManager.cacheResponse(options, response);
      await cacheManager.invalidate('https://api.example.com/users');

      final entry = await cacheManager.getCachedResponse(options);
      expect(entry, isNull);
    });

    test('should clear all cache', () async {
      await cacheManager.init();

      for (int i = 0; i < 3; i++) {
        final options = RequestOptions(
          method: 'GET',
          path: '/users/$i',
          baseUrl: 'https://api.example.com',
        );
        final response = Response(
          requestOptions: options,
          data: '{"id":$i}',
          statusCode: 200,
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
        await cacheManager.cacheResponse(options, response);
      }

      await cacheManager.clearAll();

      final stats = await cacheManager.getStats();
      expect(stats.totalEntries, 0);
    });

    test('should return correct stats', () async {
      await cacheManager.init();

      for (int i = 0; i < 3; i++) {
        final options = RequestOptions(
          method: 'GET',
          path: '/endpoint$i',
          baseUrl: 'https://api.example.com',
        );
        final response = Response(
          requestOptions: options,
          data: '{"id":$i}',
          statusCode: 200,
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
        await cacheManager.cacheResponse(options, response);
      }

      final stats = await cacheManager.getStats();
      expect(stats.totalEntries, 3);
      expect(stats.sizeInBytes, greaterThan(0));
    });

    test('should not cache non-GET methods by default', () async {
      await cacheManager.init();

      final options = RequestOptions(
        method: 'POST',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final response = Response(
        requestOptions: options,
        data: '{"id":1}',
        statusCode: 200,
        headers: Headers.fromMap({
          'content-type': ['application/json'],
        }),
      );

      await cacheManager.cacheResponse(options, response);

      final entry = await cacheManager.getCachedResponse(options);
      expect(entry, isNull);
    });

    test('should not cache error status codes', () async {
      await cacheManager.init();

      final options = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final response = Response(
        requestOptions: options,
        data: '{"error":"not found"}',
        statusCode: 404,
        headers: Headers.fromMap({
          'content-type': ['application/json'],
        }),
      );

      await cacheManager.cacheResponse(options, response);

      final entry = await cacheManager.getCachedResponse(options);
      expect(entry, isNull);
    });
  });
}
