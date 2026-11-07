/// A signed-in user: a Capstone student, or a lecturer when [mentorId] is set.
class Student {
  const Student({
    required this.id,
    required this.email,
    required this.fullName,
    required this.studentCode,
    required this.major,
    required this.cohort,
    this.avatarUrl,
    this.skills = const [],
    this.preferredRoles = const [],
    this.mentorId,
  });

  final String id;
  final String email;
  final String fullName;
  final String studentCode;
  final String major;
  final String cohort;
  final String? avatarUrl;
  final List<String> skills;
  final List<String> preferredRoles;

  /// The lecturer's `mentors` document, from their roster entry (`allowedEmails`).
  final String? mentorId;

  bool get isMentor => mentorId != null;

  String get firstName => fullName.split(' ').first;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory Student.fromJson(Map<String, dynamic> j) => Student(
    id: j['id'] as String,
    email: j['email'] as String,
    fullName: j['fullName'] as String,
    studentCode: j['studentCode'] as String,
    major: j['major'] as String,
    cohort: j['cohort'] as String,
    avatarUrl: j['avatarUrl'] as String?,
    skills: List<String>.from(j['skills'] as List? ?? const []),
    preferredRoles: List<String>.from(j['preferredRoles'] as List? ?? const []),
  );
}
