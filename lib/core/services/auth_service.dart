// ─── Auth Service ─────────────────────────────────────────────────────────────
// Sign-in, registration, password reset and the signed-in user's account.
// Methods without a result type throw [ApiException] with a message to show.

import '../api/api_client.dart';
import '../models/app_models.dart';
import '../utils/validators.dart';

class AuthResult {
  final bool success;
  final UserModel? user;
  final String? error;
  const AuthResult({required this.success, this.user, this.error});
}

class AuthService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final ApiClient _api = ApiClient();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // ── Session ────────────────────────────────────────────────────────────────
  // Signs the user back in with the token saved by the last sign-in. Returns
  // null when there is none or it has expired.
  Future<UserModel?> restoreSession() async {
    await _api.restore();
    if (!_api.hasToken) return null;
    try {
      _currentUser = UserModel.fromJson(objectOf(await _api.get('/users/me')));
      return _currentUser;
    } on ApiException catch (e) {
      // A network problem keeps the token for the next start.
      if (e.statusCode == 401 || e.statusCode == 403) await _api.setToken(null);
      return null;
    }
  }

  Future<AuthResult> _startSession(Future<dynamic> Function() request) async {
    try {
      final json = objectOf(await request());
      await _api.setToken(json['token'] as String);
      _currentUser = UserModel.fromJson(objectOf(json['user']));
      return AuthResult(success: true, user: _currentUser);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  // POST /api/auth/login
  Future<AuthResult> login(String email, String password) =>
      _startSession(() => _api.post('/auth/login', {'email': email.trim(), 'password': password}));

  // ── Register ───────────────────────────────────────────────────────────────
  // POST /api/auth/register. A customer verifies the phone with an OTP first.
  Future<AuthResult> register({
    required String name, required String email, required String phone,
    required String password, required UserRole role, String? city,
    int? experienceYears, String? specialties,
  }) =>
      _startSession(() => _api.post('/auth/register', {
        'name': name, 'email': email, 'phone': Validators.normalizeMobile(phone), 'password': password,
        'role': role.name,
        'city': ?city,
        'experience_years': ?experienceYears,
        'specialties': ?specialties,
      }));

  // ── OTP ────────────────────────────────────────────────────────────────────
  // POST /api/auth/send-otp
  Future<void> sendOtp(String phone) => _api.post('/auth/send-otp', {'phone': Validators.normalizeMobile(phone)});

  // POST /api/auth/verify-otp
  Future<void> verifyOtp(String phone, String otp) =>
      _api.post('/auth/verify-otp', {'phone': Validators.normalizeMobile(phone), 'otp': otp});

  // ── Password reset ─────────────────────────────────────────────────────────
  // POST /api/auth/forgot-password. The email carries a reset code.
  Future<void> forgotPassword(String email) =>
      _api.post('/auth/forgot-password', {'email': email});

  // POST /api/auth/reset-password. token is the code from the reset email.
  Future<void> resetPassword(String token, String newPassword) =>
      _api.post('/auth/reset-password', {'token': token, 'new_password': newPassword});

  // ── Profile ────────────────────────────────────────────────────────────────
  // GET /api/users/me
  Future<UserModel> getProfile() async {
    _currentUser = UserModel.fromJson(objectOf(await _api.get('/users/me')));
    return _currentUser!;
  }

  // PUT /api/users/me
  Future<AuthResult> updateProfile({String? name, String? phone, String? city}) async {
    try {
      final json = await _api.put('/users/me', {
        'name': ?name,
        if (phone != null) 'phone': Validators.normalizeMobile(phone),
        'city': ?city,
      });
      _currentUser = UserModel.fromJson(objectOf(json));
      return AuthResult(success: true, user: _currentUser);
    } on ApiException catch (e) {
      return AuthResult(success: false, error: e.message);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  // POST /api/auth/logout. The local session ends even when the request fails.
  Future<void> logout() async {
    try {
      if (_api.hasToken) await _api.post('/auth/logout');
    } on ApiException {
      // The token is dropped below either way.
    }
    _currentUser = null;
    await _api.setToken(null);
  }
}
