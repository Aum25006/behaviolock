import 'dart:convert';
import 'dart:io';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phoneNumber;
  final DateTime? lastLogin;
  final Map<String, dynamic>? behaviorMetrics;
  final bool hasMpin;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.lastLogin,
    this.behaviorMetrics,
    this.hasMpin = false,
  });

  // Convert UserModel to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'lastLogin': lastLogin?.toIso8601String(),
      'behaviorMetrics': behaviorMetrics,
      'has_mpin': hasMpin,
    };
  }

  // Convert UserModel to JSON string
  String toJson() => jsonEncode(toMap());

  // Create UserModel from JSON string
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  // Helper method to parse date from different formats
  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    final dateStr = dateValue.toString().trim();
    if (dateStr.isEmpty) return null;

    // Prefer HTTP/RFC first (e.g., 'Wed, 13 Aug 2025 14:26:30 GMT')
    if (dateStr.contains(',') &&
        (dateStr.contains('GMT') || dateStr.contains('UTC'))) {
      try {
        return HttpDate.parse(dateStr);
      } catch (_) {}
    }

    // ISO 8601 next
    try {
      final iso = DateTime.tryParse(dateStr);
      if (iso != null) return iso;
    } catch (_) {}

    // Fallback: attempt HTTP/RFC again even without the heuristic
    try {
      return HttpDate.parse(dateStr);
    } catch (_) {}

    return null;
  }

  // Create UserModel from Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Handle both snake_case and camelCase for backend compatibility
    final phoneNumber = map['phone_number'] ?? map['phoneNumber'];
    final lastLogin = map['last_login'] ?? map['lastLogin'];

    return UserModel(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phoneNumber: phoneNumber?.toString(),
      lastLogin: _parseDate(lastLogin),
      behaviorMetrics: map['behaviorMetrics'] as Map<String, dynamic>?,
      hasMpin: map['has_mpin'] == true,
    );
  }

  // Copy with method for immutability
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phoneNumber,
    DateTime? lastLogin,
    Map<String, dynamic>? behaviorMetrics,
    bool? hasMpin,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lastLogin: lastLogin ?? this.lastLogin,
      behaviorMetrics: behaviorMetrics ?? this.behaviorMetrics,
      hasMpin: hasMpin ?? this.hasMpin,
    );
  }
}
