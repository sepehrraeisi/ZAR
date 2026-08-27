import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/application/zar_write_coordinator.dart';

void main() {
  test('reports success only after persistence future completes', () async {
    final coordinator = ZarWriteCoordinator();
    final gate = Completer<void>();

    final future = coordinator.run(() => gate.future);
    expect(coordinator.inFlight, isTrue);

    gate.complete();
    final result = await future;

    expect(result.succeeded, isTrue);
    expect(result.error, isNull);
    expect(result.canRetry, isFalse);
    expect(coordinator.inFlight, isFalse);
  });

  test('reports failure and preserves the operation for retry UX', () async {
    final coordinator = ZarWriteCoordinator();
    final error = StateError('network unavailable');
    var attempts = 0;

    final result = await coordinator.run(() async {
      attempts += 1;
      if (attempts == 1) throw error;
    });

    expect(result.succeeded, isFalse);
    expect(result.error, same(error));
    expect(result.canRetry, isTrue);
    expect(coordinator.hasRetryableFailure, isTrue);

    final retried = await result.retry!.call();
    expect(retried.succeeded, isTrue);
    expect(attempts, 2);
    expect(coordinator.hasRetryableFailure, isFalse);
  });

  test('rejects a second concurrent write without replacing retry state', () async {
    final coordinator = ZarWriteCoordinator();
    final gate = Completer<void>();

    final first = coordinator.run(() => gate.future);
    final second = await coordinator.run(() async {});

    expect(second.succeeded, isFalse);
    expect(second.error, isA<ZarWriteAlreadyInFlight>());
    expect(second.canRetry, isFalse);

    gate.complete();
    expect((await first).succeeded, isTrue);
  });

  test('retry without a previous failed write fails safely', () async {
    final coordinator = ZarWriteCoordinator();

    final result = await coordinator.retryLastFailure();

    expect(result.succeeded, isFalse);
    expect(result.error, isA<ZarNoFailedWrite>());
    expect(result.canRetry, isFalse);
  });
}
