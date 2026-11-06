class RosterEntry {
  const RosterEntry({
    required this.email,
    required this.fullName,
    this.studentCode = '',
    this.major = '',
    this.cohort = '',
    this.enabled = true,
  });

  final String email;
  final String fullName;
  final String studentCode;
  final String major;
  final String cohort;
  final bool enabled;

  factory RosterEntry.fromFirestore(String email, Map<String, dynamic> data) => RosterEntry(
    email: email,
    fullName: data['fullName'] as String? ?? '',
    studentCode: data['studentCode'] as String? ?? '',
    major: data['major'] as String? ?? '',
    cohort: data['cohort'] as String? ?? '',
    enabled: data['enabled'] as bool? ?? true,
  );

  Map<String, dynamic> toFirestore() => {
    'email': email,
    'fullName': fullName,
    'studentCode': studentCode,
    'major': major,
    'cohort': cohort,
    'enabled': enabled,
  };
}
