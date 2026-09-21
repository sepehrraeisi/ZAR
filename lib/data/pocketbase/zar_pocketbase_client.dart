import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal PocketBase REST client — only what ZAR+ needs (auth + record CRUD
/// + batch). Kept dependency-light on purpose; the official SDK adds more
/// than this app uses and was unavailable offline when this landed.
class ZarPocketBaseClient {
  ZarPocketBaseClient({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  String? authToken;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: {...base.queryParameters, ...query});
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': authToken!,
  };

  Future<Map<String, Object?>> _send(
    String method,
    Uri uri, {
    Object? body,
  }) async {
    final request = http.Request(method, uri)
      ..headers.addAll(_headers())
      ..bodyBytes = utf8.encode(body == null ? '' : jsonEncode(body));
    final response = await _client.send(request);
    final rawBody = await response.stream.bytesToString();
    final decoded = rawBody.isEmpty
        ? <String, Object?>{}
        : jsonDecode(rawBody) as Object?;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : 'PocketBase request failed (${response.statusCode}).';
      throw ZarPocketBaseException(message, statusCode: response.statusCode);
    }
    return decoded == null ? {} : Map<String, Object?>.from(decoded as Map);
  }

  /// Authenticates against an auth collection, returning `(token, record)`.
  Future<({String token, Map<String, Object?> record})> authWithPassword(
    String collection, {
    required String identity,
    required String password,
  }) async {
    final result = await _send(
      'POST',
      _uri('/api/collections/$collection/auth-with-password'),
      body: {'identity': identity, 'password': password},
    );
    return (
      token: result['token']! as String,
      record: Map<String, Object?>.from(result['record']! as Map),
    );
  }

  Future<Map<String, Object?>> createRecord(
    String collection,
    Map<String, Object?> body,
  ) => _send('POST', _uri('/api/collections/$collection/records'), body: body);

  Future<Map<String, Object?>> updateRecord(
    String collection, {
    required String id,
    required Map<String, Object?> body,
  }) => _send(
    'PATCH',
    _uri('/api/collections/$collection/records/$id'),
    body: body,
  );

  Future<void> deleteRecord(String collection, {required String id}) =>
      _send('DELETE', _uri('/api/collections/$collection/records/$id'));

  Future<void> requestPasswordReset(
    String collection, {
    required String email,
  }) => _send(
    'POST',
    _uri('/api/collections/$collection/request-password-reset'),
    body: {'email': email},
  );

  Future<Map<String, Object?>> getRecord(
    String collection, {
    required String id,
  }) => _send('GET', _uri('/api/collections/$collection/records/$id'));

  /// Lists every record of a collection matching [filter], paging through the
  /// full result set (500 per page).
  Future<List<Map<String, Object?>>> listRecords(
    String collection, {
    String? filter,
  }) async {
    final items = <Map<String, Object?>>[];
    var page = 1;
    while (true) {
      final result = await _send(
        'GET',
        _uri(
          '/api/collections/$collection/records',
          {'page': '$page', 'perPage': '500', if (filter != null) 'filter': filter},
        ),
      );
      final rawItems = result['items']! as List;
      items.addAll(
        rawItems.map((item) => Map<String, Object?>.from(item! as Map)),
      );
      final totalPages = result['totalPages'];
      if (totalPages is! int || page >= totalPages) return items;
      page++;
    }
  }

  /// Runs one PocketBase batch (a transaction of sub-requests). The batch
  /// endpoint must be enabled server-side (the ZAR+ migration enables it).
  Future<void> batch(List<({String method, String url, Object? body})> ops) => _send(
    'POST',
    _uri('/api/batch'),
    body: {
      'requests': [
        for (final op in ops)
          {
            'method': op.method,
            'url': op.url,
            if (op.body != null) 'body': op.body,
          },
      ],
    },
  );
}

class ZarPocketBaseException implements Exception {
  const ZarPocketBaseException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
