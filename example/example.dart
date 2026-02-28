import 'package:dio/dio.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

Future<void> main() async {
  // ──────────────────────────────────────────────────────────────────────────
  // Example 1 — Basic Setup
  // ──────────────────────────────────────────────────────────────────────────

  // Create a cache manager with global configuration.
  final cacheManager = ApiCacheManager(
    config: const CacheConfig(
      defaultTtlSeconds: 300,
      maxEntries: 500,
      enableLogging: true,
    ),
  );

  // Initialize storage backends — must be called before any cache operations.
  await cacheManager.init();

  // Create a Dio instance and attach the cache interceptor.
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(
    CacheInterceptor(
      cacheManager: cacheManager,
      defaultPolicy: const CachePolicy(
        strategy: CacheStrategy.cacheFirst,
        ttlSeconds: 300,
      ),
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Example 2 — Simple GET Request (auto-cached)
  // ──────────────────────────────────────────────────────────────────────────

  // All GET requests are automatically cached by the interceptor.
  final response = await dio.get('/users');
  print('From cache: ${response.extra['fromCache'] ?? false}');

  // ──────────────────────────────────────────────────────────────────────────
  // Example 3 — Per-Request Custom Policy
  // ──────────────────────────────────────────────────────────────────────────

  // Override the default policy for a specific request using extras.
  final detailResponse = await dio.get(
    '/users/1',
    options: Options(
      extra: {
        cachePolicyKey: const CachePolicy(
          strategy: CacheStrategy.networkFirst,
          ttlSeconds: 600,
        ),
      },
    ),
  );
  print(
      'User detail from cache: ${detailResponse.extra['fromCache'] ?? false}');

  // ──────────────────────────────────────────────────────────────────────────
  // Example 4 — URL-Based Policy Map
  // ──────────────────────────────────────────────────────────────────────────

  // Clear existing interceptors and add a new one with URL-based policies.
  dio.interceptors.clear();
  dio.interceptors.add(
    CacheInterceptor(
      cacheManager: cacheManager,
      policyMap: {
        '/users': const CachePolicy(
          strategy: CacheStrategy.cacheFirst,
          ttlSeconds: 300,
        ),
        // Config data rarely changes — cache aggressively for 1 hour.
        '/config': const CachePolicy(
          strategy: CacheStrategy.cacheFirst,
          ttlSeconds: 3600,
        ),
        '/feed': const CachePolicy(
          strategy: CacheStrategy.staleWhileRevalidate,
          ttlSeconds: 60,
        ),
        // Never cache auth endpoints.
        '/auth': CachePolicy.none,
      },
    ),
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Example 5 — Force Refresh
  // ──────────────────────────────────────────────────────────────────────────

  // Force a fresh network fetch, ignoring any cached data.
  final freshResponse = await dio.get(
    '/users',
    options: Options(
      extra: {
        cachePolicyKey: const CachePolicy(forceRefresh: true),
      },
    ),
  );
  print('Fresh data fetched: ${freshResponse.statusCode}');

  // ──────────────────────────────────────────────────────────────────────────
  // Example 6 — Stale-While-Revalidate with Background Callback
  // ──────────────────────────────────────────────────────────────────────────

  // Register a callback that fires when a background refresh completes.
  cacheManager.onBackgroundUpdate = (key, entry) {
    print('Background refresh completed for: $key');
    // Update your UI here when fresh data arrives.
  };

  // ──────────────────────────────────────────────────────────────────────────
  // Example 7 — Manual Cache Operations
  // ──────────────────────────────────────────────────────────────────────────

  // Invalidate a specific endpoint's cache.
  await cacheManager.invalidate('https://api.example.com/users/1');

  // Retrieve and print cache statistics.
  final stats = await cacheManager.getStats();
  print(stats);

  // Remove all cached entries.
  await cacheManager.clearAll();

  // Release resources when the cache manager is no longer needed.
  await cacheManager.dispose();
}
