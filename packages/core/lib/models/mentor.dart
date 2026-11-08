import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'student.dart';
import 'team.dart';
import 'view_state.dart';

enum MentorRequestStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const MentorRequestStatus(this.label);
  final String label;

  static MentorRequestStatus fromString(String? value) => switch (value) {
    'approved' => approved,
    'rejected' => rejected,
    _ => pending,
  };
}

/// A lecturer who can supervise Capstone teams, up to [maxQuota] per semester.
class Mentor {
  const Mentor({
    required this.id,
    required this.fullName,
    required this.email,
    required this.title,
    required this.department,
    required this.expertise,
    required this.bio,
    this.office = '',
    this.maxQuota = 5,
    this.currentAssigned = 0,
    this.mentoredTeamNames = const [],
    this.archived = false,
  });

  final String id;
  final String fullName;
  final String email;
  final String title;
  final String department;
  final List<String> expertise;
  final String bio;
  final String office;
  final int maxQuota;
  final int currentAssigned;
  final List<String> mentoredTeamNames;

  /// Archived lecturers stay on their teams but leave the student directory.
  final bool archived;

  bool get isAvailable => !archived && currentAssigned < maxQuota;
  int get remainingSlots => (maxQuota - currentAssigned).clamp(0, maxQuota);

  String get initials {
    final name = fullName.replaceFirst(RegExp(r'^(Dr|MSc|Prof|Assoc\.\s*Prof)\.\s*', caseSensitive: false), '');
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length == 1 ? parts.first[0].toUpperCase() : (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory Mentor.fromJson(Map<String, dynamic> j) => Mentor(
    id: j['id'] as String,
    fullName: j['fullName'] as String? ?? '',
    email: j['email'] as String? ?? '',
    title: j['title'] as String? ?? '',
    department: j['department'] as String? ?? '',
    expertise: List<String>.from(j['expertise'] as List? ?? const []),
    bio: j['bio'] as String? ?? '',
    office: j['office'] as String? ?? '',
    maxQuota: (j['maxQuota'] as num?)?.toInt() ?? 5,
    currentAssigned: (j['currentAssigned'] as num?)?.toInt() ?? 0,
    mentoredTeamNames: List<String>.from(j['mentoredTeamNames'] as List? ?? const []),
    archived: j['status'] == 'archived',
  );

  /// One more supervised team, after a request is accepted.
  Mentor withTeam(String teamName) => Mentor(
    id: id,
    fullName: fullName,
    email: email,
    title: title,
    department: department,
    expertise: expertise,
    bio: bio,
    office: office,
    maxQuota: maxQuota,
    currentAssigned: currentAssigned + 1,
    mentoredTeamNames: [...mentoredTeamNames, teamName],
    archived: archived,
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'title': title,
    'department': department,
    'expertise': expertise,
    'bio': bio,
    'office': office,
    'maxQuota': maxQuota,
    'currentAssigned': currentAssigned,
    'mentoredTeamNames': mentoredTeamNames,
    'status': archived ? 'archived' : 'active',
  };
}

/// A team's request for a lecturer to supervise it. A team has at most one:
/// the document id is the team id, so a second request cannot exist while one
/// is pending, and two lecturers cannot accept the same team.
class MentorRequest {
  const MentorRequest({
    required this.teamId,
    required this.teamName,
    required this.mentorId,
    required this.mentorName,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.status = MentorRequestStatus.pending,
    this.decisionReason,
  });

  final String teamId;
  final String teamName;
  final String mentorId;
  final String mentorName;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final MentorRequestStatus status;
  final String? decisionReason;

  bool get isPending => status == MentorRequestStatus.pending;
  bool get isRejected => status == MentorRequestStatus.rejected;

  factory MentorRequest.fromJson(Map<String, dynamic> d) {
    final createdAt = d['createdAt'];
    return MentorRequest(
      teamId: d['teamId'] as String,
      teamName: d['teamName'] as String? ?? '',
      mentorId: d['mentorId'] as String? ?? '',
      mentorName: d['mentorName'] as String? ?? '',
      senderId: d['senderId'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      message: d['message'] as String? ?? '',
      // Null while the server timestamp of a local write is still pending.
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      status: MentorRequestStatus.fromString(d['status'] as String?),
      decisionReason: d['decisionReason'] as String?,
    );
  }

  factory MentorRequest.create({
    required Team team,
    required Mentor mentor,
    required Student sender,
    required String message,
  }) => MentorRequest(
    teamId: team.id,
    teamName: team.name,
    mentorId: mentor.id,
    mentorName: mentor.fullName,
    senderId: sender.id,
    senderName: sender.fullName,
    message: message,
    createdAt: DateTime.now(),
  );

  MentorRequest decided({required bool accept, String? reason}) => MentorRequest(
    teamId: teamId,
    teamName: teamName,
    mentorId: mentorId,
    mentorName: mentorName,
    senderId: senderId,
    senderName: senderName,
    message: message,
    createdAt: createdAt,
    status: accept ? MentorRequestStatus.approved : MentorRequestStatus.rejected,
    decisionReason: reason,
  );
}

/// The checks both repositories run inside their write, so they hold against
/// what is stored now and not what the screen last loaded.
abstract final class MentorRules {
  /// Why [senderId] cannot ask [mentor] to supervise [team], or null if they can.
  static AppFailure? requestBlocker({
    required Team team,
    required Mentor mentor,
    required String senderId,
    MentorRequest? current,
  }) {
    if (!team.hasLeader || team.leaderId != senderId) {
      return const AppFailure(
        'Only the team leader can choose a mentor',
        'Ask your leader to send the request, or elect a leader first.',
        retryable: false,
        code: 'not-leader',
      );
    }
    if (team.hasMentor) {
      return AppFailure(
        'Your team already has a mentor',
        '${team.supervisor} supervises ${team.name}.',
        retryable: false,
        code: 'has-mentor',
      );
    }
    if (current != null && current.isPending) {
      return AppFailure(
        'A request is already waiting',
        'Withdraw your request to ${current.mentorName} before asking another mentor.',
        retryable: false,
        code: 'request-pending',
      );
    }
    if (!mentor.isAvailable) return _quotaFull(mentor);
    return null;
  }

  /// Why [mentor] cannot accept [request] for [team], or null if they can.
  static AppFailure? acceptBlocker({required MentorRequest request, required Team team, required Mentor mentor}) {
    if (!request.isPending || team.hasMentor) return requestClosed;
    if (!mentor.isAvailable) return _quotaFull(mentor);
    return null;
  }

  static const requestClosed = AppFailure(
    'This request is no longer open',
    'Pull down to refresh your requests.',
    retryable: false,
    code: 'request-closed',
  );

  static AppFailure _quotaFull(Mentor mentor) => AppFailure(
    'Mentor quota reached',
    '${mentor.fullName} already supervises ${mentor.maxQuota} teams this semester.',
    retryable: false,
    code: 'quota-full',
  );
}
