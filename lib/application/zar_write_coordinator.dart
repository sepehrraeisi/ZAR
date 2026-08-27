/// Coordinates user-initiated persistence so UI code can distinguish a
/// confirmed write from a failed one before dismissing sheets or dialogs.
///
/// A business action is only successful after the repository Future completes.
/// Callers should keep the current interaction surface open when [succeeded] is
/// false and may expose [retry] to the user.
class ZarWriteResult {
  const ZarWriteResult._({required this.succeeded, this.error});

  const ZarWriteResult.success() : this._(succeeded: true);

  const ZarWriteResult.failure(Object error)
      : this._(succeeded: false, error: error);

  final bool succeeded;
  final Object? error;
}

class ZarWriteCoordinator {
  bool _inFlight = false;

  bool get inFlight => _inFlight;

  Future<ZarWriteResult> run(Future<void> Function() operation) async {
    if (_inFlight) {
      return ZarWriteResult.failure(const ZarWriteAlreadyInFlight());
    }

    _inFlight = true;
    try {
      await operation();
      return const ZarWriteResult.success();
    } catch (error) {
      return ZarWriteResult.failure(error);
    } finally {
      _inFlight = false;
    }
  }
}

class ZarWriteAlreadyInFlight implements Exception {
  const ZarWriteAlreadyInFlight();

  @override
  String toString() => 'A persistence write is already in progress.';
}
