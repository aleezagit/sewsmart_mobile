// ─── API Client ───────────────────────────────────────────────────────────────
// Talks to the SewSmart backend (backend/, docs/API.md). Every service goes
// through it, so the token, the base address and the error format live here.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // The address of the backend. The user can change it on the login screen,
  // which is how one installed app is pointed at a laptop or a server. Without
  // that, the address given when building (flutter run
  // --dart-define=API_URL=https://api.example.com) is used, and without both, a
  // backend on this computer: the Android emulator reaches the host as
  // 10.0.2.2, everything else as localhost.
  static const String _configuredUrl = String.fromEnvironment('API_URL');
  static const _serverKey = 'server_url';
  String? _server;

  String get defaultUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl.replaceAll(RegExp(r'/$'), '');
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:4000' : 'http://localhost:4000';
  }

  String get baseUrl => _server ?? defaultUrl;

  // Points the app at another backend, after checking that it answers. Throws
  // an ApiException, and keeps the old address, when it does not.
  Future<void> useServer(String input) async {
    var url = input.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) throw const ApiException(0, 'Enter the server address.');
    if (!url.contains('://')) url = 'http://$url';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty || !uri.scheme.startsWith('http')) {
      throw const ApiException(0, 'Enter an address like http://192.168.1.5:4000');
    }
    try {
      final response = await _http.get(Uri.parse('$url/api/health')).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception();
    } catch (_) {
      throw ApiException(0, 'SewSmart did not answer at $url. Check the address and that the server is running.');
    }
    _server = url;
    await (await SharedPreferences.getInstance()).setString(_serverKey, url);
  }

  // Goes back to the address given when the app was built.
  Future<void> resetServer() async {
    _server = null;
    await (await SharedPreferences.getInstance()).remove(_serverKey);
  }

  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 30);
  // The try-on waits for the image to be rendered, which can take a minute or
  // more. Other uploads finish much sooner.
  static const _uploadTimeout = Duration(seconds: 200);

  final http.Client _http = http.Client();
  // The sign-in token is kept in the Android Keystore or the iOS Keychain,
  // not in plain preferences.
  static const _storage = FlutterSecureStorage();
  String? _token;

  bool get hasToken => _token != null;

  // Reads what the last run saved: the backend address and the sign-in token.
  // If the secure storage cannot be read, the user simply signs in again.
  Future<void> restore() async {
    _server = (await SharedPreferences.getInstance()).getString(_serverKey);
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
  }

  Future<void> setToken(String? token) async {
    _token = token;
    if (token == null) {
      // Signing out must work even when the storage cannot be reached.
      await _storage.delete(key: _tokenKey).catchError((_) {});
    } else {
      await _storage.write(key: _tokenKey, value: token);
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
