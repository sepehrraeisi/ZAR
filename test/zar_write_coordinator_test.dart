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
    expect(coordinator.inFlight, isFalse);
  });

  test('reports failure and preserves the error for retry UX', () async {
    final coordinator = ZarWriteCoordinator();
    final error = StateError('network unavailable');

    final result = await coordinator.run(() async => throw error);

    expect(result.succeeded, isFalse);
    expect(result.error, same(error));
    expect(coordinator.inFlight, isFalse);
  });

  test('rejects a second concurrent write', () async {
    final coordinator = ZarWriteCoordinator();
    final gate = Completer<void>();

    final first = coordinator.run(() => gate.future);
    final second = await coordinator.run(() async {});

    expect(second.succeeded, isFalse);
    expect(second.error, isA<ZarWriteAlreadyInFlight>());

    gate.complete();
    expect((await first).succeeded, isTrue);
  });
}
