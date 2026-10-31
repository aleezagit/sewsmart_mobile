// ─── All App Models ───────────────────────────────────────────────────────────

export 'user_model.dart';

// ── Tailor Profile ────────────────────────────────────────────────────────────
class TailorModel {
  final String id, name, category, city, bio;
  final String userAvatar;
  final double rating, priceFrom;
  final int totalOrders;
  final List<String> specialties;
  final bool isVerified;
  final List<String> portfolio;
  final int experienceYears;

  const TailorModel({
    required this.id, required this.name, required this.category,
    required this.city, required this.bio, required this.userAvatar,
    required this.rating, required this.priceFrom, required this.totalOrders,
    required this.specialties, required this.isVerified, this.portfolio = const [],
    this.experienceYears = 0,
  });

  factory TailorModel.fromJson(Map<String, dynamic> j) => TailorModel(
    id: j['id'], name: j['name'], category: j['category'], city: j['city'],
    bio: j['bio'] ?? '', userAvatar: j['avatar'] ?? '',
    rating: (j['rating'] as num).toDouble(),
    priceFrom: (j['price_from'] as num).toDouble(),
    totalOrders: j['total_orders'] ?? 0,
    specialties: List<String>.from(j['specialties'] ?? []),
    isVerified: j['is_verified'] ?? false,
    portfolio: List<String>.from(j['portfolio'] ?? []),
    experienceYears: j['experience_years'] ?? 0,
  );
}

// ── Order ─────────────────────────────────────────────────────────────────────
enum OrderStatus { pending, accepted, rejected, inProgress, qualityCheck, readyForDelivery, delivered, completed, cancelled }

class OrderModel {
  final String id, customerId, tailorId, customerName, tailorName, garmentType;
  final OrderStatus status;
  final double amount, discount;
  final String measurements;
  final bool hasDesignRef, deliveryRequested;
  final DateTime createdAt;
  final DateTime? scheduledDelivery;
  final String? deliverySlot, deliveryAddress, designRefUrl;
  final String? notes;

  const OrderModel({
    required this.id, required this.customerId, required this.tailorId,
    required this.customerName, required this.tailorName,
    required this.garmentType, required this.status, required this.amount,
    required this.measurements, required this.createdAt,
    this.discount = 0, this.hasDesignRef = false, this.deliveryRequested = false,
    this.scheduledDelivery, this.deliverySlot, this.deliveryAddress, this.designRefUrl, this.notes,
  });

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
    id: j['id'], customerId: j['customer_id'], tailorId: j['tailor_id'],
    customerName: j['customer_name'], tailorName: j['tailor_name'],
    garmentType: j['garment_type'],
    status: OrderStatus.values.byName(j['status']),
    amount: (j['amount'] as num).toDouble(),
    discount: ((j['discount'] ?? 0) as num).toDouble(),
    measurements: j['measurements'] ?? '',
    createdAt: DateTime.parse(j['created_at']).toLocal(),
    hasDesignRef: j['has_design_ref'] ?? false,
    deliveryRequested: j['delivery_requested'] ?? false,
    scheduledDelivery: _date(j['scheduled_delivery']),
    deliverySlot: j['delivery_slot'],
    deliveryAddress: j['delivery_address'],
    designRefUrl: j['design_ref_url'],
    notes: j['notes'],
  );

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending: return 'Pending';
      case OrderStatus.accepted: return 'Accepted';
      case OrderStatus.rejected: return 'Rejected';
      case OrderStatus.inProgress: return 'In Progress';
      case OrderStatus.qualityCheck: return 'Quality Check';
      case OrderStatus.readyForDelivery: return 'Ready';
      case OrderStatus.delivered: return 'Delivered';
      case OrderStatus.completed: return 'Completed';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }
}

// ── Payment ───────────────────────────────────────────────────────────────────
enum PaymentStatus { pending, completed, failed, refunded }
enum PaymentMethod { jazzCash, easyPaisa, bank, card }

class PaymentModel {
  final String id, orderId, customerId, tailorId;
  final double amount;
  final PaymentStatus status;
  final PaymentMethod method;
  final DateTime createdAt;
  final String? transactionId;

  const PaymentModel({
    required this.id, required this.orderId, required this.customerId,
    required this.tailorId, required this.amount, required this.status,
    required this.method, required this.createdAt, this.transactionId,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> j) => PaymentModel(
    id: j['id'], orderId: j['order_id'], customerId: j['customer_id'],
    tailorId: j['tailor_id'], amount: (j['amount'] as num).toDouble(),
    status: PaymentStatus.values.byName(j['status']),
    method: PaymentMethod.values.byName(j['method']),
    createdAt: DateTime.parse(j['created_at']).toLocal(),
    transactionId: j['transaction_id'],
  );
}

// ── Earnings ──────────────────────────────────────────────────────────────────
// month is YYYY-MM.
class MonthlyEarning {
  final String month;
  final double amount;
  final int orders;
  const MonthlyEarning({required this.month, required this.amount, required this.orders});

  factory MonthlyEarning.fromJson(Map<String, dynamic> j) => MonthlyEarning(
    month: j['month'], amount: (j['amount'] as num).toDouble(), orders: j['orders'] ?? 0,
  );

  // "Oct" for "2026-10".
  String get shortMonth {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final number = int.tryParse(month.split('-').last) ?? 1;
    return names[(number - 1).clamp(0, 11)];
  }
}

// GET /api/tailors/:id/earnings. commissionRate is the platform's percentage.
class TailorEarnings {
  final double total, thisMonth, pending, withdrawn, available, commissionRate;
  final List<MonthlyEarning> monthly;

  const TailorEarnings({
    required this.total, required this.thisMonth, required this.pending,
    required this.withdrawn, required this.available, required this.commissionRate,
    required this.monthly,
  });

  factory TailorEarnings.fromJson(Map<String, dynamic> j) => TailorEarnings(
    total: _money(j['total']), thisMonth: _money(j['this_month']),
    pending: _money(j['pending']), withdrawn: _money(j['withdrawn']),
    available: _money(j['available']), commissionRate: _money(j['commission_rate']),
    monthly: ((j['monthly'] ?? []) as List)
        .map((m) => MonthlyEarning.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList(),
  );
}

double _money(dynamic value) => ((value ?? 0) as num).toDouble();
// API dates are UTC. The app shows them in the phone's time zone.
DateTime? _date(dynamic value) => value == null ? null : DateTime.parse(value as String).toLocal();

// ── Message ───────────────────────────────────────────────────────────────────
enum MessageType { text, image, document }

class MessageModel {
  final String id, senderId, receiverId, text;
  final MessageType type;
  final DateTime time;
  final bool isRead;

  const MessageModel({
    required this.id, required this.senderId, required this.receiverId,
    required this.text, required this.type, required this.time,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
    id: j['id'], senderId: j['sender_id'], receiverId: j['receiver_id'],
    text: j['text'] ?? '',
    type: MessageType.values.byName(j['type'] ?? 'text'),
    time: DateTime.parse(j['created_at']).toLocal(),
    isRead: j['is_read'] ?? false,
  );
}

// ── Notification ──────────────────────────────────────────────────────────────
class NotificationModel {
  final String id, title, body, type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id, required this.title, required this.body,
    required this.type, required this.isRead, required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
    id: j['id'], title: j['title'], body: j['body'] ?? '',
    type: j['type'] ?? '',
    isRead: j['is_read'] ?? false,
    createdAt: DateTime.parse(j['created_at']).toLocal(),
  );

  NotificationModel asRead() => NotificationModel(
    id: id, title: title, body: body, type: type, isRead: true, createdAt: createdAt,
  );
}

// ── Review ────────────────────────────────────────────────────────────────────
// orderId is the order the review is about. A customer reviews each order once.
class ReviewModel {
  final String id, customerId, tailorId, customerName, comment;
  final double rating;
  final DateTime createdAt;
  final String? orderId;

  const ReviewModel({
    required this.id, required this.customerId, required this.tailorId,
    required this.customerName, required this.comment,
    required this.rating, required this.createdAt, this.orderId,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> j) => ReviewModel(
    id: j['id'], customerId: j['customer_id'], tailorId: j['tailor_id'],
    customerName: j['customer_name'], comment: j['comment'] ?? '',
    rating: (j['rating'] as num).toDouble(),
    createdAt: DateTime.parse(j['created_at']).toLocal(),
    orderId: j['order_id'],
  );
}

// ── Garment Pricing ───────────────────────────────────────────────────────────
// One line of a tailor's own price list.
class GarmentPricing {
  final String id;
  final String garment, estimatedTime;
  final double price;
  const GarmentPricing({required this.id, required this.garment, required this.price, required this.estimatedTime});

  factory GarmentPricing.fromJson(Map<String, dynamic> j) => GarmentPricing(
    id: j['id'], garment: j['garment'],
    price: (j['price'] as num).toDouble(),
    estimatedTime: j['estimated_time'] ?? '',
  );
}

// ── Portfolio Sample ──────────────────────────────────────────────────────────
class PortfolioItem {
  final String id, tailorId, title, imageUrl;
  final String status; // active, flagged
  final DateTime createdAt;

  const PortfolioItem({
    required this.id, required this.tailorId, required this.title,
    required this.imageUrl, required this.createdAt, this.status = 'active',
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> j) => PortfolioItem(
    id: j['id'], tailorId: j['tailor_id'], title: j['title'] ?? '',
    imageUrl: j['image_url'] ?? '', status: j['status'] ?? 'active',
    createdAt: DateTime.parse(j['created_at']).toLocal(),
  );
}

// ── Coupon ────────────────────────────────────────────────────────────────────
class CouponResult {
  final String code, message;
  final bool valid;
  final double discountPercent, discountAmount;

  const CouponResult({
    required this.code, required this.valid, this.message = '',
    this.discountPercent = 0, this.discountAmount = 0,
  });

  factory CouponResult.fromJson(Map<String, dynamic> j) => CouponResult(
    code: j['code'] ?? '', valid: j['valid'] ?? false, message: j['message'] ?? '',
    discountPercent: ((j['discount_percent'] ?? 0) as num).toDouble(),
    discountAmount: ((j['discount_amount'] ?? 0) as num).toDouble(),
  );
}

// ── Saved Measurements ────────────────────────────────────────────────────────
class MeasurementModel {
  final String unit; // cm, in
  final double height, weight, chest, waist, hips, shoulder, armLength, inseam, neck, wrist;
  final DateTime? updatedAt;

  const MeasurementModel({
    required this.unit, required this.height, required this.weight,
    required this.chest, required this.waist, required this.hips,
    required this.shoulder, required this.armLength, required this.inseam,
    required this.neck, required this.wrist, this.updatedAt,
  });

  factory MeasurementModel.fromJson(Map<String, dynamic> j) => MeasurementModel(
    unit: j['unit'] ?? 'cm',
    height: (j['height'] as num).toDouble(), weight: (j['weight'] as num).toDouble(),
    chest: (j['chest'] as num).toDouble(), waist: (j['waist'] as num).toDouble(),
    hips: (j['hips'] as num).toDouble(), shoulder: (j['shoulder'] as num).toDouble(),
    armLength: (j['arm_length'] as num).toDouble(), inseam: (j['inseam'] as num).toDouble(),
    neck: (j['neck'] as num).toDouble(), wrist: (j['wrist'] as num).toDouble(),
    updatedAt: _date(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'unit': unit, 'height': height, 'weight': weight, 'chest': chest,
    'waist': waist, 'hips': hips, 'shoulder': shoulder, 'arm_length': armLength,
    'inseam': inseam, 'neck': neck, 'wrist': wrist,
  };
}

// ── Saved Payment Method ──────────────────────────────────────────────────────
class SavedPaymentMethod {
  final String id;
  final String type; // jazzCash, easyPaisa, bank, card, cashOnDelivery
  final String detail, accountName;
  final bool isDefault;

  const SavedPaymentMethod({
    required this.id, required this.type, required this.detail,
    this.accountName = '', this.isDefault = false,
  });

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> j) => SavedPaymentMethod(
    id: j['id'], type: j['type'], detail: j['detail'] ?? '',
    accountName: j['account_name'] ?? '', isDefault: j['is_default'] ?? false,
  );
}

// ── Payout Account ────────────────────────────────────────────────────────────
class PayoutAccount {
  final String id;
  final String type; // jazzCash, easyPaisa, bank
  final String accountNumber, accountName;
  final String? bankName, iban;
  final bool isDefault;

  const PayoutAccount({
    required this.id, required this.type, required this.accountNumber,
    required this.accountName, this.bankName, this.iban, this.isDefault = false,
  });

  factory PayoutAccount.fromJson(Map<String, dynamic> j) => PayoutAccount(
    id: j['id'], type: j['type'], accountNumber: j['account_number'],
    accountName: j['account_name'] ?? '', bankName: j['bank_name'], iban: j['iban'],
    isDefault: j['is_default'] ?? false,
  );
}

// ── Withdrawal ────────────────────────────────────────────────────────────────
class WithdrawalModel {
  final String id;
  final String status; // pending, paid, failed
  final double amount;
  final DateTime requestedAt;
  final DateTime? paidAt;

  const WithdrawalModel({
    required this.id, required this.amount, required this.status,
    required this.requestedAt, this.paidAt,
  });

  factory WithdrawalModel.fromJson(Map<String, dynamic> j) => WithdrawalModel(
    id: j['id'], amount: (j['amount'] as num).toDouble(), status: j['status'],
    requestedAt: DateTime.parse(j['requested_at']).toLocal(),
    paidAt: _date(j['paid_at']),
  );
}

// ── Chat Conversation ─────────────────────────────────────────────────────────
// One conversation per order, between its customer and its tailor.
class ConversationModel {
  final String orderId, garmentType, otherUserId, otherUserName, lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.orderId, required this.garmentType, required this.otherUserId,
    required this.otherUserName, this.lastMessage = '', this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> j) => ConversationModel(
    orderId: j['order_id'], garmentType: j['garment_type'],
    otherUserId: j['other_user_id'], otherUserName: j['other_user_name'],
    lastMessage: j['last_message'] ?? '',
    lastMessageAt: _date(j['last_message_at']),
    unreadCount: j['unread_count'] ?? 0,
  );
}

// ── Design (recommendations and wishlist) ─────────────────────────────────────
class DesignModel {
  final String id, name, category;
  final double priceMin, priceMax;
  final String? imageUrl;

  const DesignModel({
    required this.id, required this.name, required this.category,
    required this.priceMin, required this.priceMax, this.imageUrl,
  });

  factory DesignModel.fromJson(Map<String, dynamic> j) => DesignModel(
    id: j['id'], name: j['name'], category: j['category'],
    priceMin: (j['price_min'] as num).toDouble(),
    priceMax: (j['price_max'] as num).toDouble(),
    imageUrl: j['image_url'],
  );
}

// ── Search History ────────────────────────────────────────────────────────────
class SearchEntry {
  final String query, category;
  final DateTime createdAt;

  const SearchEntry({required this.query, required this.category, required this.createdAt});

  factory SearchEntry.fromJson(Map<String, dynamic> j) => SearchEntry(
    query: j['query'], category: j['category'] ?? 'General',
    createdAt: DateTime.parse(j['created_at']).toLocal(),
  );
}

class TrendingSearch {
  final String query;
  final int count;

  const TrendingSearch({required this.query, required this.count});

  factory TrendingSearch.fromJson(Map<String, dynamic> j) => TrendingSearch(
    query: j['query'], count: j['count'] ?? 0,
  );
}

// ── AI Design Studio ──────────────────────────────────────────────────────────
class DesignConcept {
  final String id, title, description, category, color, fabric;

  const DesignConcept({
    required this.id, required this.title, required this.description,
    required this.category, required this.color, required this.fabric,
  });

  factory DesignConcept.fromJson(Map<String, dynamic> j) => DesignConcept(
    id: j['id'], title: j['title'], description: j['description'] ?? '',
    category: j['category'], color: j['color'], fabric: j['fabric'],
  );
}

// ── Virtual Try-On ────────────────────────────────────────────────────────────
class TryOnResult {
  final String id, garmentType, resultUrl;
  final String? command;
  final bool isSaved;
  final DateTime createdAt;

  const TryOnResult({
    required this.id, required this.garmentType, required this.resultUrl,
    required this.createdAt, this.command, this.isSaved = false,
  });

  factory TryOnResult.fromJson(Map<String, dynamic> j) => TryOnResult(
    id: j['id'], garmentType: j['garment_type'], resultUrl: j['result_url'] ?? '',
    command: j['command'], isSaved: j['is_saved'] ?? false,
    createdAt: DateTime.parse(j['created_at']).toLocal(),
  );
}

// ── Live Stream ───────────────────────────────────────────────────────────────
class LiveGift {
  final String name;
  final int amount, count;

  const LiveGift({required this.name, required this.amount, this.count = 0});

  factory LiveGift.fromJson(Map<String, dynamic> j) => LiveGift(
    name: j['name'], amount: j['amount'] ?? 0, count: j['count'] ?? 0,
  );
}

class LiveMessage {
  final String id, viewerName, text;
  final DateTime createdAt;

  const LiveMessage({
    required this.id, required this.viewerName, required this.text,
    required this.createdAt,
  });

  factory LiveMessage.fromJson(Map<String, dynamic> j) => LiveMessage(
    id: j['id'], viewerName: j['viewer_name'], text: j['text'] ?? '',
    createdAt: DateTime.parse(j['created_at']).toLocal(),
  );
}

class LiveStream {
  final String id, tailorId, title, category;
  // The business name, so the customer app can list streams without
  // loading each tailor.
  final String tailorName;
  final String status; // live, ended
  final bool giftsEnabled;
  final int viewers, peakViewers, likes, durationSeconds;
  final double earnings;
  final String? pinnedGarmentId;
  final DateTime startedAt;
  final List<LiveGift> gifts;

  const LiveStream({
    required this.id, required this.tailorId, required this.title,
    required this.category, required this.status, required this.startedAt,
    this.tailorName = '',
    this.giftsEnabled = true, this.viewers = 0, this.peakViewers = 0,
    this.likes = 0, this.durationSeconds = 0, this.earnings = 0,
    this.pinnedGarmentId, this.gifts = const [],
  });

  factory LiveStream.fromJson(Map<String, dynamic> j) => LiveStream(
    id: j['id'], tailorId: j['tailor_id'], title: j['title'],
    tailorName: j['tailor_name'] ?? '',
    category: j['category'], status: j['status'],
    startedAt: DateTime.parse(j['started_at']).toLocal(),
    giftsEnabled: j['gifts_enabled'] ?? true,
    viewers: j['viewers'] ?? 0, peakViewers: j['peak_viewers'] ?? 0,
    likes: j['likes'] ?? 0, durationSeconds: j['duration_seconds'] ?? 0,
    earnings: ((j['earnings'] ?? 0) as num).toDouble(),
    pinnedGarmentId: j['pinned_garment_id'],
    gifts: ((j['gifts'] ?? []) as List)
        .map((g) => LiveGift.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList(),
  );
}

// ── Delivery Address ──────────────────────────────────────────────────────────
class AddressModel {
  final String id;
  final String label; // home, work, other
  final String street, area, city, phone;
  final String? landmark;
  final bool isDefault;

  const AddressModel({
    required this.id, required this.label, required this.street,
    required this.area, required this.city, required this.phone,
    this.landmark, this.isDefault = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> j) => AddressModel(
    id: j['id'], label: j['label'] ?? 'other', street: j['street'] ?? '',
    area: j['area'] ?? '', city: j['city'] ?? '', phone: j['phone'] ?? '',
    landmark: j['landmark'], isDefault: j['is_default'] ?? false,
  );

  // One line for lists: "House 12, Street 5, Gulberg III, Lahore".
  String get summary =>
      [street, area, city].where((part) => part.trim().isNotEmpty).join(', ');
}

// ── Dispute ───────────────────────────────────────────────────────────────────
// A problem with one order, raised by its customer or its tailor and resolved
// by the admin.
class DisputeModel {
  final String id, orderId, reason, details;
  final String status; // open, resolved
  final String? resolution; // refund, warning, dismiss
  final String? resolutionNotes;
  final DateTime createdAt;

  const DisputeModel({
    required this.id, required this.orderId, required this.reason,
    required this.details, required this.status, required this.createdAt,
    this.resolution, this.resolutionNotes,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> j) => DisputeModel(
    id: j['id'], orderId: j['order_id'], reason: j['reason'] ?? '',
    details: j['details'] ?? '', status: j['status'] ?? 'open',
    resolution: j['resolution'], resolutionNotes: j['resolution_notes'],
    createdAt: DateTime.parse(j['created_at']).toLocal(),
  );

  bool get isOpen => status == 'open';
}

// ── Verification ──────────────────────────────────────────────────────────────
// A document a tailor sends to be verified. type is cnicFront, cnicBack or
// businessProof.
class VerificationDocument {
  final String type, url;
  const VerificationDocument({required this.type, this.url = ''});

  factory VerificationDocument.fromJson(Map<String, dynamic> j) =>
      VerificationDocument(type: j['type'], url: j['url'] ?? '');
}

class VerificationRequest {
  final String id;
  final String status; // pending, approved, rejected
  final String cnicNumber;
  final List<VerificationDocument> documents;
  final DateTime submittedAt;
  final String? rejectionReason;
  // Set when the admin asked for more documents. The request stays pending.
  final String? adminMessage;

  const VerificationRequest({
    required this.id, required this.status, required this.cnicNumber,
    required this.documents, required this.submittedAt,
    this.rejectionReason, this.adminMessage,
  });

  factory VerificationRequest.fromJson(Map<String, dynamic> j) => VerificationRequest(
    id: j['id'], status: j['status'], cnicNumber: j['cnic_number'] ?? '',
    documents: ((j['documents'] ?? []) as List)
        .map((d) => VerificationDocument.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList(),
    submittedAt: DateTime.parse(j['submitted_at']).toLocal(),
    rejectionReason: j['rejection_reason'], adminMessage: j['admin_message'],
  );

  bool has(String type) => documents.any((d) => d.type == type);
}
