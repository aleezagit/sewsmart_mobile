// The admin panel's models. The API sends lower camelCase values such as
// `inProgress` and `jazzCash` (docs/API.md, section 2), and the screens show
// labels such as In Progress and Paid, so fromJson converts them here.

// "active" → "Active".
String _label(dynamic value) {
  final text = '${value ?? ''}';
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

// An ISO date from the API as "2024-06-01" in local time.
String _day(dynamic value) {
  if (value == null) return '';
  final date = DateTime.parse(value as String).toLocal();
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

double _number(dynamic value) => ((value ?? 0) as num).toDouble();

// The four order tabs (docs/API.md, section 2).
String orderStatusLabel(String status) => switch (status) {
  'pending' => 'Pending',
  'accepted' || 'inProgress' || 'qualityCheck' || 'readyForDelivery' => 'In Progress',
  'delivered' || 'completed' => 'Completed',
  _ => 'Cancelled',
};

class PlatformStats {
  final int totalUsers;
  final int totalOrders;
  final double totalRevenue;
  final int activeOrders;
  final int pendingVerifications;
  final int registeredTailors;
  final int openDisputes;
  final double thisMonthRevenue;
  final double lastMonthRevenue;
  final double averageTailorRating;

  const PlatformStats({
    required this.totalUsers,
    required this.totalOrders,
    required this.totalRevenue,
    required this.activeOrders,
    required this.pendingVerifications,
    required this.registeredTailors,
    required this.openDisputes,
    required this.thisMonthRevenue,
    required this.lastMonthRevenue,
    required this.averageTailorRating,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> j) => PlatformStats(
    totalUsers: j['total_users'] ?? 0,
    totalOrders: j['total_orders'] ?? 0,
    totalRevenue: _number(j['total_revenue']),
    activeOrders: j['active_orders'] ?? 0,
    pendingVerifications: j['pending_verifications'] ?? 0,
    registeredTailors: j['registered_tailors'] ?? 0,
    openDisputes: j['open_disputes'] ?? 0,
    thisMonthRevenue: _number(j['this_month_revenue']),
    lastMonthRevenue: _number(j['last_month_revenue']),
    averageTailorRating: _number(j['average_tailor_rating']),
  );
}

class MonthlyRevenue {
  // The short month name, such as "Jun".
  final String month;
  final double revenue;

  const MonthlyRevenue({required this.month, required this.revenue});

  // `month` arrives as "2024-06".
  factory MonthlyRevenue.fromJson(Map<String, dynamic> j) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final number = int.tryParse('${j['month']}'.split('-').last) ?? 1;
    return MonthlyRevenue(month: names[(number - 1).clamp(0, 11)], revenue: _number(j['revenue']));
  }
}

class CategoryRevenue {
  final String category;
  final double amount;
  final int color;

  const CategoryRevenue({
    required this.category,
    required this.amount,
    required this.color,
  });

  // The API leaves the colours to the app, so they follow the list order.
  static const _palette = [0xFF7C3AED, 0xFF0D9488, 0xFFEA580C, 0xFF2563EB, 0xFFDB2777, 0xFFEAB308, 0xFF16A34A];

  factory CategoryRevenue.fromJson(Map<String, dynamic> j, int index) => CategoryRevenue(
    category: j['category'] ?? '',
    amount: _number(j['amount']),
    color: _palette[index % _palette.length],
  );
}

class AdminUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String role;
  final String status;
  final String joinDate;
  final int totalOrders;
  final double totalSpent;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.role,
    required this.status,
    required this.joinDate,
    required this.totalOrders,
    required this.totalSpent,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'],
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    phone: j['phone'] ?? '',
    city: j['city'] ?? '',
    role: j['role'] ?? 'customer',
    status: _label(j['status']),
    joinDate: _day(j['created_at']),
    totalOrders: j['total_orders'] ?? 0,
    totalSpent: _number(j['total_spent']),
  );
}

class AdminTailor {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String category;
  final String status;
  final bool isVerified;
  final String joinDate;
  final int totalOrders;
  final double rating;
  final double revenue;

  const AdminTailor({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.category,
    required this.status,
    required this.isVerified,
    required this.joinDate,
    required this.totalOrders,
    required this.rating,
    required this.revenue,
  });

  factory AdminTailor.fromJson(Map<String, dynamic> j) => AdminTailor(
    id: j['id'],
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    phone: j['phone'] ?? '',
    city: j['city'] ?? '',
    category: j['category'] ?? '',
    status: _label(j['status']),
    isVerified: j['is_verified'] ?? false,
    joinDate: _day(j['created_at']),
    totalOrders: j['total_orders'] ?? 0,
    rating: _number(j['rating']),
    revenue: _number(j['revenue']),
  );
}

// A tailor's request to be verified.
class PendingVerification {
  final String id;
  final String name;
  final String phone;
  final String city;
  final String submittedDate;
  final String status;
  final bool documentsSubmitted;
  // The uploaded image of each document type: cnicFront, cnicBack, businessProof.
  final Map<String, String> documents;

  const PendingVerification({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.submittedDate,
    required this.status,
    required this.documentsSubmitted,
    required this.documents,
  });

  factory PendingVerification.fromJson(Map<String, dynamic> j) => PendingVerification(
    id: j['id'],
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    city: j['city'] ?? '',
    submittedDate: _day(j['submitted_at']),
    status: _label(j['status']),
    documentsSubmitted: j['documents_submitted'] ?? false,
    documents: {
      for (final d in (j['documents'] ?? const []) as List)
        if ((d['url'] ?? '').isNotEmpty) d['type'] as String: d['url'] as String,
    },
  );
}

class AdminOrder {
  final String id;
  final String customerId;
  final String customerName;
  final String tailorId;
  final String tailorName;
  final String garment;
  final double amount;
  // One of the four tab labels: Pending, In Progress, Completed, Cancelled.
  final String status;
  final String date;
  final String city;

  const AdminOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.tailorId,
    required this.tailorName,
    required this.garment,
    required this.amount,
    required this.status,
    required this.date,
    required this.city,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> j) => AdminOrder(
    id: j['id'],
    customerId: j['customer_id'] ?? '',
    customerName: j['customer_name'] ?? '',
    tailorId: j['tailor_id'] ?? '',
    tailorName: j['tailor_name'] ?? '',
    garment: j['garment_type'] ?? '',
    amount: _number(j['amount']),
    status: orderStatusLabel(j['status'] ?? ''),
    date: _day(j['created_at']),
    city: j['city'] ?? '',
  );
}

class AdminPayment {
  final String id;
  final String transactionId;
  final String orderId;
  final String customerName;
  final String tailorName;
  final double amount;
  final String status;
  final String date;

  const AdminPayment({
    required this.id,
    required this.transactionId,
    required this.orderId,
    required this.customerName,
    required this.tailorName,
    required this.amount,
    required this.status,
    required this.date,
  });

  static const statusLabels = {'pending': 'Processing', 'completed': 'Paid', 'refunded': 'Refunded'};

  factory AdminPayment.fromJson(Map<String, dynamic> j) => AdminPayment(
    id: j['id'],
    transactionId: j['transaction_id'] ?? j['id'],
    orderId: j['order_id'] ?? '',
    customerName: j['customer_name'] ?? '',
    tailorName: j['tailor_name'] ?? '',
    amount: _number(j['amount']),
    status: statusLabels[j['status']] ?? _label(j['status']),
    date: _day(j['created_at']),
  );
}

class AdminDispute {
  final String id;
  final String orderId;
  final String customerName;
  final String tailorName;
  final String issue;
  final double amount;
  final String dateRaised;
  final String status;
  // "Refund: Full refund issued", once resolved.
  final String? resolution;

  const AdminDispute({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.tailorName,
    required this.issue,
    required this.amount,
    required this.dateRaised,
    required this.status,
    this.resolution,
  });

  factory AdminDispute.fromJson(Map<String, dynamic> j) {
    final resolution = j['resolution'] as String?;
    final notes = (j['resolution_notes'] as String?) ?? '';
    return AdminDispute(
      id: j['id'],
      orderId: j['order_id'] ?? '',
      customerName: j['customer_name'] ?? '',
      tailorName: j['tailor_name'] ?? '',
      issue: j['issue'] ?? '',
      amount: _number(j['amount']),
      dateRaised: _day(j['created_at']),
      status: _label(j['status']),
      resolution: resolution == null ? null : (notes.isEmpty ? _label(resolution) : '${_label(resolution)}: $notes'),
    );
  }
}

class TopTailor {
  final String id;
  final String name;
  final String city;
  final int orders;
  final double rating;
  final double revenue;
  final double completionRate;

  const TopTailor({
    required this.id,
    required this.name,
    required this.city,
    required this.orders,
    required this.rating,
    required this.revenue,
    required this.completionRate,
  });

  factory TopTailor.fromJson(Map<String, dynamic> j) => TopTailor(
    id: j['id'],
    name: j['name'] ?? '',
    city: j['city'] ?? '',
    orders: j['total_orders'] ?? 0,
    rating: _number(j['rating']),
    revenue: _number(j['revenue']),
    completionRate: _number(j['completion_rate']),
  );
}

// A portfolio sample a tailor uploaded.
class ContentItem {
  final String id;
  final String creator;
  final String title;
  final String type;
  final String status;
  final String date;

  const ContentItem({
    required this.id,
    required this.creator,
    required this.title,
    required this.type,
    required this.status,
    required this.date,
  });

  factory ContentItem.fromJson(Map<String, dynamic> j) => ContentItem(
    id: j['id'],
    creator: j['creator_name'] ?? '',
    title: (j['title'] as String?)?.isNotEmpty == true ? j['title'] : 'Untitled sample',
    type: j['type'] ?? 'design',
    status: _label(j['status']),
    date: _day(j['created_at']),
  );
}

class ReviewItem {
  final String id;
  final String customer;
  final String tailor;
  final int rating;
  final String comment;
  final String date;
  final String status;

  const ReviewItem({
    required this.id,
    required this.customer,
    required this.tailor,
    required this.rating,
    required this.comment,
    required this.date,
    required this.status,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
    id: j['id'],
    customer: j['customer_name'] ?? '',
    tailor: j['tailor_name'] ?? '',
    rating: (_number(j['rating'])).round(),
    comment: j['comment'] ?? '',
    date: _day(j['created_at']),
    status: _label(j['status']),
  );
}

// A report a customer or tailor sent about a design, review or profile.
class FlaggedItem {
  final String id;
  final String reporter;
  final String reportedItem;
  final String reason;
  final String date;
  final String status;

  const FlaggedItem({
    required this.id,
    required this.reporter,
    required this.reportedItem,
    required this.reason,
    required this.date,
    required this.status,
  });

  factory FlaggedItem.fromJson(Map<String, dynamic> j) => FlaggedItem(
    id: j['id'],
    reporter: j['reporter_name'] ?? '',
    reportedItem: j['reported_item'] ?? '',
    reason: j['reason'] ?? '',
    date: _day(j['created_at']),
    status: _label(j['status']),
  );
}

class AdminAuthResult {
  final bool success;
  final String? name;
  final String? email;
  final String? error;

  const AdminAuthResult({
    required this.success,
    this.name,
    this.email,
    this.error,
  });
}

class PaymentSummary {
  final double totalRevenue;
  final double thisMonth;
  final double pending;
  final double refunded;

  const PaymentSummary({
    required this.totalRevenue,
    required this.thisMonth,
    required this.pending,
    required this.refunded,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> j) => PaymentSummary(
    totalRevenue: _number(j['total_revenue']),
    thisMonth: _number(j['this_month']),
    pending: _number(j['pending']),
    refunded: _number(j['refunded']),
  );
}

class AdminReport {
  final String range;
  final PlatformStats stats;
  final List<MonthlyRevenue> monthlyRevenue;
  final List<CategoryRevenue> revenueByCategory;
  final List<TopTailor> topTailors;
  // Order counts by tab label: Pending, In Progress, Completed, Cancelled.
  final Map<String, int> orderStatusDistribution;

  const AdminReport({
    required this.range,
    required this.stats,
    required this.monthlyRevenue,
    required this.revenueByCategory,
    required this.topTailors,
    required this.orderStatusDistribution,
  });

  // [range] is the label the screen asked with, such as "This Month".
  factory AdminReport.fromJson(Map<String, dynamic> j, String range) {
    final byStatus = <String, int>{};
    for (final entry in Map<String, dynamic>.from(j['order_status_distribution'] ?? {}).entries) {
      final label = orderStatusLabel(entry.key);
      byStatus[label] = (byStatus[label] ?? 0) + ((entry.value ?? 0) as num).toInt();
    }
    final categories = (j['revenue_by_category'] ?? []) as List;
    return AdminReport(
      range: range,
      stats: PlatformStats.fromJson(Map<String, dynamic>.from(j['stats'] as Map)),
      monthlyRevenue: [
        for (final m in (j['monthly_revenue'] ?? []) as List) MonthlyRevenue.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
      revenueByCategory: [
        for (var i = 0; i < categories.length; i++)
          CategoryRevenue.fromJson(Map<String, dynamic>.from(categories[i] as Map), i),
      ],
      topTailors: [
        for (final t in (j['top_tailors'] ?? []) as List) TopTailor.fromJson(Map<String, dynamic>.from(t as Map)),
      ],
      orderStatusDistribution: byStatus,
    );
  }
}

class AdminSettings {
  double commissionRate;
  final List<String> categories;
  bool notifyNewOrder;
  bool notifyOrderComplete;
  bool notifyNewVerification;
  bool notifyDispute;
  bool notifyPayment;
  bool notifyMarketing;
  bool twoFaEnabled;
  int sessionTimeout;

  AdminSettings({
    required this.commissionRate,
    required this.categories,
    required this.notifyNewOrder,
    required this.notifyOrderComplete,
    required this.notifyNewVerification,
    required this.notifyDispute,
    required this.notifyPayment,
    required this.notifyMarketing,
    required this.twoFaEnabled,
    required this.sessionTimeout,
  });

  factory AdminSettings.fromJson(Map<String, dynamic> j) => AdminSettings(
    commissionRate: _number(j['commission_rate']),
    categories: List<String>.from(j['categories'] ?? const []),
    notifyNewOrder: j['notify_new_order'] ?? false,
    notifyOrderComplete: j['notify_order_complete'] ?? false,
    notifyNewVerification: j['notify_new_verification'] ?? false,
    notifyDispute: j['notify_dispute'] ?? false,
    notifyPayment: j['notify_payment'] ?? false,
    notifyMarketing: j['notify_marketing'] ?? false,
    twoFaEnabled: j['two_fa_enabled'] ?? false,
    sessionTimeout: j['session_timeout'] ?? 30,
  );

  // Categories change through their own endpoints, so they are left out.
  Map<String, dynamic> toJson() => {
    'commission_rate': commissionRate,
    'notify_new_order': notifyNewOrder,
    'notify_order_complete': notifyOrderComplete,
    'notify_new_verification': notifyNewVerification,
    'notify_dispute': notifyDispute,
    'notify_payment': notifyPayment,
    'notify_marketing': notifyMarketing,
    'two_fa_enabled': twoFaEnabled,
    'session_timeout': sessionTimeout,
  };
}
