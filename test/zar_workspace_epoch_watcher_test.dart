import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/application/zar_workspace_epoch_watcher.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';

class _FakeEpochSource implements ZarWorkspaceEpochSource {
  _FakeEpochSource({this.lastKnownEpoch, this.remote, this.push});

  @override
  int? lastKnownEpoch;
  int? remote;
  StreamController<void>? push;
  int peekCalls = 0;
  int closeCalls = 0;

  @override
  Future<int?> peekRemoteEpoch() async {
    peekCalls += 1;
    return remote;
  }

  @override
  Stream<void>? openRemoteChangeSignals() => push?.stream;

  @override
  void closeRemoteChangeSignals() {
    closeCalls += 1;
  }
}

void main() {
  test('checkNow no-ops before a snapshot epoch is known', () async {
    final source = _FakeEpochSource(lastKnownEpoch: null, remote: 3);
    var changes = 0;
    final watcher = ZarWorkspaceEpochWatcher(
      source: source,
      onRemoteChange: () async {
        changes += 1;
      },
    );
    expect(await watcher.checkNow(), isFalse);
    expect(changes, 0);
    expect(source.peekCalls, 0);
    watcher.dispose();
  });

  test('checkNow no-ops when remote epoch has not advanced', () async {
    final source = _FakeEpochSource(lastKnownEpoch: 4, remote: 4);
    var changes = 0;
    final watcher = ZarWorkspaceEpochWatcher(
      source: source,
      onRemoteChange: () async {
        changes += 1;
      },
    );
    expect(await watcher.checkNow(), isFalse);
    expect(changes, 0);
    expect(source.peekCalls, 1);
    watcher.dispose();
  });

  test('checkNow reloads when remote epoch advances', () async {
    final source = _FakeEpochSource(lastKnownEpoch: 2, remote: 5);
    var changes = 0;
    final watcher = ZarWorkspaceEpochWatcher(
      source: source,
      onRemoteChange: () async {
        changes += 1;
        source.lastKnownEpoch = source.remote;
      },
    );
    expect(await watcher.checkNow(), isTrue);
    expect(changes, 1);
    expect(await watcher.checkNow(), isFalse);
    expect(changes, 1);
    watcher.dispose();
  });

  test('checkNow respects pause and dispose', () async {
    final source = _FakeEpochSource(lastKnownEpoch: 1, remote: 9);
    var paused = true;
    var changes = 0;
    final watcher = ZarWorkspaceEpochWatcher(
      source: source,
      isPaused: () => paused,
      onRemoteChange: () async {
        changes += 1;
      },
    );
    expect(await watcher.checkNow(), isFalse);
    expect(source.peekCalls, 0);
    paused = false;
    expect(await watcher.checkNow(), isTrue);
    expect(changes, 1);
    watcher.dispose();
    expect(source.closeCalls, 1);
    source.remote = 99;
    expect(await watcher.checkNow(), isFalse);
    expect(changes, 1);
  });

  test('push signal triggers an epoch check', () async {
    final push = StreamController<void>.broadcast();
    final source = _FakeEpochSource(
      lastKnownEpoch: 1,
      remote: 2,
      push: push,
    );
    var changes = 0;
    final watcher = ZarWorkspaceEpochWatcher(
      source: source,
      pushSignals: source.openRemoteChangeSignals(),
      onRemoteChange: () async {
        changes += 1;
        source.lastKnownEpoch = source.remote;
      },
    )..start();
    push.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(changes, 1);
    watcher.dispose();
    await push.close();
  });
}
