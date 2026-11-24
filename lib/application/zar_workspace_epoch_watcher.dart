import 'dart:async';

import '../data/zar_domain_repository.dart';

/// Watches [ZarWorkspaceEpochSource] for remote workspace mutations
/// (ZAR-DATA-002).
///
/// Prefers optional SSE push signals when available, and always keeps a
/// periodic epoch poll as the resilience path (proxy buffering / disconnects).
class ZarWorkspaceEpochWatcher {
  ZarWorkspaceEpochWatcher({
    required ZarWorkspaceEpochSource source,
    required Future<void> Function() onRemoteChange,
    this.interval = const Duration(seconds: 15),
    Stream<void>? pushSignals,
    bool Function()? isPaused,
  }) : _source = source,
       _onRemoteChange = onRemoteChange,
       _pushSignals = pushSignals,
       _isPaused = isPaused ?? (() => false);

  final ZarWorkspaceEpochSource _source;
  final Future<void> Function() _onRemoteChange;
  final Stream<void>? _pushSignals;
  final Duration interval;
  final bool Function() _isPaused;

  Timer? _timer;
  StreamSubscription<void>? _pushSub;
  bool _checking = false;
  bool _disposed = false;

  bool get isRunning => _timer != null;

  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) {
      unawaited(checkNow());
    });
    _pushSub ??= _pushSignals?.listen((_) {
      unawaited(checkNow());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(_pushSub?.cancel());
    _pushSub = null;
  }

  void dispose() {
    _disposed = true;
    stop();
    _source.closeRemoteChangeSignals();
  }

  /// Probe once (poll tick, SSE signal, or app resume). No-ops while paused.
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
