// ─── Customer Service ─────────────────────────────────────────────────────────
// The customer's side of the API (docs/API.md, section 3). The API reads the
// customer from the token, so no customer id is passed. Every method throws
// [ApiException] with a message to show when the request fails.

import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/validators.dart';

class CustomerService {
  static final CustomerService _i = CustomerService._();
  factory CustomerService() => _i;
  CustomerService._();

  final ApiClient _api = ApiClient();

  // ── Tailors ─────────────────────────────────────────────────────────────────
  // GET /api/tailors?category=&city=&rating=&search=
  Future<List<TailorModel>> getTailors({String? category, String? city, double? minRating, String? search}) async =>
      listOf(await _api.get('/tailors', query: {
        'category': category == 'All' ? null : category,
        'city': city, 'rating': minRating, 'search': search,
      }), TailorModel.fromJson);

  // GET /api/tailors/:id
  Future<TailorModel> getTailorById(String id) async =>
      TailorModel.fromJson(objectOf(await _api.get('/tailors/$id')));

  // GET /api/tailors/:id/portfolio
  Future<List<PortfolioItem>> getTailorPortfolio(String tailorId) async =>
      listOf(await _api.get('/tailors/$tailorId/portfolio'), PortfolioItem.fromJson);

  // GET /api/tailors/:id/garments
  Future<List<GarmentPricing>> getTailorGarments(String tailorId) async =>
      listOf(await _api.get('/tailors/$tailorId/garments'), GarmentPricing.fromJson);

  // GET /api/tailors/:id/reviews
  Future<List<ReviewModel>> getTailorReviews(String tailorId) async =>
      listOf(await _api.get('/tailors/$tailorId/reviews'), ReviewModel.fromJson);

  // GET /api/categories. The screen adds its own "All" chip.
  Future<List<String>> getCategories() async =>
      List<String>.from(await _api.get('/categories') as List);

  // ── Orders ──────────────────────────────────────────────────────────────────
  // GET /api/orders
  Future<List<OrderModel>> getMyOrders() async =>
      listOf(await _api.get('/orders'), OrderModel.fromJson);

  // POST /api/orders. The price comes from the tailor's price list and the
  // discount from the coupon, both worked out by the server.
  Future<OrderModel> placeOrder({
    required String tailorId, required String garmentType,
    required String measurements, String? notes, String? couponCode,
  }) async =>
      OrderModel.fromJson(objectOf(await _api.post('/orders', {
        'tailor_id': tailorId, 'garment_type': garmentType,
        'measurements': measurements, 'notes': ?notes, 'coupon_code': ?couponCode,
      })));

  // POST /api/orders/:id/design-ref, the reference picture of a placed order.
  Future<OrderModel> uploadDesignReference(String orderId, XFile image) async =>
      OrderModel.fromJson(objectOf(await _api.upload('/orders/$orderId/design-ref', files: {'image': image})));

  // PUT /api/orders/:id/delivery-schedule
  Future<OrderModel> setDeliverySchedule({
    required String orderId, required DateTime deliveryDate, required String deliverySlot,
  }) async =>
      OrderModel.fromJson(objectOf(await _api.put('/orders/$orderId/delivery-schedule', {
        'delivery_date': _day(deliveryDate), 'delivery_slot': deliverySlot,
      })));

  String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // POST /api/payments. Pays the order from the wallet, for the order's own
  // amount. Answers 409 with how much to add when the wallet has too little.
  Future<PaymentModel> makePayment({required String orderId}) async =>
      PaymentModel.fromJson(objectOf(await _api.post('/payments', {'order_id': orderId})));

  // ── Wallet ──────────────────────────────────────────────────────────────────
  // GET /api/wallet
  Future<WalletModel> getWallet() async => WalletModel.fromJson(objectOf(await _api.get('/wallet')));

  // POST /api/wallet/top-up. Adds [amount] rupees from a saved account.
  Future<WalletModel> topUpWallet({required String methodId, required int amount}) async =>
      WalletModel.fromJson(objectOf(await _api.post('/wallet/top-up', {'method_id': methodId, 'amount': amount})));

  // POST /api/reviews. One review per delivered or completed order.
  Future<ReviewModel> submitReview({required String orderId, required int rating, required String comment}) async =>
      ReviewModel.fromJson(objectOf(await _api.post('/reviews', {
        'order_id': orderId, 'rating': rating, 'comment': comment.trim(),
      })));

  // ── Coupons ─────────────────────────────────────────────────────────────────
  // POST /api/coupons/validate
  Future<CouponResult> validateCoupon({required String code, required double amount, String? tailorId}) async =>
      CouponResult.fromJson(objectOf(await _api.post('/coupons/validate', {
        'code': code.trim().toUpperCase(), 'amount': amount, 'tailor_id': ?tailorId,
      })));

  // ── Saved measurements ──────────────────────────────────────────────────────
  // GET /api/measurements. Null when the customer has saved none yet.
  Future<MeasurementModel?> getMeasurements() async {
    try {
      return MeasurementModel.fromJson(objectOf(await _api.get('/measurements')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  // PUT /api/measurements
  Future<MeasurementModel> saveMeasurements(MeasurementModel measurements) async =>
      MeasurementModel.fromJson(objectOf(await _api.put('/measurements', measurements.toJson())));

  // ── Saved payment methods ───────────────────────────────────────────────────
  // GET /api/payment-methods
  Future<List<SavedPaymentMethod>> getPaymentMethods() async =>
      listOf(await _api.get('/payment-methods'), SavedPaymentMethod.fromJson);

  // POST /api/payment-methods. type is jazzCash, easyPaisa, bank or card. A
  // bank account has the bank from BankService and an account number or an IBAN.
  Future<SavedPaymentMethod> addPaymentMethod({
    required String type, required String accountName,
    String? accountNumber, String? bankName, String? iban,
  }) async =>
      SavedPaymentMethod.fromJson(objectOf(await _api.post('/payment-methods', {
        'type': type,
        'account_name': accountName.trim(),
        if (accountNumber != null && accountNumber.trim().isNotEmpty)
          'account_number': type == 'jazzCash' || type == 'easyPaisa' ? Validators.normalizeMobile(accountNumber) : accountNumber.trim(),
        'bank_name': ?bankName,
        if (iban != null && iban.trim().isNotEmpty) 'iban': iban.replaceAll(' ', '').toUpperCase(),
      })));

  // PUT /api/payment-methods/:id/default
  Future<void> setDefaultPaymentMethod(String id) => _api.put('/payment-methods/$id/default');

  // DELETE /api/payment-methods/:id. The default method cannot be removed.
  Future<void> removePaymentMethod(String id) => _api.delete('/payment-methods/$id');

  // ── Saved addresses ─────────────────────────────────────────────────────────
  // GET /api/addresses
  Future<List<AddressModel>> getAddresses() async =>
      listOf(await _api.get('/addresses'), AddressModel.fromJson);

  Map<String, dynamic> _address(String label, String street, String area, String city, String phone, String? landmark) => {
    'label': label, 'street': street.trim(), 'area': area.trim(), 'city': city.trim(),
    'phone': Validators.normalizeMobile(phone), 'landmark': landmark?.trim() ?? '',
  };

  // POST /api/addresses. label is home, work or other. The first address becomes the default.
  Future<AddressModel> addAddress({
    required String label, required String street, required String area,
    required String city, required String phone, String? landmark,
  }) async =>
      AddressModel.fromJson(objectOf(await _api.post('/addresses', _address(label, street, area, city, phone, landmark))));

  // PUT /api/addresses/:id
  Future<AddressModel> updateAddress({
    required String id, required String label, required String street,
    required String area, required String city, required String phone,
    String? landmark,
  }) async =>
      AddressModel.fromJson(objectOf(await _api.put('/addresses/$id', _address(label, street, area, city, phone, landmark))));

  // PUT /api/addresses/:id/default
  Future<void> setDefaultAddress(String id) => _api.put('/addresses/$id/default');

  // DELETE /api/addresses/:id. The default address can only be removed when it is the last one.
  Future<void> removeAddress(String id) => _api.delete('/addresses/$id');

  // ── Wishlist ────────────────────────────────────────────────────────────────
  // GET /api/wishlist
  Future<List<DesignModel>> getWishlist() async =>
      listOf(await _api.get('/wishlist'), DesignModel.fromJson);

  // POST /api/wishlist
  Future<void> addToWishlist(String designId) => _api.post('/wishlist', {'design_id': designId});

  // DELETE /api/wishlist/:designId
  Future<void> removeFromWishlist(String designId) => _api.delete('/wishlist/$designId');

  // ── Searches and AI recommendations ─────────────────────────────────────────
  // POST /api/searches. Searches shorter than three characters are not kept.
  Future<void> recordSearch(String query) async {
    final text = query.trim();
    if (text.length >= 3) await _api.post('/searches', {'query': text});
  }

  // GET /api/searches
  Future<List<SearchEntry>> getMySearches() async =>
      listOf(await _api.get('/searches'), SearchEntry.fromJson);

  // GET /api/searches/trending?limit=
  Future<List<TrendingSearch>> getTrendingSearches({int limit = 10}) async =>
      listOf(await _api.get('/searches/trending', query: {'limit': limit}), TrendingSearch.fromJson);

  // GET /api/ai/recommendations?query=&limit=. Without a query, designs
  // picked from the customer's own searches.
  Future<List<DesignModel>> getRecommendations({String? query, int limit = 6}) async =>
      listOf(await _api.get('/ai/recommendations', query: {'query': query?.trim(), 'limit': limit}), DesignModel.fromJson);

  // ── Virtual try-on ──────────────────────────────────────────────────────────
  // POST /api/ai/try-on, as multipart form data: the customer's photo and the
  // garment's photo. Waits for the rendered image, which takes up to a minute.
  Future<TryOnResult> generateTryOn({
    required XFile photo, required XFile garment, required String garmentType, String? command,
  }) async =>
      TryOnResult.fromJson(objectOf(await _api.upload('/ai/try-on', fields: {
        'garment_type': garmentType,
        if (command != null && command.trim().isNotEmpty) 'command': command.trim(),
      }, files: {'photo': photo, 'garment': garment})));

  // PUT /api/ai/try-on/:id/save
  Future<TryOnResult> saveTryOn(String id) async =>
      TryOnResult.fromJson(objectOf(await _api.put('/ai/try-on/$id/save')));

  // ── Live streams (watching) ─────────────────────────────────────────────────
  // The video itself is carried by LiveKit (core/services/live_video.dart).

  // GET /api/streams?status=live
  Future<List<LiveStream>> getLiveStreams() async =>
      listOf(await _api.get('/streams', query: {'status': 'live'}), LiveStream.fromJson);

  // POST /api/streams/:id/join. A stream that has ended comes back with status ended.
  Future<LiveStream> joinStream(String streamId) async =>
      LiveStream.fromJson(objectOf(await _api.post('/streams/$streamId/join')));

  // GET /api/streams/:id
  Future<LiveStream> getStream(String streamId) async =>
      LiveStream.fromJson(objectOf(await _api.get('/streams/$streamId')));

  // POST /api/streams/:id/leave
  Future<void> leaveStream(String streamId) => _api.post('/streams/$streamId/leave');

  // GET /api/streams/:id/messages
  Future<List<LiveMessage>> getStreamMessages(String streamId) async =>
      listOf(await _api.get('/streams/$streamId/messages'), LiveMessage.fromJson);

  // POST /api/streams/:id/messages
  Future<LiveMessage> sendStreamMessage(String streamId, String text) async =>
      LiveMessage.fromJson(objectOf(await _api.post('/streams/$streamId/messages', {'text': text.trim()})));

  // POST /api/streams/:id/like
  Future<void> likeStream(String streamId) => _api.post('/streams/$streamId/like');

  // POST /api/streams/:id/gifts. giftName is Star, Rose, Diamond or Crown, and
  // is paid from the viewer's wallet.
  Future<void> sendGift(String streamId, String giftName) =>
      _api.post('/streams/$streamId/gifts', {'gift': giftName});
}
