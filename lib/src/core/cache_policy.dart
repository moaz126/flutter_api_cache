import 'cache_strategy.dart';

/// Configures caching behavior for a specific endpoint or group of endpoints.
///
/// A [CachePolicy] combines a [CacheStrategy] with additional parameters such
/// as TTL, allowed HTTP methods, and an optional key suffix to fine-tune how
/// responses are cached and retrieved.
///
/// Use the provided static preset constants for common configurations, or
/// create a custom policy with the constructor.
class CachePolicy {
  /// Creates a new [CachePolicy] with the given configuration.
  ///
  /// All parameters are optional and have sensible defaults.
  const CachePolicy({
    this.strategy = CacheStrategy.cacheFirst,
    this.ttlSeconds = 300,
    this.methods = const ['GET'],
    this.forceRefresh = false,
    this.keySuffix,
  });

  /// The caching strategy to use for this policy.
  ///
  /// Defaults to [CacheStrategy.cacheFirst].
  final CacheStrategy strategy;

  /// Time-to-live in seconds — how long cached responses remain valid.
  ///
  /// Defaults to `300` (5 minutes).
  final int ttlSeconds;

  /// The HTTP methods whose responses should be cached.
  ///
  /// Defaults to `['GET']`.
  final List<String> methods;

  /// Whether to skip the cache and always fetch fresh data from the network.
  ///
  /// Defaults to `false`.
  final bool forceRefresh;

  /// An optional custom suffix appended to the cache key to differentiate
  /// entries for the same URL.
  ///
  /// Useful when the same endpoint returns different data based on context
  /// that isn't captured in the URL alone (e.g. user role, locale).
  final String? keySuffix;

  /// A policy for endpoints that should never be cached, such as
  /// authentication or token-refresh endpoints.
  ///
  /// Uses [CacheStrategy.networkOnly] so every request goes straight to the
  /// network and no response is stored.
  static const CachePolicy none = CachePolicy(
    strategy: CacheStrategy.networkOnly,
  );

  /// The standard default policy.
  ///
  /// Uses [CacheStrategy.cacheFirst] with a 5-minute TTL. Suitable for most
  /// general-purpose API calls.
  static const CachePolicy defaultPolicy = CachePolicy(
    strategy: CacheStrategy.cacheFirst,
    ttlSeconds: 300,
  );

  /// An aggressive caching policy for data that rarely changes, such as
  /// application configuration or feature flags.
  ///
  /// Uses [CacheStrategy.cacheFirst] with a 1-hour TTL.
  static const CachePolicy aggressive = CachePolicy(
    strategy: CacheStrategy.cacheFirst,
    ttlSeconds: 3600,
  );

  /// A stale-while-revalidate policy that returns cached data immediately
  /// — even if stale — while refreshing from the network in the background.
  ///
  /// Uses [CacheStrategy.staleWhileRevalidate] with a 10-minute TTL.
  /// Ideal for feeds, lists, or any data where perceived speed matters more
  /// than absolute freshness.
  static const CachePolicy staleWhileRevalidate = CachePolicy(
    strategy: CacheStrategy.staleWhileRevalidate,
    ttlSeconds: 600,
  );

  /// Returns a copy of this [CachePolicy] with the given fields replaced.
  ///
  /// Any parameter that is not provided retains its current value.
  CachePolicy copyWith({
    CacheStrategy? strategy,
    int? ttlSeconds,
    List<String>? methods,
    bool? forceRefresh,
    String? keySuffix,
  }) {
    return CachePolicy(
      strategy: strategy ?? this.strategy,
      ttlSeconds: ttlSeconds ?? this.ttlSeconds,
      methods: methods ?? this.methods,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      keySuffix: keySuffix ?? this.keySuffix,
    );
  }
}
