class AdminUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String verified; // e.g., "Đã xác thực" or "Chưa xác thực"
  final String createdAt; // display string
  final double credit; // tổng credit hiện có
  final double creditUsed; // credit đã sử dụng

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.verified,
    required this.createdAt,
    required this.credit,
    required this.creditUsed,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    String getStr(dynamic v) => (v ?? '').toString();
    double getD(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return AdminUser(
      id: getStr(json['id'] ?? json['_id']),
      name: getStr(json['name'] ?? json['fullName'] ?? json['username']),
      email: getStr(json['email']),
      phone: getStr(json['phone'] ?? json['phoneNumber']),
      role: getStr(json['role'] ?? 'user'),
      verified: getStr(
        json['verified'] ?? json['isVerified'] ?? json['emailVerified'] ?? '',
      ),
      createdAt: getStr(json['createdAt'] ?? json['created_at'] ?? ''),
      credit: getD(json['credit'] ?? json['credits']),
      creditUsed: getD(json['creditUsed'] ?? json['creditsUsed']),
    );
  }
}
