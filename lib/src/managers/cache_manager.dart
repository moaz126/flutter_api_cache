import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/cache_config.dart';
import '../core/cache_entry.dart';
import '../core/cache_policy.dart';
import '../core/cache_strategy.dart';
import '../storage/cache_storage.dart';
import '../storage/hive_cache_storage.dart';
import '../storage/memory_cache_storage.dart';
import '../utils/cache_key_builder.dart';
import '../utils/connectivity_checker.dart';
import 'eviction_manager.dart';

/// The main public API of the flutter_api_cache package.
///
/// [ApiCacheManager] orchestrates caching of API responses using a dual-layer
/// storage system (optional in-memory LRU cache + persistent disk cache),
/// supports multiple [CacheStrategy] modes, handles connectivity-aware
/// fallback, and performs automatic eviction based on [CacheConfig] limits.
///
/// Call [init] before performing any other operations.
class ApiCacheManager {
  /// Creates a new [ApiCacheManager].
  ///
  /// [config] provides global cache settings and defaults to [CacheConfig()].
  /// An optional [diskStorage] can be injected for testing; otherwise a
  /// [HiveCacheStorage] is created using [CacheConfig.boxName].
  /// An optional [connectivityChecker] can be injected for testing.
  /// [onBackgroundUpdate] is an optional callback for stale-while-revalidate
  /// notifications.
  ApiCacheManager({
    this.config = const CacheConfig(),
    CacheStorage? diskStorage,
    ConnectivityChecker? connectivityChecker,
    this.onBackgroundUpdate,
  }) {
    _diskStorage = diskStorage ?? HiveCacheStorage(boxName: config.boxName);
    _memoryStorage = config.useMemoryCache
        ? MemoryCacheStorage(maxEntries: config.maxMemoryEntries)
        : null;
    _connectivityChecker = connectivityChecker ?? ConnectivityChecker();
    _evictionManager = EvictionManager(storage: _diskStorage, config: config);
  }

  /// The global cache configuration.
  final CacheConfig config;

  /// The persistent disk storage backend.
  late final CacheStorage _diskStorage;

  /// The optional in-memory LRU cache for faster access.
  late final MemoryCacheStorage? _memoryStorage;

  /// Handles eviction of expired and excess entries.
  late final EvictionManager _evictionManager;

  /// Checks device connectivity to decide between network and cache.
  late final ConnectivityChecker _connectivityChecker;

  /// Whether [init] has been called successfully.
  bool _initialized = false;

  /// Optional callback invoked when a stale-while-revalidate background
  /// update completes, providing the cache key and the freshly fetched entry.
  void Function(String key, CacheEntry entry)? onBackgroundUpdate;

  /// Initializes both storage backends and runs an initial eviction pass.
  ///
  /// Must be called once before any other operations. Subsequent calls are
  /// ignored.
  Future<void> init() async {
    if (_initialized) return;

    await _diskStorage.init();
    await _memoryStorage?.init();
    _initialized = true;
    await _evictionManager.evict();
  }

  /// Retrieves a cached response for the given [options] according to the
  /// specified [policy].
  ///
  /// Returns the matching [CacheEntry] if available and valid for the
  /// strategy, or `null` if the caller should fetch from the network.
  Future<CacheEntry?> getCachedResponse(
    RequestOptions options, {
    CachePolicy policy = const CachePolicy(),
  }) async {
    _ensureInitialized();

    if (policy.forceRefresh) return null;

    final key = CacheKeyBuilder.build(options, suffix: policy.keySuffix);

    CacheEntry? entry = await _memoryStorage?.get(key);
    entry ??= await _diskStorage.get(key);

    if (entry == null) return null;

    switch (policy.strategy) {
      case CacheStrategy.cacheFirst:
      case CacheStrategy.cacheOnly:
        return entry.isExpired ? null : entry;
      case CacheStrategy.staleWhileRevalidate:
        return entry;
      case CacheStrategy.networkFirst:
        final online = await _connectivityChecker.isOnline;
        if (online) return null;
        return entry;
      case CacheStrategy.networkOnly:
        return null;
    }
  }

  /// Caches a network [response] for the given [options] according to the
  /// specified [policy].
  ///
  /// Only successful responses (status 200–299) whose HTTP method is included
  /// in [CachePolicy.methods] are cached. The entry is stored in both the
  /// in-memory and disk caches, and an eviction pass is triggered afterwards.
  Future<void> cacheResponse(
    RequestOptions options,
    Response response, {
    CachePolicy policy = const CachePolicy(),
  }) async {
    _ensureInitialized();

    if (!policy.methods.contains(options.method.toUpperCase())) return;

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) return;

    final key = CacheKeyBuilder.build(options, suffix: policy.keySuffix);

    final data = response.data is String
        ? response.data as String
        : jsonEncode(response.data);

    final entry = CacheEntry(
      data: data,
      statusCode: statusCode,
      headers: jsonEncode(response.headers.map),
      createdAt: DateTime.now(),
      ttlSeconds: policy.ttlSeconds,
    );

    await _memoryStorage?.put(key, entry);
    await _diskStorage.put(key, entry);
    await _evictionManager.evict();

    if (config.enableLogging) {
      // ignore: avoid_print
      print(
        '[flutter_api_cache] Cached: ${options.method} ${options.uri} '
        '(TTL: ${policy.ttlSeconds}s)',
      );
    }
  }

  /// Invalidates (removes) the cached entry for a specific [url] and HTTP
  /// [method].
  ///
  /// An optional [keySuffix] can be provided if the entry was stored with one.
  Future<void> invalidate(
    String url, {
    String method = 'GET',
    String? keySuffix,
  }) async {
    _ensureInitialized();

    final key =
        CacheKeyBuilder.buildSimple(url, method: method, suffix: keySuffix);
    await _memoryStorage?.remove(key);
    await _diskStorage.remove(key);
  }

  /// Removes all cached entries whose key satisfies [predicate].
  ///
  /// Returns the total number of entries removed.
  Future<int> invalidateWhere(bool Function(String key) predicate) async {
    _ensureInitialized();

    final keys = await _diskStorage.getAllKeys();
    int count = 0;

    for (final key in keys) {
      if (predicate(key)) {
        await _memoryStorage?.remove(key);
        await _diskStorage.remove(key);
        count++;
      }
    }

    return count;
  }

  /// Removes all entries from both the in-memory and disk caches.
  Future<void> clearAll() async {
    _ensureInitialized();

    await _memoryStorage?.clear();
    await _diskStorage.clear();
  }

  /// Returns current cache statistics including total entries, size, and
  /// in-memory entry count.
  Future<CacheStats> getStats() async {
    _ensureInitialized();

    return CacheStats(
      totalEntries: await _diskStorage.length,
      sizeInBytes: await _diskStorage.sizeInBytes,
      memoryEntries: await _memoryStorage?.length ?? 0,
    );
  }

  /// Closes both storage backends and marks the manager as uninitialized.
  ///
  /// After calling [dispose], no further operations should be performed
  /// without calling [init] again.
  Future<void> dispose() async {
    await _memoryStorage?.close();
    await _diskStorage.close();
    _initialized = false;
  }

  /// Throws a [StateError] if [init] has not been called.
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'ApiCacheManager is not initialized. Call init() first.',
      );
    }
  }
}

/// A simple data class containing cache statistics.
class CacheStats {
  /// Creates a new [CacheStats] instance.
  const CacheStats({
    required this.totalEntries,
    required this.sizeInBytes,
    required this.memoryEntries,
  });

  /// The total number of entries stored on disk.
  final int totalEntries;

  /// The approximate total size of all cached data in bytes.
  final int sizeInBytes;

  /// The number of entries currently held in the in-memory cache.
  final int memoryEntries;

  /// The total cache size expressed in megabytes.
  double get sizeInMB => sizeInBytes / (1024 * 1024);

  @override
  String toString() =>
      'CacheStats(entries: $totalEntries, size: ${sizeInMB.toStringAsFixed(2)} MB, memory: $memoryEntries)';
}
