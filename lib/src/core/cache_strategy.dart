/// Defines the caching strategy used when making API requests.
///
/// Each strategy controls how cached data and network responses are
/// prioritized, allowing fine-grained control over performance, freshness,
/// and offline behavior.
enum CacheStrategy {
  /// Return cached data first. If the cache is not available or expired,
  /// fetch from the network and cache the response.
  cacheFirst,

  /// Always fetch from the network first. If the network call fails,
  /// use cached data as a fallback.
  networkFirst,

  /// Return cached data immediately even if stale, then fetch fresh data
  /// from the network in the background and update the cache.
  staleWhileRevalidate,

  /// Always fetch from the network. Never use or store cache.
  networkOnly,

  /// Only return cached data. Never make any network call.
  cacheOnly,
}
