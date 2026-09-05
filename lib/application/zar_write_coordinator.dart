typedef ZarWriteOperation = Future<void> Function();

/// Coordinates user-initiated persistence so UI code can distinguish a
/// confirmed write from a failed one before dismissing sheets or dialogs.
///
/// A business action is only successful after the repository Future completes.
/// Callers should keep the current interaction surface open when [succeeded] is
/// false and may expose [retry] to the user.
class ZarWriteResult {
  const ZarWriteResult._({
    required this.succeeded,
    this.error,
    this.retry,
  });

  const ZarWriteResult.success() : this._(succeeded: true);

  const ZarWriteResult.failure(
    Object error, {
    Future<ZarWriteResult> Function()? retry,
  }) : this._(succeeded: false, error: error, retry: retry);

  final bool succeeded;
  final Object? error;
  final Future<ZarWriteResult> Function()? retry;

  bool get canRetry => retry != null;
}

class ZarWriteCoordinator {
  bool _inFlight = false;
  ZarWriteOperation? _lastFailedOperation;

  bool get inFlight => _inFlight;
  bool get hasRetryableFailure => _lastFailedOperation != null;

  Future<ZarWriteResult> run(ZarWriteOperation operation) async {
    if (_inFlight) {
      return const ZarWriteResult.failure(ZarWriteAlreadyInFlight());
    }

    _inFlight = true;
    try {
      await operation();
      _lastFailedOperation = null;
      return const ZarWriteResult.success();
    } catch (error) {
      _lastFailedOperation = operation;
      return ZarWriteResult.failure(
        error,
        retry: retryLastFailure,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Replays only the most recent failed persistence operation.
  ///
  /// A successful retry clears the stored failure. Concurrent retry attempts are
  /// still rejected by the same in-flight guard, preventing duplicate writes.
  Future<ZarWriteResult> retryLastFailure() async {
    final operation = _lastFailedOperation;
    if (operation == null) {
      return const ZarWriteResult.failure(ZarNoFailedWrite());
    }
    return run(operation);
  }

  void clearRetry() {
    _lastFailedOperation = null;
  }
}

class ZarWriteAlreadyInFlight implements Exception {
  const ZarWriteAlreadyInFlight();

  @override
  String toString() => 'A persistence write is already in progress.';
}

class ZarNoFailedWrite implements Exception {
  const ZarNoFailedWrite();

  @override
  String toString() => 'There is no failed persistence write to retry.';
}
