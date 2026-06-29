class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.preferences,
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final Map<String, dynamic> preferences;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? 'Guest',
    phone: (json['phone'] as String?) ?? '',
    role: (json['role'] as String?) ?? 'CUSTOMER',
    preferences: (json['preferences'] as Map?)?.cast<String, dynamic>() ?? {},
  );
}
