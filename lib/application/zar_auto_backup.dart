import 'dart:io';

import 'zar_backup_manager.dart';

/// Silent rolling local backups of the whole business snapshot.
///
/// Every time [runIfNeeded] runs and the newest backup is older than
/// [minInterval], it writes a portable JSON V7 backup into [directory] and
/// prunes the oldest files beyond [keep]. Failures never propagate — a backup
/// problem must never block the app — they are reported through [onError].
class ZarAutoBackupCoordinator {
  ZarAutoBackupCoordinator({
    required ZarBackupManager backupManager,
    required Directory directory,
    int keep = 10,
    this.minInterval = const Duration(hours: 12),
    DateTime Function()? clock,
    this.onError,
  }) : _backupManager = backupManager,
       _directory = directory,
       _keep = keep < 1 ? 1 : keep,
       _clock = clock ?? DateTime.now;

  final ZarBackupManager _backupManager;
  final Directory _directory;
  final int _keep;
  final Duration minInterval;
  final DateTime Function() _clock;
  final void Function(Object error)? onError;

  static const _prefix = 'zar-auto-backup-';
  static const _extension = '.json';

  /// Returns the written backup file, or `null` when nothing was due.
  Future<File?> runIfNeeded() async {
    try {
      await _directory.create(recursive: true);
      final existing = await _listBackups();
      final now = _clock();
      if (existing.isNotEmpty) {
        final newest = existing.last;
        final newestAt = _parseStamp(newest.path);
        if (newestAt != null && now.difference(newestAt) < minInterval) {
          await _prune(existing);
          return null;
        }
      }
      final json = await _backupManager.createJson();
      final file = File(
        '${_directory.path}${Platform.pathSeparator}'
        '$_prefix${_stamp(now)}$_extension',
      );
      await file.writeAsString(json, flush: true);
      await _prune(await _listBackups());
      return file;
    } catch (error) {
      onError?.call(error);
      return null;
    }
  }

  Future<List<File>> _listBackups() async {
    final entries = await _directory.list().toList();
    return entries
        .whereType<File>()
        .where(
          (file) =>
              file.path.contains(_prefix) && file.path.endsWith(_extension),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  Future<void> _prune(List<File> backups) async {
    if (backups.length <= _keep) return;
    for (final file in backups.take(backups.length - _keep)) {
      try {
        await file.delete();
      } catch (error) {
        onError?.call(error);
      }
    }
  }

  /// UTC timestamp, lexicographically sortable: `20260921T104500Z`.
  String _stamp(DateTime at) {
    final utc = at.toUtc();
    String pad(int value, [int width = 2]) =>
        value.toString().padLeft(width, '0');
    return '${utc.year}${pad(utc.month)}${pad(utc.day)}'
        'T${pad(utc.hour)}${pad(utc.minute)}${pad(utc.second)}Z';
  }

  /// Filesystem mtimes are real-clock values and would make the interval
  /// check nondeterministic under an injected clock, so the embedded UTC
  /// stamp inside the filename is the single source of truth.
  DateTime? _parseStamp(String path) {
    final name = path.split(Platform.pathSeparator).last;
    if (!name.startsWith(_prefix) || !name.endsWith(_extension)) {
      return null;
    }
    final stamp = name
        .substring(_prefix.length, name.length - _extension.length)
        .toUpperCase();
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$')
        .firstMatch(stamp);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}
