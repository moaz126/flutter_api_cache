## 0.0.1

* Initial release
* 5 caching strategies: cacheFirst, networkFirst, staleWhileRevalidate, networkOnly, cacheOnly
* Dio interceptor for automatic request/response caching
* Dual-layer caching: in-memory LRU + persistent disk storage (Hive)
* Configurable TTL per endpoint and per request
* Offline-first support with automatic cache fallback on network errors
* Stale-while-revalidate with background refresh and callback notification
* Smart cache key generation using MD5 hashing of method, URL, query params, and body
* LRU eviction by entry count, total size, and TTL expiry
* Per-request policy via Dio request extras
* URL pattern-based policy mapping
* Force refresh support to bypass cache
* Cache statistics (entry count, size, memory entries)
* Manual cache invalidation (single entry, pattern-based, clear all)
* Pluggable storage backend via CacheStorage abstract interface
