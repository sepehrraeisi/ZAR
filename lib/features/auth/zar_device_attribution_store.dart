import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../domain/zar_domain_models.dart';
import 'zar_token_store.dart';

/// Keystore-backed installation id + editable device label (ADR Option B).
class ZarDeviceAttributionStore {
  ZarDeviceAttributionStore({ZarTokenStore? tokenStore})
    : _tokens = tokenStore ?? ZarSecureTokenStore();

  static const _rawIdKey = 'zar.device.installation_raw';
  static const _labelKey = 'zar.device.label';

  final ZarTokenStore _tokens;

  /// Returns the public [ZarDeviceRef] (short hash id + label).
  Future<ZarDeviceRef> current() async {
    final raw = await _ensureRawInstallationId();
    final label = await _ensureLabel();
    return ZarDeviceRef(
      installationId: _opaqueHash(raw),
      label: label,
    );
  }

  Future<String> readLabel() async => _ensureLabel();

  Future<void> writeLabel(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const FormatException('Device label must be 1–80 characters.');
    }
    await _tokens.write(_labelKey, trimmed);
  }

  Future<String> _ensureRawInstallationId() async {
    final existing = await _tokens.read(_rawIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final created = _newRawId();
    await _tokens.write(_rawIdKey, created);
    return created;
  }

  Future<String> _ensureLabel() async {
    final existing = await _tokens.read(_labelKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final label = _defaultLabel();
    await _tokens.write(_labelKey, label);
    return label;
  }

  String _opaqueHash(String raw) {
    final digest = sha256.convert(utf8.encode('zar.device.v1:$raw'));
    return digest.toString().substring(0, 16);
  }

  String _newRawId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _defaultLabel() {
    if (kIsWeb) return 'وب';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
    } catch (_) {}
    return 'دستگاه';
  }
}
