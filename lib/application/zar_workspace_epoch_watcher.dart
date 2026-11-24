import 'dart:async';

import '../data/zar_domain_repository.dart';

/// Polls [ZarWorkspaceEpochSource.peekRemoteEpoch] and invokes [onRemoteChange]
/// when the server epoch advances past the last snapshot epoch (ZAR-DATA-002).
///
/// Full PocketBase SSE is deferred; this uses the existing workspace Record
/// API so another device's writes surface without waiting for a conflict.
class ZarWorkspaceEpochWatcher {
  ZarWorkspaceEpochWatcher({
    required ZarWorkspaceEpochSource source,
    required Future<void> Function() onRemoteChange,
    this.interval = const Duration(seconds: 15),
    bool Function()? isPaused,
  }) : _source = source,
       _onRemoteChange = onRemoteChange,
       _isPaused = isPaused ?? (() => false);

  final ZarWorkspaceEpochSource _source;
  final Future<void> Function() _onRemoteChange;
  final Duration interval;
  final bool Function() _isPaused;

  Timer? _timer;
  bool _checking = false;
  bool _disposed = false;

  bool get isRunning => _timer != null;

  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) {
      unawaited(checkNow());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    stop();
  }

  /// Probe once (poll tick or app resume). No-ops while paused or in-flight.
  Future<bool> checkNow() async {
    if (_disposed || _checking || _isPaused()) return false;
    final known = _source.lastKnownEpoch;
    if (known == null) return false;
    _checking = true;
    try {
      final remote = await _source.peekRemoteEpoch();
      if (_disposed || remote == null || remote <= known) return false;
      await _onRemoteChange();
      return true;
    } finally {
      _checking = false;
    }
  }
}
