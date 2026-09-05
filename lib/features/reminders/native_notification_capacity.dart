/// Pure scheduling policy for platforms that cap pending local notifications.
///
/// iOS keeps only a bounded number of pending local notifications. ZAR+ keeps
/// the nearest reminders and leaves the authoritative reminder plans in memory/
/// repository state so the native queue can be refreshed as records change.
class NativeReminderCandidate<T> {
  const NativeReminderCandidate({
    required this.value,
    required this.fireAt,
  });

  final T value;
  final DateTime fireAt;
}

class NativeNotificationCapacityPolicy {
  const NativeNotificationCapacityPolicy({
    this.iosPendingLimit = 60,
  });

  /// Apple documents a finite pending-notification queue. We deliberately keep
  /// a small safety margin rather than trying to occupy every available slot.
  final int iosPendingLimit;

  List<NativeReminderCandidate<T>> earliestForIos<T>(
    Iterable<NativeReminderCandidate<T>> candidates, {
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).toUtc();
    final sorted = candidates
        .where((candidate) => candidate.fireAt.toUtc().isAfter(cutoff))
        .toList(growable: false)
      ..sort((a, b) => a.fireAt.compareTo(b.fireAt));

    if (iosPendingLimit <= 0) return <NativeReminderCandidate<T>>[];
    if (sorted.length <= iosPendingLimit) return sorted;
    return sorted.take(iosPendingLimit).toList(growable: false);
  }
}
