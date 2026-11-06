import 'package:cloud_firestore/cloud_firestore.dart';

/// A final team roster submitted by its leader for academic approval.
///
/// This is intentionally separate from a team document: the submitted roster
/// is an immutable audit snapshot while a rejected team may be unlocked and
/// corrected by its leader.
class TeamSubmission {
  const TeamSubmission({
    required this.id,
    required this.teamId,
    required this.leaderId,
    required this.teamName,
    required this.lockCode,
    required this.memberSnapshot,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reason = '',
  });

  final String id;
  final String teamId;
  final String leaderId;
  final String teamName;
  final String lockCode;
  final List<Map<String, dynamic>> memberSnapshot;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String reason;

  bool get isPending => status == 'pending';

  factory TeamSubmission.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime time(dynamic value) => value is Timestamp ? value.toDate() : DateTime.now();
    return TeamSubmission(
      id: id,
      teamId: data['teamId'] as String? ?? id,
      leaderId: data['leaderId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? 'Unnamed team',
      lockCode: data['lockCode'] as String? ?? '',
      memberSnapshot: (data['memberSnapshot'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      status: data['status'] as String? ?? 'pending',
      submittedAt: time(data['submittedAt']),
      reviewedAt: data['reviewedAt'] is Timestamp ? (data['reviewedAt'] as Timestamp).toDate() : null,
      reviewedBy: data['reviewedBy'] as String?,
      reason: data['reason'] as String? ?? '',
    );
  }
}
