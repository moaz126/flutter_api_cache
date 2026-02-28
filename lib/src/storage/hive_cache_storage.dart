import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../core/cache_entry.dart';
import 'cache_storage.dart';

/// Persistent disk-based cache storage implementation using Hive.
///
/// [HiveCacheStorage] stores each [CacheEntry] as a JSON string inside a
/// Hive [Box<String>]. This provides fast key-value persistence that survives
/// app restarts and works well on all Flutter-supported platforms.
///
/// Call [init] before performing any other operations to ensure the Hive
/// backend is fully initialized and the box is open.
class HiveCacheStorage implements CacheStorage {
  /// Creates a new [HiveCacheStorage] with an optional [boxName].
  HiveCacheStorage({this.boxName = 'flutter_api_cache'});

  /// The Hive box name used for storage.
  ///
  /// Defaults to `'flutter_api_cache'`.
  final String boxName;

  /// The underlying Hive box instance.
  ///
  /// Initialized lazily in [init].
  late Box<String> _box;

  /// Initializes the Hive backend and opens the storage box.
  ///
  /// Must be called once before any other operations. Calls
  /// `Hive.initFlutter()` and then opens a [Box<String>] with [boxName].
  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(boxName);
  }

  /// Retrieves a cached entry by its [key].
  ///
  /// If the key exists the stored JSON string is decoded into a [CacheEntry],
  /// its access metadata is updated via [CacheEntry.markAccessed], and the
  /// updated entry is persisted back to the box before being returned.
  ///
  /// Returns `null` if [key] does not exist or if the stored value is
  /// corrupted (in which case the corrupted entry is deleted).
  @override
  Future<CacheEntry?> get(String key) async {
    final value = _box.get(key);
    if (value == null) return null;

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(json);
      entry.markAccessed();
      await _box.put(key, jsonEncode(entry.toJson()));
      return entry;
    } catch (_) {
      await _box.delete(key);
      return null;
    }
  }

  /// Stores a [CacheEntry] with the given [key].
  ///
  /// The entry is serialized to a JSON string before being written to the
  /// Hive box. If [key] already exists it will be overwritten.
  @override
  Future<void> put(String key, CacheEntry entry) async {
    final jsonString = jsonEncode(entry.toJson());
    await _box.put(key, jsonString);
  }

  /// Removes the cache entry associated with [key].
  ///
  /// If [key] does not exist this is a no-op.
  @override
  Future<void> remove(String key) async {
    await _box.delete(key);
  }

  /// Returns `true` if an entry with the given [key] exists in the box.
  @override
  Future<bool> containsKey(String key) async {
    return _box.containsKey(key);
  }

  /// Returns a list of all cache keys currently stored in the Hive box.
  @override
  Future<List<String>> getAllKeys() async {
    return _box.keys.cast<String>().toList();
  }

  /// The total number of entries currently stored in the Hive box.
  @override
  Future<int> get length async => _box.length;

  /// The approximate total size of all cached data in bytes.
  ///
  /// Calculated by summing the UTF-8 encoded byte length of each stored
  /// JSON string value.
  @override
  Future<int> get sizeInBytes async {
    int total = 0;
    for (final value in _box.values) {
      total += utf8.encode(value).length;
    }
    return total;
  }

  /// Removes all entries from the Hive box.
  @override
  Future<void> clear() async {
    await _box.clear();
  }

  /// Closes the Hive box and releases any held resources.
  ///
  /// After calling this method no further operations should be performed on
  /// this instance.
  @override
  Future<void> close() async {
    await _box.close();
  }
}
