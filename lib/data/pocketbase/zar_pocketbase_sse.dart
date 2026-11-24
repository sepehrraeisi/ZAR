import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'zar_pocketbase_client.dart';

/// One Server-Sent Event frame from PocketBase `/api/realtime`.
class ZarPocketBaseSseEvent {
  const ZarPocketBaseSseEvent({this.id, this.event, this.data});

  final String? id;
  final String? event;
  final String? data;
}

/// Parses incremental SSE text into complete event frames.
class ZarPocketBaseSseParser {
  final StringBuffer _buffer = StringBuffer();

  /// Feeds [chunk] and returns any completed events.
  List<ZarPocketBaseSseEvent> add(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();
    final parts = text.split('\n\n');
    _buffer
      ..clear()
      ..write(parts.isEmpty ? '' : parts.removeLast());
    final events = <ZarPocketBaseSseEvent>[];
    for (final part in parts) {
      final event = _parseFrame(part);
      if (event != null) events.add(event);
    }
    return events;
  }

  static ZarPocketBaseSseEvent? _parseFrame(String frame) {
    if (frame.trim().isEmpty) return null;
    String? id;
    String? event;
    final dataLines = <String>[];
    for (final rawLine in frame.split('\n')) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      if (line.isEmpty || line.startsWith(':')) continue;
      final sep = line.indexOf(':');
      final field = sep < 0 ? line : line.substring(0, sep);
      var value = sep < 0 ? '' : line.substring(sep + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'id':
          id = value;
        case 'event':
          event = value;
        case 'data':
          dataLines.add(value);
      }
    }
    if (id == null && event == null && dataLines.isEmpty) return null;
    return ZarPocketBaseSseEvent(
      id: id,
      event: event,
      data: dataLines.isEmpty ? null : dataLines.join('\n'),
    );
  }
}

/// Long-lived PocketBase realtime subscription for one workspace record.
///
/// Flow: GET `/api/realtime` → `PB_CONNECT` → POST subscriptions with auth →
/// emit on matching topic events. Poll remains the resilience path.
class ZarPocketBaseWorkspaceRealtime {
  ZarPocketBaseWorkspaceRealtime({
    required ZarPocketBaseClient client,
    required String workspaceId,
    http.Client? httpClient,
    Duration reconnectDelay = const Duration(seconds: 3),
  }) : _client = client,
       _workspaceId = workspaceId,
       _http = httpClient ?? client.httpClient,
       _reconnectDelay = reconnectDelay;

  final ZarPocketBaseClient _client;
  final String _workspaceId;
  final http.Client _http;
  final Duration _reconnectDelay;

  final StreamController<void> _signals = StreamController<void>.broadcast();
  StreamSubscription<List<int>>? _bytesSub;
  bool _running = false;
  bool _disposed = false;
  int _generation = 0;

  Stream<void> get signals => _signals.stream;

  String get _topic => 'zar_workspaces/$_workspaceId';

  Future<void> start() async {
    if (_disposed || _running) return;
    _running = true;
    unawaited(_runLoop());
  }

  Future<void> stop() async {
    _running = false;
    _generation++;
    await _bytesSub?.cancel();
    _bytesSub = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _signals.close();
  }

  Future<void> _runLoop() async {
    while (_running && !_disposed) {
      final generation = ++_generation;
      try {
        await _connectOnce(generation);
      } catch (_) {
        // Transport / protocol failures fall back to the epoch poller.
      }
      if (!_running || _disposed || generation != _generation) return;
      await Future<void>.delayed(_reconnectDelay);
    }
  }

  Future<void> _connectOnce(int generation) async {
    final request = http.Request('GET', Uri.parse('${_client.baseUrl}/api/realtime'))
      ..headers.addAll({
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      });
    final response = await _http.send(request);
    if (generation != _generation || !_running || _disposed) {
      await response.stream.drain<void>();
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw ZarPocketBaseException(
        'PocketBase realtime connect failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final parser = ZarPocketBaseSseParser();
    final connected = Completer<String>();
    _bytesSub = response.stream.listen(
      (chunk) {
        if (generation != _generation || !_running || _disposed) return;
        final text = utf8.decode(chunk, allowMalformed: true);
        for (final event in parser.add(text)) {
          _handleEvent(event, connected);
        }
      },
      onError: (_) {
        if (!connected.isCompleted) {
          connected.completeError(
            const ZarPocketBaseTransportException('realtime stream error'),
          );
        }
      },
      onDone: () {
        if (!connected.isCompleted) {
          connected.completeError(
            const ZarPocketBaseTransportException('realtime stream closed'),
          );
        }
      },
      cancelOnError: true,
    );

    final clientId = await connected.future.timeout(
      const Duration(seconds: 15),
    );
    if (generation != _generation || !_running || _disposed) return;

    await _client.requestJson(
      'POST',
      '/api/realtime',
      body: {
        'clientId': clientId,
        'subscriptions': [_topic],
      },
    );

    // Keep the subscription alive until the stream ends or we stop.
    final sub = _bytesSub;
    if (sub == null) return;
    await sub.asFuture<void>().catchError((Object _) {});
  }

  void _handleEvent(
    ZarPocketBaseSseEvent event,
    Completer<String> connected,
  ) {
    final name = event.event ?? '';
    final data = event.data;
    if (name == 'PB_CONNECT') {
      if (connected.isCompleted || data == null) return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['clientId'] is String) {
          connected.complete(decoded['clientId'] as String);
        } else {
          connected.completeError(
            const ZarPocketBaseProtocolException('PB_CONNECT missing clientId'),
          );
        }
      } catch (error) {
        connected.completeError(ZarPocketBaseProtocolException(error));
      }
      return;
    }
    if (!_signals.isClosed &&
        (name == _topic || name.startsWith('zar_workspaces/'))) {
      _signals.add(null);
    }
  }
}
