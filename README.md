# flutter_api_cache

[![Pub Version](https://img.shields.io/pub/v/flutter_api_cache.svg)](https://pub.dev/packages/flutter_api_cache)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/moaz126/flutter_api_cache/ci.yml?branch=main)](https://github.com/moaz126/flutter_api_cache/actions)
[![Pub Points](https://img.shields.io/pub/points/flutter_api_cache)](https://pub.dev/packages/flutter_api_cache/score)

A powerful, lightweight API response caching solution for Flutter with TTL, offline-first support, stale-while-revalidate, and Dio interceptor.

---

## Features

- 🗂️ **5 caching strategies** — cacheFirst, networkFirst, staleWhileRevalidate, networkOnly, cacheOnly
- 🔌 **Dio interceptor** with automatic caching — drop-in, zero-boilerplate integration
- ⚡ **Dual-layer caching** — in-memory LRU cache + persistent disk storage via Hive
- ⏱️ **Configurable TTL per endpoint** — fine-grained control over cache freshness
- 📡 **Offline-first support** — automatic cache fallback on network errors
- 🔄 **Stale-while-revalidate** with background refresh callback
- 🔑 **Smart cache key generation** using MD5 hashing
- 🧹 **LRU eviction** by count, size, and TTL expiry
- 🎯 **Per-request and URL-based policy configuration**
- 🚀 **Force refresh support** — bypass cache on demand
- 📊 **Cache statistics and manual invalidation**

---

## Installation

Add `flutter_api_cache` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_api_cache: ^0.0.1
```

Then run:

```bash
flutter pub get
```

---

## Quick Start

```dart
import 'package:dio/dio.dart';
import 'package:flutter_api_cache/flutter_api_cache.dart';

Future<void> main() async {
  // 1. Create and initialize the cache manager
  final cacheManager = ApiCacheManager(
    config: const CacheConfig(
      defaultTtlSeconds: 300,
      maxEntries: 500,
      enableLogging: true,
    ),
  );
  await cacheManager.init();

  // 2. Create Dio and attach the cache interceptor
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(CacheInterceptor(cacheManager: cacheManager));

  // 3. Make requests — caching is handled automatically
  final response = await dio.get('/users');
  print('From cache: ${response.extra['fromCache'] ?? false}');
}
```

---

## Caching Strategies

| Strategy | Behavior | Best For |
|---|---|---|
| `cacheFirst` | Returns cache if available and fresh, otherwise fetches from network. | Mostly static data |
| `networkFirst` | Always tries network first, falls back to cache on failure. | Frequently updated data |
| `staleWhileRevalidate` | Returns cache immediately (even if stale), refreshes in background. | Feeds and lists |
| `networkOnly` | Always fetches from network, never uses or stores cache. | Auth, payments |
| `cacheOnly` | Only returns cached data, never makes a network call. | Offline mode |

---

## Advanced Usage

### Per-Request Policy

Override the default caching policy for a specific request using `cachePolicyKey` in request extras:

```dart
final response = await dio.get(
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
```

### URL-Based Policy Map

Configure different policies for different URL patterns via the interceptor's `policyMap`:

```dart
dio.interceptors.add(
  CacheInterceptor(
    cacheManager: cacheManager,
    policyMap: {
      '/users': const CachePolicy(
        strategy: CacheStrategy.cacheFirst,
        ttlSeconds: 300,
      ),
      '/config': const CachePolicy(
        strategy: CacheStrategy.cacheFirst,
        ttlSeconds: 3600, // Config rarely changes
      ),
      '/feed': const CachePolicy(
        strategy: CacheStrategy.staleWhileRevalidate,
        ttlSeconds: 60,
      ),
      '/auth': CachePolicy.none, // Never cache auth endpoints
    },
  ),
);
```

### Force Refresh

Bypass the cache and fetch fresh data from the network:

```dart
final response = await dio.get(
  '/users',
  options: Options(
    extra: {
      cachePolicyKey: const CachePolicy(forceRefresh: true),
    },
  ),
);
```

### Background Update Callback

React to background refreshes when using the stale-while-revalidate strategy:

```dart
cacheManager.onBackgroundUpdate = (key, entry) {
  print('Background refresh completed for: $key');
  // Update your UI here when fresh data arrives
};
```

### Manual Cache Operations

```dart
// Invalidate a specific endpoint
await cacheManager.invalidate('https://api.example.com/users/1');

// Invalidate all entries matching a predicate
await cacheManager.invalidateWhere((key) => key.contains('users'));

// Clear the entire cache
await cacheManager.clearAll();

// Get cache statistics
final stats = await cacheManager.getStats();
print(stats); // CacheStats(entries: 42, size: 0.15 MB, memory: 12)

// Dispose when done
await cacheManager.dispose();
```

### Custom Storage Backend

Implement the `CacheStorage` abstract class to provide your own storage backend (e.g. SQLite, shared preferences, or a remote cache). Pass your custom implementation as the `diskStorage` parameter when creating `ApiCacheManager`.

```dart
final cacheManager = ApiCacheManager(
  diskStorage: MyCustomStorage(),
);
```

---

## Configuration

```dart
final cacheManager = ApiCacheManager(
  config: const CacheConfig(
    defaultTtlSeconds: 300,    // Default TTL: 5 minutes
    maxEntries: 500,           // Max cached entries before LRU eviction
    maxSizeBytes: 0,           // Max cache size in bytes (0 = unlimited)
    enableLogging: false,      // Print cache operations to console
    boxName: 'flutter_api_cache', // Hive box name for disk storage
    useMemoryCache: true,      // Enable in-memory LRU cache layer
    maxMemoryEntries: 100,     // Max entries in the memory cache
  ),
);
```

---

## How It Works

1. **Request arrives** → the Dio interceptor resolves the caching policy and checks the cache.
2. **Cache hit** → the cached response is returned immediately, skipping the network call.
3. **Cache miss** → the request is forwarded to the network; the response is cached on success.
4. **Network error** → the interceptor falls back to stale cached data when available.
5. **Background** → the eviction manager periodically cleans expired entries and enforces count/size limits.

---

## Contributing

Contributions are welcome! To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes and write tests
4. Ensure all checks pass before submitting:
   ```bash
   dart analyze
   dart format .
   flutter test
   ```
5. Submit a pull request

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
