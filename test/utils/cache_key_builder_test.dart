import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

void main() {
  group('CacheKeyBuilder', () {
    test('should generate consistent key for same input', () {
      final options1 = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final options2 = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );

      final key1 = CacheKeyBuilder.build(options1);
      final key2 = CacheKeyBuilder.build(options2);

      expect(key1, key2);
    });

    test('should generate different keys for different URLs', () {
      final options1 = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final options2 = RequestOptions(
        method: 'GET',
        path: '/posts',
        baseUrl: 'https://api.example.com',
      );

      final key1 = CacheKeyBuilder.build(options1);
      final key2 = CacheKeyBuilder.build(options2);

      expect(key1, isNot(key2));
    });

    test('should generate different keys for different methods', () {
      final options1 = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );
      final options2 = RequestOptions(
        method: 'POST',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );

      final key1 = CacheKeyBuilder.build(options1);
      final key2 = CacheKeyBuilder.build(options2);

      expect(key1, isNot(key2));
    });

    test('should include query parameters in key', () {
      final options1 = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
        queryParameters: {'page': '1'},
      );
      final options2 = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
        queryParameters: {'page': '2'},
      );

      final key1 = CacheKeyBuilder.build(options1);
      final key2 = CacheKeyBuilder.build(options2);

      expect(key1, isNot(key2));
    });

    test('should include body in key for POST requests', () {
      final options1 = RequestOptions(
        method: 'POST',
        path: '/users',
        baseUrl: 'https://api.example.com',
        data: {'name': 'Alice'},
      );
      final options2 = RequestOptions(
        method: 'POST',
        path: '/users',
        baseUrl: 'https://api.example.com',
        data: {'name': 'Bob'},
      );

      final key1 = CacheKeyBuilder.build(options1);
      final key2 = CacheKeyBuilder.build(options2);

      expect(key1, isNot(key2));
    });

    test('should not include body for GET requests', () {
      final options1 = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
        data: {'name': 'Alice'},
      );
      final options2 = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
        data: {'name': 'Bob'},
      );

      final key1 = CacheKeyBuilder.build(options1);
      final key2 = CacheKeyBuilder.build(options2);

      expect(key1, key2);
    });

    test('should append suffix to key', () {
      final options = RequestOptions(
        method: 'GET',
        path: '/users',
        baseUrl: 'https://api.example.com',
      );

      final keyWithout = CacheKeyBuilder.build(options);
      final keyWith = CacheKeyBuilder.build(options, suffix: 'v2');

      expect(keyWithout, isNot(keyWith));
    });

    test('buildSimple should generate consistent keys', () {
      final key1 = CacheKeyBuilder.buildSimple(
        'https://api.example.com/users',
        method: 'GET',
      );
      final key2 = CacheKeyBuilder.buildSimple(
        'https://api.example.com/users',
        method: 'GET',
      );
      final key3 = CacheKeyBuilder.buildSimple(
        'https://api.example.com/posts',
        method: 'GET',
      );

      expect(key1, key2);
      expect(key1, isNot(key3));
    });
  });
}
