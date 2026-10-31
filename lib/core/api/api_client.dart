// ─── API Client ───────────────────────────────────────────────────────────────
// Talks to the SewSmart backend (backend/, docs/API.md). Every service goes
// through it, so the token, the base address and the error format live here.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A failed request. [message] comes from the backend's `{ "message": "..." }`
// and is written to be shown to the user as it is.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  // Set it when building: flutter run --dart-define=API_URL=https://api.example.com
  // Without it, a backend on this computer: the Android emulator reaches the
  // host as 10.0.2.2, everything else as localhost.
  static const String _configuredUrl = String.fromEnvironment('API_URL');
  static String get baseUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl.replaceAll(RegExp(r'/$'), '');
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:4000' : 'http://localhost:4000';
  }

  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 30);
  // The try-on waits for the image to be rendered.
  static const _uploadTimeout = Duration(seconds: 90);

  final http.Client _http = http.Client();
  String? _token;

  bool get hasToken => _token != null;

  // Reads the token saved by the last sign-in.
  Future<void> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final params = <String, String>{
      for (final entry in (query ?? const {}).entries)
        if (entry.value != null && '${entry.value}'.isNotEmpty) entry.key: '${entry.value}',
    };
    return Uri.parse('$baseUrl/api$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _http.post(_uri(path), headers: _jsonHeaders, body: jsonEncode(body ?? const {})));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => _http.put(_uri(path), headers: _jsonHeaders, body: jsonEncode(body ?? const {})));

  Future<dynamic> delete(String path) =>
      _send(() => _http.delete(_uri(path), headers: _headers));

  Map<String, String> get _jsonHeaders => {..._headers, 'Content-Type': 'application/json'};

  // Multipart form data with image files, keyed by form field name.
  Future<dynamic> upload(
    String path, {
    Map<String, String> fields = const {},
    Map<String, XFile> files = const {},
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers)
      ..fields.addAll(fields);
    for (final entry in files.entries) {
      final file = entry.value;
      request.files.add(http.MultipartFile.fromBytes(
        entry.key,
        await file.readAsBytes(),
        filename: file.name,
        contentType: MediaType.parse(_imageType(file)),
      ));
    }
    return _send(() async => http.Response.fromStream(await _http.send(request)), timeout: _uploadTimeout);
  }

  // The backend takes JPEG and PNG images.
  static String _imageType(XFile file) {
    final type = file.mimeType;
    if (type == 'image/png' || type == 'image/jpeg') return type!;
    return file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  }

  Future<dynamic> _send(Future<http.Response> Function() request, {Duration timeout = _timeout}) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } catch (_) {
      throw const ApiException(0, 'Cannot reach SewSmart. Check your internet connection and try again.');
    }
    final body = response.body.isEmpty ? null : _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final message = body is Map && body['message'] is String
        ? body['message'] as String
        : 'Something went wrong. Please try again.';
    throw ApiException(response.statusCode, message);
  }

  static dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

// Turns a JSON array into models.
List<T> listOf<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) =>
    (json as List).map((item) => fromJson(Map<String, dynamic>.from(item as Map))).toList();

Map<String, dynamic> objectOf(dynamic json) => Map<String, dynamic>.from(json as Map);
