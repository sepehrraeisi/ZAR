import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class BackupFileService {
  Future<bool> saveJson({required String fileName, required String contents});
  Future<void> shareJson({required String fileName, required String contents});
  Future<String?> pickJson();
}

class PlatformBackupFileService implements BackupFileService {
  const PlatformBackupFileService();

  static const _jsonGroup = XTypeGroup(
    label: 'ZAR+ JSON backup',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  @override
  Future<bool> saveJson({required String fileName, required String contents}) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final baseName = fileName.toLowerCase().endsWith('.json')
          ? fileName.substring(0, fileName.length - 5)
          : fileName;
      final savedPath = await FileSaver.instance.saveAs(
        name: baseName,
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      return savedPath != null;
    }
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [_jsonGroup],
    );
    if (location == null) return false;
    await XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: fileName,
    ).saveTo(location.path);
    return true;
  }

  @override
  Future<void> shareJson({required String fileName, required String contents}) =>
      SharePlus.instance.share(
        ShareParams(
          text: 'نسخه پشتیبان کامل ZAR+',
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(contents)),
              mimeType: 'application/json',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
        ),
      );

  @override
  Future<String?> pickJson() async {
    final file = await openFile(acceptedTypeGroups: const [_jsonGroup]);
    return file?.readAsString();
  }
}
