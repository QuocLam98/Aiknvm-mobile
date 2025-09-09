class AppUser {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String? role;
  final String? phone;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.role,
    this.phone,
  });
}
