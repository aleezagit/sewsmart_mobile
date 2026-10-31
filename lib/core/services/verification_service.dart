// ─── Verification Service ─────────────────────────────────────────────────────
// Tailors send their documents here, and the admin approves or
// rejects them on the Verifications screen. Throws [ApiException] on failure.

import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models/app_models.dart';

class VerificationService {
  static final VerificationService _instance = VerificationService._();
  factory VerificationService() => _instance;
  VerificationService._();

  final ApiClient _api = ApiClient();

  // GET /api/verifications/me
  // The latest request of the signed-in tailor, or null when they have
  // not sent one yet.
  Future<VerificationRequest?> getMyVerification() async {
    try {
      return VerificationRequest.fromJson(objectOf(await _api.get('/verifications/me')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  // POST /api/verifications, as multipart form data. documents maps a type
  // (cnicFront, cnicBack or businessProof) to the picked image.
  Future<VerificationRequest> submitVerification({
    required String cnicNumber, required Map<String, XFile> documents,
  }) async =>
      VerificationRequest.fromJson(objectOf(await _api.upload(
        '/verifications',
        fields: {'cnic_number': cnicNumber.trim()},
        files: documents,
      )));
}
