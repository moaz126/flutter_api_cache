import 'package:connectivity_plus/connectivity_plus.dart';

/// Provides a simple way to check whether the device is online or offline.
///
/// Used by the cache manager to decide whether to attempt network calls or
/// fall back to cached data. Wraps the `connectivity_plus` package and
/// exposes both a one-shot check and a reactive stream.
class ConnectivityChecker {
  /// Creates a new [ConnectivityChecker].
  ///
  /// An optional [connectivity] instance can be injected for testing purposes
  /// (e.g. passing a mock). If omitted a default [Connectivity] instance is
  /// created.
  ConnectivityChecker({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// The underlying [Connectivity] instance from `connectivity_plus`.
  final Connectivity _connectivity;

  /// Whether the device currently has network connectivity.
  ///
  /// Returns `true` if the device has any form of connectivity (Wi-Fi,
  /// mobile, ethernet, etc.) and `false` if the device is offline
  /// ([ConnectivityResult.none]).
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// A reactive stream that emits `true` when the device goes online and
  /// `false` when it goes offline.
  ///
  /// Each emission corresponds to a connectivity change event from the
  /// underlying platform.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none),
    );
  }
}
