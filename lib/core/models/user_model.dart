// ─── User Model ───────────────────────────────────────────────────────────────
// The user object of GET /api/users/me and the login response.

enum UserRole { customer, tailor }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatar;
  final UserRole role;
  final bool isVerified;
  final String? city;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isVerified,
    this.avatar,
    this.city,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    phone: json['phone'],
    role: UserRole.values.byName(json['role']),
    isVerified: json['is_verified'] ?? false,
    avatar: json['avatar'],
    city: json['city'],
    createdAt: DateTime.parse(json['created_at']).toLocal(),
  );

  String get initials => initialsOf(name);
}

// Up to [max] capital letters from a name, for avatars. Extra spaces are
// ignored, and an empty name gives '?'.
String initialsOf(String name, {int max = 2}) {
  final letters = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0])
      .take(max)
      .join()
      .toUpperCase();
  return letters.isEmpty ? '?' : letters;
}
