import 'dart:collection';
import 'dart:convert';

import '../core/cache_entry.dart';
import 'cache_storage.dart';

/// An in-memory LRU (Least Recently Used) cache implementation of
/// [CacheStorage].
///
/// Uses a [LinkedHashMap] to maintain insertion order — the first key is the
/// oldest / least recently used entry and the last key is the most recently
/// used. When the cache exceeds [maxEntries], the least recently used entries
/// are evicted automatically.
class MemoryCacheStorage implements CacheStorage {
  /// Creates a new [MemoryCacheStorage] with an optional [maxEntries] limit.
  MemoryCacheStorage({this.maxEntries = 100});

  /// Maximum number of entries this in-memory cache will hold.
  ///
  /// When exceeded, the least recently used entries are removed to make room.
  /// Defaults to `100`.
  final int maxEntries;

  /// The underlying ordered map storing cache entries.
  final LinkedHashMap<String, CacheEntry> _cache =
      LinkedHashMap<String, CacheEntry>();

  /// Initializes the in-memory storage.
  ///
  /// No setup is required for in-memory storage, so this is a no-op.
  @override
  Future<void> init() async {}

  /// Retrieves a cached entry by its [key].
  ///
  /// If the key exists the entry is moved to the end of the map (marking it
  /// as most recently used), its access metadata is updated via
  /// [CacheEntry.markAccessed], and the entry is returned.
  ///
  /// Returns `null` if [key] does not exist.
  @override
  Future<CacheEntry?> get(String key) async {
    if (!_cache.containsKey(key)) return null;

    final entry = _cache.remove(key)!;
    entry.markAccessed();
    _cache[key] = entry;
    return entry;
  }

  /// Stores a [CacheEntry] with the given [key].
  ///
  /// If [key] already exists it is removed first so that the re-inserted
  /// entry is placed at the end (most recently used position). If the cache
  /// is at capacity, the least recently used entries are evicted until there
  /// is room.
  @override
  Future<void> put(String key, CacheEntry entry) async {
    _cache.remove(key);

    while (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = entry;
  }

  /// Removes the cache entry associated with [key].
  ///
  /// If [key] does not exist this is a no-op.
  @override
  Future<void> remove(String key) async {
    _cache.remove(key);
  }

  /// Returns `true` if an entry with the given [key] exists in the cache.
  @override
  Future<bool> containsKey(String key) async {
    return _cache.containsKey(key);
  }

  /// Returns a list of all cache keys currently stored.
  @override
  Future<List<String>> getAllKeys() async {
    return _cache.keys.toList();
  }

  /// The total number of entries currently in the in-memory cache.
  @override
  Future<int> get length async => _cache.length;

  /// The approximate total size of all cached data in bytes.
  ///
  /// Calculated by summing the UTF-8 encoded byte length of each entry's
  /// [CacheEntry.data] field.
  @override
  Future<int> get sizeInBytes async {
    int total = 0;
    for (final entry in _cache.values) {
      total += utf8.encode(entry.data).length;
    }
    return total;
  }

  /// Removes all entries from the in-memory cache.
  @override
  Future<void> clear() async {
    _cache.clear();
  }

  /// Closes the in-memory storage by clearing all entries.
  ///
  /// After calling this method no further operations should be performed on
  /// this instance.
  @override
  Future<void> close() async {
    _cache.clear();
  }
}
