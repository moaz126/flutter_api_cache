/// Global configuration for the entire cache system.
///
/// A [CacheConfig] defines system-wide defaults such as TTL, size limits,
/// encryption settings, and memory-cache behavior. Pass an instance to the
/// cache manager at initialization; individual endpoints can still override
/// specific values through [CachePolicy].
class CacheConfig {
  /// Creates a new [CacheConfig] with the given settings.
  ///
  /// All parameters are optional and have sensible defaults.
  const CacheConfig({
    this.defaultTtlSeconds = 300,
    this.maxEntries = 500,
    this.maxSizeBytes = 0,
    this.encrypt = false,
    this.encryptionKey,
    this.enableLogging = false,
    this.boxName = 'flutter_api_cache',
    this.useMemoryCache = true,
    this.maxMemoryEntries = 100,
  });

  /// Default time-to-live in seconds applied to all cached entries when no
  /// specific [CachePolicy] overrides it.
  ///
  /// Defaults to `300` (5 minutes).
  final int defaultTtlSeconds;

  /// Maximum number of entries allowed in the cache.
  ///
  /// When this limit is exceeded the eviction manager removes the least
  /// recently used entries. Defaults to `500`.
  final int maxEntries;

  /// Maximum total cache size in bytes.
  ///
  /// A value of `0` means unlimited. When exceeded the eviction manager
  /// removes the least recently used entries until the total size is back
  /// under the limit. Defaults to `0`.
  final int maxSizeBytes;

  /// Whether to encrypt cached data before storing it on disk.
  ///
  /// When set to `true`, [encryptionKey] must also be provided.
  /// Defaults to `false`.
  final bool encrypt;

  /// The encryption key used when [encrypt] is `true`.
  ///
  /// Required if [encrypt] is `true`; otherwise can be `null`.
  final String? encryptionKey;

  /// Whether to log cache operations (store, retrieve, evict) to the console
  /// for debugging purposes.
  ///
  /// Defaults to `false`.
  final bool enableLogging;

  /// The Hive box name used for persistent disk storage.
  ///
  /// Defaults to `'flutter_api_cache'`.
  final String boxName;

  /// Whether to enable a dual-layer caching system with both an in-memory
  /// LRU cache and disk cache for faster access.
  ///
  /// Defaults to `true`.
  final bool useMemoryCache;

  /// Maximum number of entries to keep in the in-memory LRU cache.
  ///
  /// Only applies when [useMemoryCache] is `true`. Defaults to `100`.
  final int maxMemoryEntries;
}
