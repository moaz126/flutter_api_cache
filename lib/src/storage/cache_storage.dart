import '../core/cache_entry.dart';

/// Abstract interface for all cache storage implementations.
///
/// Any storage backend — such as in-memory, Hive-based, or a custom
/// implementation — must implement this interface to be used by the cache
/// manager.
///
/// Callers must invoke [init] before performing any other operations.
abstract class CacheStorage {
  /// Initializes the storage backend.
  ///
  /// Must be called once before any other operations such as [get], [put],
  /// or [remove]. Implementations may use this to open database connections,
  /// allocate buffers, or perform other setup work.
  Future<void> init();

  /// Retrieves a cached entry by its [key].
  ///
  /// Returns the [CacheEntry] associated with [key], or `null` if no entry
  /// exists for that key.
  Future<CacheEntry?> get(String key);

  /// Stores a [CacheEntry] with the given [key].
  ///
  /// If an entry with the same [key] already exists it will be overwritten.
  Future<void> put(String key, CacheEntry entry);

  /// Removes the cache entry associated with [key].
  ///
  /// If [key] does not exist in storage this is a no-op.
  Future<void> remove(String key);

  /// Checks whether an entry with the given [key] exists in storage.
  ///
  /// Returns `true` if the key is present, `false` otherwise.
  Future<bool> containsKey(String key);

  /// Returns a list of all cache keys currently stored.
  ///
  /// The returned list may be empty if no entries are stored.
  Future<List<String>> getAllKeys();

  /// The total number of entries currently in storage.
  Future<int> get length;

  /// The approximate total size of all cached data in bytes.
  Future<int> get sizeInBytes;

  /// Removes all entries from the storage.
  Future<void> clear();

  /// Closes the storage backend and releases any held resources.
  ///
  /// After calling [close], no further operations should be performed on
  /// this instance.
  Future<void> close();
}
