class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'user', 'staff', 'admin'
  final DateTime? createdAt;

  /// The lecturer's `mentors` document; set by an admin on staff accounts.
  final String? mentorId;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = 'user',
    this.createdAt,
    this.mentorId,
  });

  bool get isStaff => role == 'staff' || role == 'admin';
  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate() as DateTime
          : null,
      mentorId: data['mentorId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}

