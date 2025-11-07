import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;


class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.getAuthToken,         
    this.defaultHeaders = const {},
    this.timeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final TokenProvider getAuthToken;
  final Map<String, String> defaultHeaders;
  final Duration timeout;

  Uri _u(String path, [Map<String, dynamic>? query]) =>
      Uri.parse('$baseUrl$path')
          .replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));

  Future<Map<String, String>> _headers([Map<String, String>? extra]) async {
    final tok = await getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (tok != null && tok.isNotEmpty) 'Authorization': 'Bearer $tok',
      ...defaultHeaders,
      ...?extra,
    };
  }

  Future<Map<String, dynamic>> _handle(http.Response res) async {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    final text = res.body.isEmpty ? '{}' : res.body;

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(text);
      json = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (_) {
      json = {'raw': text};
    }

    if (!ok) {
      final msg = (json['error'] ?? json['message'] ?? 'HTTP ${res.statusCode}').toString();
      throw ApiException(msg, statusCode: res.statusCode);
    }
    return json;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await http.get(_u(path, query), headers: await _headers()).timeout(timeout);
      return _handle(res);
    } on SocketException {
      throw const ApiException('Brak połączenia z siecią');
    }
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    try {
      final res = await http
          .post(_u(path), headers: await _headers(), body: jsonEncode(body ?? {}))
          .timeout(timeout);
      return _handle(res);
    } on SocketException {
      throw const ApiException('Brak połączenia z siecią');
    }
  }

  Future<Map<String, dynamic>> put(String path, {Object? body}) async {
    try {
      final res = await http
          .put(_u(path), headers: await _headers(), body: jsonEncode(body ?? {}))
          .timeout(timeout);
      return _handle(res);
    } on SocketException {
      throw const ApiException('Brak połączenia z siecią');
    }
  }

  Future<Map<String, dynamic>> delete(String path, {Object? body}) async {
    try {
      final res = await http
          .delete(_u(path), headers: await _headers(), body: body != null ? jsonEncode(body) : null)
          .timeout(timeout);
      return _handle(res);
    } on SocketException {
      throw const ApiException('Brak połączenia z siecią');
    }
  }
}
