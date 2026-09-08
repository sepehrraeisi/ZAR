import 'package:flutter/foundation.dart';

/// Buffers a notification destination until the application shell is ready.
///
/// Native notification callbacks can arrive before workspace/auth/bootstrap has
/// installed navigation. Dropping that callback would make tapping an iPhone
/// notification appear to do nothing, so the latest destination is retained
/// and delivered exactly once when a handler becomes available.
class RecordTapBuffer {
  ValueChanged<String>? _handler;
  String? _pendingRecordId;

  String? get pendingRecordId => _pendingRecordId;
  bool get hasHandler => _handler != null;

  void setHandler(ValueChanged<String>? handler) {
    _handler = handler;
    if (handler == null) return;

    final pending = _pendingRecordId;
    if (pending == null) return;

    _pendingRecordId = null;
    handler(pending);
  }

  void add(String recordId) {
    if (recordId.isEmpty) return;
    final handler = _handler;
    if (handler != null) {
      handler(recordId);
      return;
    }

    // Only the latest destination matters for app navigation. This also avoids
    // opening several stale sheets after a long bootstrap.
    _pendingRecordId = recordId;
  }

  void clear() {
    _pendingRecordId = null;
  }
}
