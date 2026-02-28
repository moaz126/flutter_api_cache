import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Generates unique, consistent cache keys from API requests.
///
/// All methods are static. Cache keys are produced by building a canonical
/// string representation of the request (method, URL, sorted query parameters,
/// body for mutating methods, and an optional suffix) and then hashing it with
/// MD5.
///
/// MD5 is used because it produces short, fixed-length keys regardless of how
/// long or complex the original URL and parameters are, while still providing
/// a highly collision-resistant mapping from request identity to key.
class CacheKeyBuilder {
  /// Builds a cache key from a Dio [RequestOptions] instance.
  ///
  /// The key is derived from:
  /// - the HTTP method
  /// - the full URI including path
  /// - query parameters (sorted alphabetically by key for consistency)
  /// - the request body for `POST`, `PUT`, and `PATCH` requests
  /// - an optional [suffix] for further differentiation
  ///
  /// Returns an MD5 hash string of the canonical request representation.
  static String build(RequestOptions options, {String? suffix}) {
    final buffer = StringBuffer();

    buffer.write(options.method);
    buffer.write(':');
    buffer.write(options.uri.toString());

    if (options.queryParameters.isNotEmpty) {
      final sortedParams = Map.fromEntries(
        options.queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      buffer.write('?');
      buffer.write(jsonEncode(sortedParams));
    }

    final method = options.method.toUpperCase();
    if (options.data != null &&
        (method == 'POST' || method == 'PUT' || method == 'PATCH')) {
      buffer.write('|body:');
      buffer.write(jsonEncode(options.data));
    }

    if (suffix != null) {
      buffer.write('|');
      buffer.write(suffix);
    }

    final bytes = utf8.encode(buffer.toString());
    final hash = md5.convert(bytes);
    return hash.toString();
  }

  /// Builds a cache key from a plain URL string and HTTP [method].
  ///
  /// A simplified alternative to [build] for cases where full
  /// [RequestOptions] are not available. The key is derived from the HTTP
  /// [method] (defaults to `'GET'`), the [url], and an optional [suffix].
  ///
  /// Returns an MD5 hash string of the canonical representation.
  static String buildSimple(String url,
      {String method = 'GET', String? suffix}) {
    final buffer = StringBuffer();

    buffer.write(method);
    buffer.write(':');
    buffer.write(url);

    if (suffix != null) {
      buffer.write('|');
      buffer.write(suffix);
    }

    final bytes = utf8.encode(buffer.toString());
    final hash = md5.convert(bytes);
    return hash.toString();
  }
}
