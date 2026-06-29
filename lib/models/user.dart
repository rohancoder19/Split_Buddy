class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password;
  final List<String> friendIds;
  final double? latitude;
  final double? longitude;
  final bool isOnline;
  final String? lastActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.friendIds,
    this.latitude,
    this.longitude,
    this.isOnline = false,
    this.lastActive,
  });
}
