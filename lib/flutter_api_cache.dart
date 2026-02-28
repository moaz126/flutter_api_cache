/// A powerful, lightweight API response caching solution for Flutter with TTL,
/// offline-first support, stale-while-revalidate, and Dio interceptor.
library;

// Core
export 'src/core/cache_config.dart';
export 'src/core/cache_entry.dart';
export 'src/core/cache_policy.dart';
export 'src/core/cache_strategy.dart';

// Storage
export 'src/storage/cache_storage.dart';
export 'src/storage/hive_cache_storage.dart';
export 'src/storage/memory_cache_storage.dart';

// Managers
export 'src/managers/cache_manager.dart';
export 'src/managers/eviction_manager.dart';

// Interceptor
export 'src/interceptor/cache_interceptor.dart';

// Utils
export 'src/utils/cache_key_builder.dart';
export 'src/utils/connectivity_checker.dart';
