/// The registration window shown on Dashboard (Lab 2 SCR_02 countdown).
class RegistrationWindow {
  const RegistrationWindow({required this.semester, required this.closesAt, required this.opensAt});

  final String semester;
  final DateTime opensAt;
  final DateTime closesAt;

  bool isClosed(DateTime now) => !now.isBefore(closesAt);

  /// Share of the window already used, 0–1 (Figma: "73% elapsed").
  double elapsed(DateTime now) {
    final total = closesAt.difference(opensAt).inMinutes;
    if (total <= 0) return 1;
    return (now.difference(opensAt).inMinutes / total).clamp(0, 1).toDouble();
  }
}

/// Random Pool status for students left without a team (Lab 2 SCR_08).
class PoolStatus {
  const PoolStatus({
    required this.queueId,
    required this.progress,
    required this.stage,
    required this.expectedResult,
    required this.preferredRoles,
    required this.skills,
    required this.studentsInPool,
    required this.contactEmail,
    required this.lastChecked,
  });

  final String queueId;
  final double progress;
  final String stage;
  final DateTime expectedResult;
  final List<String> preferredRoles;
  final List<String> skills;
  final int studentsInPool;
  final String contactEmail;
  final DateTime lastChecked;
}
