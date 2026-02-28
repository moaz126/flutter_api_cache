import 'dart:convert';

import '../core/cache_config.dart';
import '../core/cache_entry.dart';
import '../storage/cache_storage.dart';

/// Handles removing old or excess cache entries based on TTL expiry,
/// maximum entry count, and maximum size constraints.
///
/// The [evict] method runs three eviction stages in order:
/// 1. Remove expired entries (TTL-based)
/// 2. Remove least recently used entries if count exceeds [CacheConfig.maxEntries]
/// 3. Remove least recently used entries if size exceeds [CacheConfig.maxSizeBytes]
class EvictionManager {
  /// Creates a new [EvictionManager].
  ///
  /// Both [storage] and [config] are required.
  EvictionManager({required this.storage, required this.config});

  /// The storage backend to evict entries from.
  final CacheStorage storage;

  /// The global cache configuration containing eviction limits.
  final CacheConfig config;

  /// Runs all three eviction stages in order and returns the total number of
  /// entries evicted.
  ///
  /// 1. Expired entries are removed first.
  /// 2. If [CacheConfig.maxEntries] is greater than 0, excess entries are
  ///    evicted by LRU order.
  /// 3. If [CacheConfig.maxSizeBytes] is greater than 0, entries are evicted
  ///    by LRU order until the total size is within the limit.
  Future<int> evict() async {
    int evictedCount = 0;

    evictedCount += await _evictExpired();

    if (config.maxEntries > 0) {
      evictedCount += await _evictByCount();
    }

    if (config.maxSizeBytes > 0) {
      evictedCount += await _evictBySize();
    }

    return evictedCount;
  }

  /// Stage 1: Removes all entries whose TTL has expired.
  ///
  /// Iterates through every key in storage, checks [CacheEntry.isExpired],
  /// and removes any expired entries. Returns the number of entries removed.
  Future<int> _evictExpired() async {
    int count = 0;
    final keys = await storage.getAllKeys();

    for (final key in keys) {
      final entry = await storage.get(key);
      if (entry != null && entry.isExpired) {
        await storage.remove(key);
        count++;
      }
    }

    return count;
  }

  /// Stage 2: Removes least recently used entries when the total count exceeds
  /// [CacheConfig.maxEntries].
  ///
  /// Collects all entries, sorts them by [CacheEntry.lastAccessedAt] ascending
  /// (oldest first), and removes entries from the front until the count is
  /// within the configured limit. Returns the number of entries removed.
  Future<int> _evictByCount() async {
    final currentLength = await storage.length;
    if (currentLength <= config.maxEntries) return 0;

    final keys = await storage.getAllKeys();
    final entries = <MapEntry<String, CacheEntry>>[];

    for (final key in keys) {
      final entry = await storage.get(key);
      if (entry != null) {
        entries.add(MapEntry(key, entry));
      }
    }

    entries.sort(
      (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt),
    );

    final toRemove = currentLength - config.maxEntries;
    int count = 0;

    for (int i = 0; i < toRemove && i < entries.length; i++) {
      await storage.remove(entries[i].key);
      count++;
    }

    return count;
  }

  /// Stage 3: Removes least recently used entries when the total size exceeds
  /// [CacheConfig.maxSizeBytes].
  ///
  /// Collects all entries, sorts them by [CacheEntry.lastAccessedAt] ascending
  /// (oldest first), and removes entries from the front — subtracting each
  /// entry's size — until the total size drops to or below the configured
  /// limit. Returns the number of entries removed.
  Future<int> _evictBySize() async {
    int currentSize = await storage.sizeInBytes;
    if (currentSize <= config.maxSizeBytes) return 0;

    final keys = await storage.getAllKeys();
    final entries = <MapEntry<String, CacheEntry>>[];

    for (final key in keys) {
      final entry = await storage.get(key);
      if (entry != null) {
        entries.add(MapEntry(key, entry));
      }
    }

    entries.sort(
      (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt),
    );

    int count = 0;

    for (final entry in entries) {
      if (currentSize <= config.maxSizeBytes) break;

      final entrySize = utf8.encode(entry.value.data).length;
      await storage.remove(entry.key);
      currentSize -= entrySize;
      count++;
    }

    return count;
  }
}
