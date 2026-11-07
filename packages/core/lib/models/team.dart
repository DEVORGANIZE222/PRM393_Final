import 'student.dart';

/// FPT Capstone rule (Lab 2 persona and DESIGN.md): a team locks with 4–5 members.
abstract final class TeamRules {
  static const int minMembers = 4;
  static const int maxMembers = 5;
}

class TeamMember {
  const TeamMember({
    required this.studentId,
    required this.fullName,
    required this.studentCode,
    required this.role,
    this.email,
    this.avatarUrl,
    this.skills = const [],
  });

  final String studentId;
  final String fullName;
  final String studentCode;
  final String role;
  final String? email;
  final String? avatarUrl;
  final List<String> skills;

  String get initials {
    final p = fullName.trim().split(RegExp(r'\s+'));
    return p.length == 1 ? p.first[0].toUpperCase() : (p.first[0] + p.last[0]).toUpperCase();
  }

  String get contactEmail {
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    final sc = studentCode.trim();
    if (sc.contains('@')) return sc;
    if (sc.toLowerCase() == 'danghoang862') return 'danghoang862@gmail.com';
    const knownMap = {
      's_minh': 'minh.le@fpt.edu.vn',
      'SE160234': 'minh.le@fpt.edu.vn',
      's_an': 'an.tran@fpt.edu.vn',
      'SE161120': 'an.tran@fpt.edu.vn',
      's_hoang': 'hoang.tran@fpt.edu.vn',
      'SE170456': 'hoang.tran@fpt.edu.vn',
      's_quynh': 'quynh.nguyen@fpt.edu.vn',
      'SE170189': 'quynh.nguyen@fpt.edu.vn',
      's_lam': 'lam.pham@fpt.edu.vn',
      'SE170311': 'lam.pham@fpt.edu.vn',
      's_vy': 'vy.dang@fpt.edu.vn',
      'SE170522': 'vy.dang@fpt.edu.vn',
      's_bao': 'bao.pham@fpt.edu.vn',
      'SE170777': 'bao.pham@fpt.edu.vn',
      's_nhi': 'nhi.ho@fpt.edu.vn',
      'SE170812': 'nhi.ho@fpt.edu.vn',
      's_tuan': 'tuan.do@fpt.edu.vn',
      'SE170845': 'tuan.do@fpt.edu.vn',
      's_mai': 'mai.vu@fpt.edu.vn',
      'SE170901': 'mai.vu@fpt.edu.vn',
      's_long': 'long.nguyen@fpt.edu.vn',
      'SE170120': 'long.nguyen@fpt.edu.vn',
      's_thao': 'thao.le@fpt.edu.vn',
      'SE170133': 'thao.le@fpt.edu.vn',
      's_duc': 'duc.bui@fpt.edu.vn',
      'SE170146': 'duc.bui@fpt.edu.vn',
      's_hai': 'hai.dang@fpt.edu.vn',
      'SE170201': 'hai.dang@fpt.edu.vn',
      's_kim': 'kim.tran@fpt.edu.vn',
      'SE170214': 'kim.tran@fpt.edu.vn',
      's_phat': 'phat.ly@fpt.edu.vn',
      'SE170227': 'phat.ly@fpt.edu.vn',
      's_quang': 'quang.ha@fpt.edu.vn',
      'SE170240': 'quang.ha@fpt.edu.vn',
      's_bich': 'bich.ngo@fpt.edu.vn',
      'SE170253': 'bich.ngo@fpt.edu.vn',
      's_khanh': 'khanh.vo@fpt.edu.vn',
      'SE171002': 'khanh.vo@fpt.edu.vn',
    };
    if (knownMap.containsKey(sc)) return knownMap[sc]!;
    if (knownMap.containsKey(studentId)) return knownMap[studentId]!;
    if (sc.startsWith('s_')) return '${sc.substring(2)}@fpt.edu.vn';
    if (sc.isNotEmpty) return '$sc@fpt.edu.vn';
    return '$studentId@fpt.edu.vn';
  }

  factory TeamMember.fromStudent(Student s, String role) => TeamMember(
    studentId: s.id,
    fullName: s.fullName,
    studentCode: s.studentCode,
    role: role,
    email: s.email,
    avatarUrl: s.avatarUrl,
    skills: s.skills,
  );

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    studentId: j['studentId'] as String,
    fullName: j['fullName'] as String,
    studentCode: j['studentCode'] as String,
    role: j['role'] as String,
    email: j['email'] as String?,
    avatarUrl: j['avatarUrl'] as String?,
    skills: List<String>.from(j['skills'] as List? ?? const []),
  );
}

/// A Capstone team. Derived getters only; the rules that change state live in
/// the repository and ViewModels.
class Team {
  const Team({
    required this.id,
    required this.code,
    required this.name,
    required this.topic,
    required this.description,
    required this.category,
    required this.tags,
    required this.members,
    required this.openRoles,
    required this.supervisor,
    this.capacity = TeamRules.maxMembers,
    this.leaderId,
    this.votes = const {},
    this.locked = false,
    this.lockCode,
    this.lockedAt,
    this.invitesSent = 0,
    this.mentorId,
  });

  final String id;

  /// Short code shown in the UI, e.g. "AI-04".
  final String code;

  /// Display name, e.g. "Team AI-04" or "FinTech Guard".
  final String name;
  final String topic;
  final String description;
  final String category;
  final List<String> tags;
  final List<TeamMember> members;
  final List<String> openRoles;
  final String supervisor;
  final int capacity;
  final String? leaderId;

  /// voterId → candidateId.
  final Map<String, String> votes;
  final bool locked;
  final String? lockCode;
  final DateTime? lockedAt;
  final int invitesSent;

  /// The lecturer who accepted this team; [supervisor] then holds their name.
  final String? mentorId;

  bool get hasMentor => mentorId != null;
  int get memberCount => members.length;
  int get openSlots => (capacity - memberCount).clamp(0, capacity);
  bool get isFull => openSlots == 0;
  bool get meetsSizeRule => memberCount >= TeamRules.minMembers && memberCount <= TeamRules.maxMembers;
  bool get hasLeader => leaderId != null && (locked || (memberCount >= 3 && votesFor(leaderId!) >= votesNeeded));
  bool isMember(String studentId) => members.any((m) => m.studentId == studentId);

  TeamMember? get leader => members.where((m) => m.studentId == leaderId).firstOrNull;

  int votesFor(String candidateId) => votes.values.where((c) => c == candidateId).length;

  /// A leader is elected by more than half of the current members
  /// (Lab 2 Flow 2: 3 votes in a 4–5 member team).
  int get votesNeeded => memberCount ~/ 2 + 1;

  Team copyWith({
    List<TeamMember>? members,
    String? leaderId,
    bool clearLeader = false,
    bool clearLock = false,
    Map<String, String>? votes,
    bool? locked,
    String? lockCode,
    DateTime? lockedAt,
    int? invitesSent,
    List<String>? openRoles,
    String? mentorId,
    String? supervisor,
  }) {
    return Team(
      id: id,
      code: code,
      name: name,
      topic: topic,
      description: description,
      category: category,
      tags: tags,
      members: members ?? this.members,
      openRoles: openRoles ?? this.openRoles,
      supervisor: supervisor ?? this.supervisor,
      capacity: capacity,
      leaderId: clearLeader ? null : (leaderId ?? this.leaderId),
      votes: votes ?? this.votes,
      locked: clearLock ? false : (locked ?? this.locked),
      lockCode: clearLock ? null : (lockCode ?? this.lockCode),
      lockedAt: clearLock ? null : (lockedAt ?? this.lockedAt),
      invitesSent: invitesSent ?? this.invitesSent,
      mentorId: mentorId ?? this.mentorId,
    );
  }

  factory Team.fromJson(Map<String, dynamic> j) => Team(
    id: j['id'] as String,
    code: j['code'] as String? ?? j['id'] as String,
    name: j['name'] as String? ?? j['id'] as String,
    topic: j['topic'] as String? ?? '',
    description: j['description'] as String? ?? '',
    category: j['category'] as String? ?? '',
    tags: List<String>.from(j['tags'] as List? ?? const []),
    members: [for (final m in j['members'] as List? ?? const []) TeamMember.fromJson(m as Map<String, dynamic>)],
    openRoles: List<String>.from(j['openRoles'] as List? ?? const []),
    supervisor: j['supervisor'] as String? ?? '',
    capacity: j['capacity'] as int? ?? TeamRules.maxMembers,
    leaderId: j['leaderId'] as String?,
    votes: Map<String, String>.from(j['votes'] as Map? ?? const {}),
    locked: j['locked'] as bool? ?? false,
    mentorId: j['mentorId'] as String?,
  );
}

/// Filters on Browse (Lab 2 SCR_03 chips).
enum TeamFilter {
  openSlots('Open Slots'),
  aiMl('AI/ML'),
  mobile('Mobile'),
  webCloud('Web/Cloud');

  const TeamFilter(this.label);
  final String label;
}
