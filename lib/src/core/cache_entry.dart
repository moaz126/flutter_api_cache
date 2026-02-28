/// Represents a single cached API response with metadata for expiration,
/// access tracking, and serialization.
///
/// Each [CacheEntry] stores the response body, status code, optional headers,
/// and timing information used to determine freshness and support LRU eviction.
class CacheEntry {
  /// Creates a new [CacheEntry].
  ///
  /// [data], [statusCode], [createdAt], and [ttlSeconds] are required.
  /// [headers] is optional and defaults to `null`.
  /// [accessCount] defaults to `0`.
  /// [lastAccessedAt] defaults to [createdAt] if not provided.
  CacheEntry({
    required this.data,
    required this.statusCode,
    this.headers,
    required this.createdAt,
    required this.ttlSeconds,
    this.accessCount = 0,
    DateTime? lastAccessedAt,
  }) : lastAccessedAt = lastAccessedAt ?? createdAt;

  /// Deserializes a [CacheEntry] from a JSON-compatible map.
  ///
  /// Parses ISO 8601 date strings for [createdAt] and [lastAccessedAt].
  /// Handles a missing or `null` [accessCount] gracefully by defaulting to `0`.
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'] as String,
      statusCode: json['statusCode'] as int,
      headers: json['headers'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      ttlSeconds: json['ttlSeconds'] as int,
      accessCount: (json['accessCount'] as int?) ?? 0,
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.parse(json['lastAccessedAt'] as String)
          : null,
    );
  }

  /// The cached response body as a JSON string.
  final String data;

  /// The HTTP status code of the original response.
  final int statusCode;

  /// The response headers stored as a JSON string, or `null` if not captured.
  final String? headers;

  /// The timestamp when this entry was first cached.
  final DateTime createdAt;

  /// Time-to-live in seconds — how long this entry remains valid.
  final int ttlSeconds;

  /// The number of times this entry has been accessed, used for LRU eviction.
  int accessCount;

  /// The last time this entry was accessed. Defaults to [createdAt] if not
  /// provided.
  DateTime lastAccessedAt;

  /// Whether this cache entry has expired.
  ///
  /// Returns `true` if the current time is past [createdAt] plus [ttlSeconds].
  bool get isExpired {
    final expiresAt = createdAt.add(Duration(seconds: ttlSeconds));
    return DateTime.now().isAfter(expiresAt);
  }

  /// The remaining seconds until this entry expires.
  ///
  /// Returns `0` if the entry is already expired.
  int get remainingTtl {
    final expiresAt = createdAt.add(Duration(seconds: ttlSeconds));
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Marks this entry as accessed by incrementing [accessCount] and updating
  /// [lastAccessedAt] to the current time.
  void markAccessed() {
    accessCount++;
    lastAccessedAt = DateTime.now();
  }

  /// Serializes this [CacheEntry] to a JSON-compatible map.
  ///
  /// [DateTime] fields are converted to ISO 8601 strings.
  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'statusCode': statusCode,
      'headers': headers,
      'createdAt': createdAt.toIso8601String(),
      'ttlSeconds': ttlSeconds,
      'accessCount': accessCount,
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
    };
  }
}
