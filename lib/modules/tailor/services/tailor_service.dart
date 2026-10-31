// ─── Tailor Service ───────────────────────────────────────────────────────────
// The tailor's side of the API (docs/API.md, section 3). Routes that name the
// tailor take its id, and the backend checks it against the token. Every
// method throws [ApiException] with a message to show when the request fails.

import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/validators.dart';

class TailorService {
  static final TailorService _i = TailorService._();
  factory TailorService() => _i;
  TailorService._();

  final ApiClient _api = ApiClient();

  // ── Orders ──────────────────────────────────────────────────────────────────
  // GET /api/orders?status=
  Future<List<OrderModel>> getOrders({OrderStatus? status}) async =>
      listOf(await _api.get('/orders', query: {'status': status?.name}), OrderModel.fromJson);

  Future<OrderModel> _order(Future<dynamic> request) async => OrderModel.fromJson(objectOf(await request));

  // PUT /api/orders/:id/accept
  Future<OrderModel> acceptOrder(String orderId) => _order(_api.put('/orders/$orderId/accept'));

  // PUT /api/orders/:id/reject
  Future<OrderModel> rejectOrder(String orderId) => _order(_api.put('/orders/$orderId/reject'));

  // PUT /api/orders/:id/status. The status only moves forward, up to delivered.
  Future<OrderModel> updateOrderStatus(String orderId, OrderStatus status) =>
      _order(_api.put('/orders/$orderId/status', {'status': status.name}));

  // POST /api/orders/:id/delivery-request
  Future<void> sendDeliveryRequest(String orderId) => _api.post('/orders/$orderId/delivery-request');

  // ── Earnings ────────────────────────────────────────────────────────────────
  // GET /api/tailors/:id/earnings
  Future<TailorEarnings> getEarnings(String tailorId) async =>
      TailorEarnings.fromJson(objectOf(await _api.get('/tailors/$tailorId/earnings')));

  // ── Profile ─────────────────────────────────────────────────────────────────
  // GET /api/tailors/:id
  Future<TailorModel> getProfile(String tailorId) async =>
      TailorModel.fromJson(objectOf(await _api.get('/tailors/$tailorId')));

  // PUT /api/tailors/:id. name is the business name.
  Future<TailorModel> updateProfile({
    required String tailorId, String? name, String? phone, String? city,
    int? experienceYears, String? bio,
  }) async =>
      TailorModel.fromJson(objectOf(await _api.put('/tailors/$tailorId', {
        'name': ?name,
        if (phone != null) 'phone': Validators.normalizeMobile(phone),
        'city': ?city,
        'experience_years': ?experienceYears, 'bio': ?bio,
      })));

  // ── Portfolio ───────────────────────────────────────────────────────────────
  // GET /api/tailors/:id/portfolio
  Future<List<PortfolioItem>> getPortfolio(String tailorId) async =>
      listOf(await _api.get('/tailors/$tailorId/portfolio'), PortfolioItem.fromJson);

  // POST /api/tailors/:id/portfolio, as multipart form data.
  Future<PortfolioItem> addPortfolioSample({required String tailorId, required XFile image, String? title}) async =>
      PortfolioItem.fromJson(objectOf(await _api.upload('/tailors/$tailorId/portfolio',
          fields: {if (title != null && title.trim().isNotEmpty) 'title': title.trim()},
          files: {'image': image})));

  // DELETE /api/tailors/:id/portfolio/:itemId
  Future<void> removePortfolioSample(String tailorId, String itemId) =>
      _api.delete('/tailors/$tailorId/portfolio/$itemId');

  // ── Price list ──────────────────────────────────────────────────────────────
  // GET /api/tailors/:id/garments
  Future<List<GarmentPricing>> getGarments(String tailorId) async =>
      listOf(await _api.get('/tailors/$tailorId/garments'), GarmentPricing.fromJson);

  // POST /api/tailors/:id/garments
  Future<GarmentPricing> addGarment({
    required String tailorId, required String garment,
    required double price, required String estimatedTime,
  }) async =>
      GarmentPricing.fromJson(objectOf(await _api.post('/tailors/$tailorId/garments', {
        'garment': garment, 'price': price, 'estimated_time': estimatedTime,
      })));

  // PUT /api/tailors/:id/garments/:garmentId
  Future<GarmentPricing> updateGarment({
    required String tailorId, required String garmentId,
    String? garment, double? price, String? estimatedTime,
  }) async =>
      GarmentPricing.fromJson(objectOf(await _api.put('/tailors/$tailorId/garments/$garmentId', {
        'garment': ?garment, 'price': ?price, 'estimated_time': ?estimatedTime,
      })));

  // DELETE /api/tailors/:id/garments/:garmentId
  Future<void> removeGarment(String tailorId, String garmentId) =>
      _api.delete('/tailors/$tailorId/garments/$garmentId');

  // ── Live stream ─────────────────────────────────────────────────────────────
  Future<LiveStream> _stream(Future<dynamic> request) async => LiveStream.fromJson(objectOf(await request));

  // POST /api/streams
  Future<LiveStream> startStream({required String title, required String category, bool giftsEnabled = true}) =>
      _stream(_api.post('/streams', {'title': title.trim(), 'category': category, 'gifts_enabled': giftsEnabled}));

  // GET /api/streams/:id
  Future<LiveStream> getStream(String streamId) => _stream(_api.get('/streams/$streamId'));

  // GET /api/streams/:id/messages
  Future<List<LiveMessage>> getStreamMessages(String streamId) async =>
      listOf(await _api.get('/streams/$streamId/messages'), LiveMessage.fromJson);

  // PUT /api/streams/:id/pin. garmentId is an item from the tailor's price list.
  Future<LiveStream> pinStreamItem(String streamId, String garmentId) =>
      _stream(_api.put('/streams/$streamId/pin', {'garment_id': garmentId}));

  // PUT /api/streams/:id/end
  Future<LiveStream> endStream(String streamId) => _stream(_api.put('/streams/$streamId/end'));
}
