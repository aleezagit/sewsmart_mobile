// ─── Admin API Client ─────────────────────────────────────────────────────────
// Talks to the SewSmart backend (backend/, docs/API.md section 4). A failed
// request shows the server's message in a snack bar, and an expired session
// goes back to the login screen, so screens only deal with the result.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminApiException implements Exception {
  final int statusCode;
  final String message;
  const AdminApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class AdminApi {
  static final AdminApi _instance = AdminApi._();
  factory AdminApi() => _instance;
  AdminApi._();

  // Set it when building: flutter run -d chrome --dart-define=API_URL=https://api.example.com
  static const String _configuredUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000');
  static String get baseUrl => _configuredUrl.replaceAll(RegExp(r'/$'), '');

  // Given to MaterialApp, so errors and the expired-session redirect work
  // from anywhere.
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  // Opens the login screen when the session expires. Set by main.dart.
  static VoidCallback? onSessionExpired;

  static const _tokenKey = 'admin_token';
  static const _nameKey = 'admin_name';
  static const _emailKey = 'admin_email';
  static const _timeout = Duration(seconds: 30);

  final http.Client _http = http.Client();
  String? _token;

  // The session saved by the last sign-in, so a page reload keeps it, or null.
  Future<({String name, String email})?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token == null) return null;
    return (name: prefs.getString(_nameKey) ?? 'Admin', email: prefs.getString(_emailKey) ?? '');
  }

  Future<void> saveSession(String token, String name, String email) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
  }

  Future<void> clearSession() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_tokenKey, _nameKey, _emailKey]) {
      await prefs.remove(key);
    }
  }

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final params = <String, String>{
      for (final entry in (query ?? const {}).entries)
        if (entry.value != null && '${entry.value}'.isNotEmpty) entry.key: '${entry.value}',
    };
    return Uri.parse('$baseUrl/api/admin$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body, bool quiet = false]) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? const {})), quiet: quiet);

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => _http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? const {})));

  Future<dynamic> delete(String path) => _send(() => _http.delete(_uri(path), headers: _headers));

  // [quiet] leaves the error to the caller, as the login form does.
  Future<dynamic> _send(Future<http.Response> Function() request, {bool quiet = false}) async {
    AdminApiException error;
    try {
      final response = await request().timeout(_timeout);
      final body = response.body.isEmpty ? null : _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) return body;
      final message = body is Map && body['message'] is String
          ? body['message'] as String
          : 'Something went wrong. Please try again.';
      error = AdminApiException(response.statusCode, message);
    } catch (e) {
      error = e is AdminApiException
          ? e
          : const AdminApiException(0, 'Cannot reach the SewSmart server. Check your connection and try again.');
    }
    if (!quiet) {
      if (error.statusCode == 401 && _token != null) {
        await clearSession();
        onSessionExpired?.call();
        _show('Your session has expired. Please sign in again.');
      } else {
        _show(error.message);
      }
    }
    throw error;
  }

  static void _show(String message) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFFDC2626)));
  }

  static dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

List<T> listOf<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) =>
    (json as List).map((item) => fromJson(Map<String, dynamic>.from(item as Map))).toList();

Map<String, dynamic> objectOf(dynamic json) => Map<String, dynamic>.from(json as Map);
