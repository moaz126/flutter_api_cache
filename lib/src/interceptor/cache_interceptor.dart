import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/cache_policy.dart';
import '../core/cache_strategy.dart';
import '../managers/cache_manager.dart';
import '../utils/cache_key_builder.dart';

/// The key used to attach a [CachePolicy] to a Dio request's
/// `RequestOptions.extra` map.
///
/// Example:
/// ```dart
/// dio.get('/endpoint', options: Options(extra: {cachePolicyKey: myPolicy}));
/// ```
const String cachePolicyKey = 'cachePolicy';

/// A Dio `Interceptor` that automatically handles caching of API responses.
///
/// Attach this interceptor to a `Dio` instance to transparently cache
/// responses, serve cached data when appropriate, recover from network errors
/// using cached fallbacks, and refresh stale entries in the background for the
/// stale-while-revalidate strategy.
///
/// Policies are resolved in order of precedence:
/// 1. Per-request policy attached via `RequestOptions.extra` using
///    [cachePolicyKey].
/// 2. A matching entry in [policyMap] (URL pattern → policy).
/// 3. The [defaultPolicy] fallback.
class CacheInterceptor extends Interceptor {
  /// Creates a new [CacheInterceptor].
  ///
  /// [cacheManager] is required. [policyMap] and [defaultPolicy] are optional
  /// with sensible defaults.
  CacheInterceptor({
    required this.cacheManager,
    this.policyMap = const {},
    this.defaultPolicy = const CachePolicy(),
  });

  /// The [ApiCacheManager] instance used to read and write cache entries.
  final ApiCacheManager cacheManager;

  /// A map of URL pattern strings to [CachePolicy] instances.
  ///
  /// During policy resolution, if the request URL contains a map key the
  /// corresponding policy is used. Defaults to an empty map.
  final Map<String, CachePolicy> policyMap;

  /// The fallback [CachePolicy] used when no per-request or pattern-matched
  /// policy is found.
  ///
  /// Defaults to `const CachePolicy()`.
  final CachePolicy defaultPolicy;

  /// Intercepts outgoing requests to serve cached responses when appropriate.
  ///
  /// - Skips caching logic for HTTP methods not listed in the resolved policy.
  /// - Skips caching for [CacheStrategy.networkOnly] or when
  ///   [CachePolicy.forceRefresh] is `true`.
  /// - For [CacheStrategy.staleWhileRevalidate], returns stale data
  ///   immediately and triggers a background refresh.
  /// - Resolves the response from cache by calling `handler.resolve` so Dio
  ///   skips the network call entirely.
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final policy = _resolvePolicy(options);

    if (!policy.methods.contains(options.method.toUpperCase())) {
      handler.next(options);
      return;
    }

    if (policy.strategy == CacheStrategy.networkOnly || policy.forceRefresh) {
      handler.next(options);
      return;
    }

    try {
      final cachedEntry =
          await cacheManager.getCachedResponse(options, policy: policy);

      if (cachedEntry != null) {
        final isStale = cachedEntry.isExpired;

        if (policy.strategy == CacheStrategy.staleWhileRevalidate && isStale) {
          _refreshInBackground(options, policy);
        }

        if (!isStale || policy.strategy == CacheStrategy.staleWhileRevalidate) {
          final response = Response(
            requestOptions: options,
            data: _tryJsonDecode(cachedEntry.data),
            statusCode: cachedEntry.statusCode,
            headers: cachedEntry.headers != null
                ? Headers.fromMap(_decodeHeaders(cachedEntry.headers!))
                : Headers(),
            extra: {
              'fromCache': true,
              'cacheKey': CacheKeyBuilder.build(options),
            },
          );
          handler.resolve(response);
          return;
        }
      }
    } catch (_) {
      // If cache retrieval fails, fall through to network request.
    }

    handler.next(options);
  }

  /// Intercepts successful responses to cache them according to the resolved
  /// policy.
  ///
  /// Responses are not cached when the strategy is [CacheStrategy.networkOnly].
  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final policy = _resolvePolicy(response.requestOptions);

    if (policy.strategy != CacheStrategy.networkOnly) {
      await cacheManager.cacheResponse(
        response.requestOptions,
        response,
        policy: policy,
      );
    }

    handler.next(response);
  }

  /// Intercepts errors to attempt a cached fallback for network failures.
  ///
  /// If the error is a network error and the strategy is not
  /// [CacheStrategy.networkOnly], the interceptor tries to resolve the request
  /// from cache. If a cached entry is found the error is recovered and a
  /// cached `Response` is returned instead.
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final policy = _resolvePolicy(err.requestOptions);

    if (_isNetworkError(err) && policy.strategy != CacheStrategy.networkOnly) {
      try {
        final fallbackPolicy = policy.copyWith(
          strategy: CacheStrategy.cacheOnly,
          forceRefresh: false,
        );
        final cachedEntry = await cacheManager.getCachedResponse(
          err.requestOptions,
          policy: fallbackPolicy,
        );

        if (cachedEntry != null) {
          final response = Response(
            requestOptions: err.requestOptions,
            data: _tryJsonDecode(cachedEntry.data),
            statusCode: cachedEntry.statusCode,
            extra: {
              'fromCache': true,
              'isStale': cachedEntry.isExpired,
            },
          );
          handler.resolve(response);
          return;
        }
      } catch (_) {
        // If cache fallback fails, pass the original error through.
      }
    }

    handler.next(err);
  }

  /// Resolves the [CachePolicy] for a given request.
  ///
  /// Checks in order:
  /// 1. Per-request policy in `RequestOptions.extra` under [cachePolicyKey].
  /// 2. First matching URL pattern in [policyMap].
  /// 3. [defaultPolicy] as the final fallback.
  CachePolicy _resolvePolicy(RequestOptions options) {
    if (options.extra.containsKey(cachePolicyKey)) {
      return options.extra[cachePolicyKey] as CachePolicy;
    }

    for (final entry in policyMap.entries) {
      if (options.uri.toString().contains(entry.key)) {
        return entry.value;
      }
    }

    return defaultPolicy;
  }

  /// Refreshes a cache entry in the background for stale-while-revalidate.
  ///
  /// Creates a separate `Dio` instance (to avoid infinite interceptor loops),
  /// re-issues the original request, and caches the fresh response. If the
  /// [ApiCacheManager.onBackgroundUpdate] callback is set, it is invoked with
  /// the updated entry.
  ///
  /// Failures are silently ignored — the stale cache remains valid.
  Future<void> _refreshInBackground(
    RequestOptions options,
    CachePolicy policy,
  ) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: options.baseUrl,
        headers: options.headers,
      ));

      final response = await dio.request(
        options.path,
        queryParameters: options.queryParameters,
        data: options.data,
        options: Options(method: options.method),
      );

      await cacheManager.cacheResponse(options, response, policy: policy);

      if (cacheManager.onBackgroundUpdate != null) {
        final key = CacheKeyBuilder.build(options);
        final entry = await cacheManager.getCachedResponse(
          options,
          policy: policy,
        );
        if (entry != null) {
          cacheManager.onBackgroundUpdate!(key, entry);
        }
      }
    } catch (_) {
      // Background refresh failure is silent — stale cache remains valid.
    }
  }

  /// Returns `true` if the `DioException` represents a network-level error.
  ///
  /// Covers connection timeouts, receive timeouts, send timeouts, connection
  /// errors, and unknown errors that are typically caused by lack of
  /// connectivity.
  bool _isNetworkError(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.unknown;
  }

  /// Attempts to decode a JSON string, returning the parsed object on success
  /// or the raw string if decoding fails.
  dynamic _tryJsonDecode(String data) {
    try {
      return jsonDecode(data);
    } catch (_) {
      return data;
    }
  }

  /// Decodes a JSON string of headers into the format expected by
  /// `Headers.fromMap`.
  ///
  /// Each header value is expected to be a `List<String>`. Returns an empty
  /// map if decoding fails.
  Map<String, List<String>> _decodeHeaders(String headersJson) {
    try {
      final decoded = jsonDecode(headersJson) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value as List).cast<String>()),
      );
    } catch (_) {
      return {};
    }
  }
}
