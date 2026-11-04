import 'dart:async';
import 'dart:math';

import '../../models/app_notification.dart';
import '../../models/student.dart';
import '../../models/team.dart';
import '../../models/view_state.dart';
import '../services.dart';
import 'local_database.dart';

/// Development implementation of [TeamRepository] over [LocalDatabase].
/// The Firestore implementation must keep the same rules (they are the
/// server-side checks: capacity, majority, 4–5 members to lock).
class LocalTeamRepository implements TeamRepository {
  LocalTeamRepository(this._db, {this.poolAcceptDelay = const Duration(seconds: 6)});

  final LocalDatabase _db;

  /// How long until a Waiting Pool student accepts an invite (simulated server event).
  final Duration poolAcceptDelay;

  static const _categoryOf = {TeamFilter.aiMl: 'AI/ML', TeamFilter.mobile: 'Mobile', TeamFilter.webCloud: 'Web/Cloud'};

  @override
  Future<List<Team>> searchTeams({String query = '', Set<TeamFilter> filters = const {}, int limit = 20}) async {
    await _db.roundTrip();
    final q = query.trim().toLowerCase();
    final categories = {
      for (final f in filters)
        if (_categoryOf[f] != null) _categoryOf[f]!,
    };
    final results =
        _db.teams.values.where((t) {
            if (t.locked) return false;
            if (filters.contains(TeamFilter.openSlots) && t.isFull) return false;
            if (categories.isNotEmpty && !categories.contains(t.category)) return false;
            if (q.isEmpty) return true;
            final haystack = [t.name, t.code, t.topic, t.category, ...t.tags, ...t.openRoles].join(' ').toLowerCase();
            return haystack.contains(q);
          }).toList()
          // Teams that need people most come first, then by name.
          ..sort((a, b) {
            final bySlots = b.openSlots.compareTo(a.openSlots);
            return bySlots != 0 ? bySlots : a.name.compareTo(b.name);
          });
    return results.take(limit).toList();
  }

  /// The stored team, or the same not-found failure for every operation (CR-05).
  Team _team(String teamId) {
    final team = _db.teams[teamId];
    if (team == null) {
      throw const AppFailure(
        "This team no longer exists",
        'It may have been closed by its members. Go back and pick another team.',
        retryable: false,
        code: 'not-found',
      );
    }
    return team;
  }

  @override
  Future<Team> getTeam(String teamId) async {
    await _db.roundTrip();
    return _team(teamId);
  }

  @override
  Future<Team?> teamOf(String studentId) async {
    await _db.roundTrip();
    return _db.teams.values.where((t) => t.isMember(studentId)).firstOrNull;
  }

  @override
  Stream<Team> watchTeam(String teamId) => _db.teamChanges.where((t) => t.id == teamId);

  @override
  Stream<void> teamsChanged() => _db.teamChanges.map((_) {});

  @override
  Stream<Team?> watchTeamOf(String studentId) =>
      _db.teamChanges.map((_) => _db.teams.values.where((t) => t.isMember(studentId)).firstOrNull);

  @override
  Future<Team> joinTeam(String teamId, Student student) async {
    await _db.roundTrip();
    final current = _db.teams.values.where((t) => t.isMember(student.id)).firstOrNull;
    if (current != null) throw AlreadyInTeamException(current.code);
    var team = _team(teamId);
    if (_db.fillsOnNextJoin.remove(teamId)) {
      // Seeded race: another student took the last slot a moment earlier.
      team = team.copyWith(
        members: [
          ...team.members,
          const TeamMember(studentId: 's_other', fullName: 'Khoa Pham', studentCode: 'SE170999', role: 'Backend'),
        ],
      );
      _db.putTeam(team);
    }
    if (team.isFull) throw TeamFullException(team.code);
    final role = student.preferredRoles.isEmpty ? 'Member' : student.preferredRoles.first;
    team = team.copyWith(members: [...team.members, TeamMember.fromStudent(student, role)]);
    _db.putTeam(team);
    return team;
  }

  @override
  Future<void> leaveTeam(String teamId, String studentId) async {
    await _db.roundTrip();
    final team = _team(teamId);
    if (team.locked) {
      throw const AppFailure(
        "You can't leave a locked team",
        'The roster was submitted to the Academic Office. Contact them to change it.',
        retryable: false,
        code: 'locked',
      );
    }
    final votes = Map<String, String>.from(team.votes)
      ..remove(studentId)
      ..removeWhere((_, candidate) => candidate == studentId);
    _db.putTeam(
      team.copyWith(
        members: team.members.where((m) => m.studentId != studentId).toList(),
        votes: votes,
        clearLeader: team.leaderId == studentId,
      ),
    );
  }

  @override
  Future<Team> castVote(String teamId, String voterId, String candidateId) async {
    await _db.roundTrip();
    var team = _team(teamId);
    if (team.locked) {
      throw const AppFailure(
        "Voting is closed",
        'This team is locked, so its leader can no longer change.',
        retryable: false,
        code: 'locked',
      );
    }
    final votes = Map<String, String>.from(team.votes)..[voterId] = candidateId;
    team = team.copyWith(votes: votes);
    final winner = team.members.where((m) => team.votesFor(m.studentId) >= team.votesNeeded).firstOrNull;
    team = winner == null ? team.copyWith(clearLeader: true) : team.copyWith(leaderId: winner.studentId);
    _db.putTeam(team);
    return team;
  }

  @override
  Future<Team> lockTeam(String teamId, String leaderId) async {
    await _db.roundTrip();
    var team = _team(teamId);
    if (team.leaderId != leaderId) {
      throw const AppFailure(
        'Only the team leader can lock the roster',
        'Ask your leader to review and lock it.',
        retryable: false,
        code: 'not-leader',
      );
    }
    if (!team.meetsSizeRule) {
      throw AppFailure(
        "Can't lock yet: ${team.memberCount} of ${team.capacity} members",
        'FPT Capstone rules require at least ${TeamRules.minMembers} members.',
        retryable: false,
        code: 'too-small',
      );
    }
    final code =
        'CM-${team.code.replaceAll('-', '')}-${(Random(team.id.hashCode).nextInt(0xFFFF)).toRadixString(16).toUpperCase().padLeft(4, '0')}';
    team = team.copyWith(locked: true, lockCode: code, lockedAt: DateTime.now());
    _db.putTeam(team);
    return team;
  }

  @override
  Future<Team> unlockTeam(String teamId, String leaderId) async {
    await _db.roundTrip();
    var team = _team(teamId);
    if (team.leaderId != leaderId) {
      throw const AppFailure(
        'Only the team leader can unlock the roster',
        'Ask your leader to unlock it.',
        retryable: false,
        code: 'not-leader',
      );
    }
    team = team.copyWith(clearLock: true);
    _db.putTeam(team);
    return team;
  }

  @override
  Future<int> inviteFromPool(String teamId) async {
    await _db.roundTrip();
    final team = _team(teamId);
    final invited = max(1, (_db.seed['pool']['studentsInPool'] as int) ~/ 8);
    _db.putTeam(team.copyWith(invitesSent: team.invitesSent + invited));

    // Simulated server event: the first matching pool student accepts.
    // The student leaves the pool only when they actually join (CR-04), and a
    // second invite before then cannot add them twice.
    final candidate = _db.poolStudents.firstOrNull;
    if (candidate != null) {
      Timer(poolAcceptDelay, () {
        final latest = _db.teams[teamId];
        if (latest == null || latest.locked || latest.isFull) return;
        if (!_db.poolStudents.remove(candidate)) return;
        final updated = latest.copyWith(members: [...latest.members, candidate]);
        _db.putTeam(updated);
        for (final m in latest.members) {
          _db.addNotification(
            m.studentId,
            AppNotification(
              id: 'pool_${DateTime.now().millisecondsSinceEpoch}',
              kind: NotificationKind.application,
              title: 'Joined: ${candidate.fullName} · ${candidate.role}',
              body:
                  '${candidate.fullName} accepted your Waiting Pool invite. '
                  '${updated.name} now has ${updated.memberCount} of ${updated.capacity} members.',
              createdAt: DateTime.now(),
              teamId: teamId,
              actionLabel: 'Review & Lock',
            ),
          );
        }
      });
    }
    return invited;
  }

  @override
  Future<Team> createTeam({
    required Student student,
    required String name,
    required String topic,
    required String category,
    String? description,
    List<String> tags = const [],
    List<String> openRoles = const [],
    int capacity = 5,
  }) async {
    await _db.roundTrip();
    final existing = _db.teams.values.where((t) => t.isMember(student.id)).firstOrNull;
    if (existing != null) throw AlreadyInTeamException(existing.code);

    final id = 'team_${DateTime.now().millisecondsSinceEpoch}';
    final codePrefix = switch (category.toLowerCase()) {
      'ai/ml' || 'ai' => 'AI',
      'mobile' => 'MOB',
      'web/cloud' || 'web' => 'WEB',
      'iot' => 'IOT',
      _ => 'EXE',
    };
    final code = '$codePrefix-${Random().nextInt(900) + 100}';
    final creator = TeamMember.fromStudent(student, 'Team Lead');
    final team = Team(
      id: id,
      code: code,
      name: name.trim(),
      topic: topic.trim(),
      description: (description != null && description.isNotEmpty ? description : topic).trim(),
      category: category,
      tags: tags,
      members: [creator],
      openRoles: openRoles.isEmpty ? const ['Developer', 'Designer'] : openRoles,
      supervisor: 'Assigned by Academic Office',
      capacity: capacity.clamp(TeamRules.minMembers, TeamRules.maxMembers),
      leaderId: student.id,
      votes: {student.id: student.id},
    );
    _db.putTeam(team);
    return team;
  }

  @override
  Future<void> seedMembersToTeam(String teamId, {int count = 2}) async {
    await _db.roundTrip();
    final team = _db.teams[teamId];
    if (team == null) return;
    const candidates = [
      TeamMember(
        studentId: 's_an',
        fullName: 'An Tran',
        studentCode: 'SE161120',
        role: 'Backend Dev',
        email: 'an.tran@fpt.edu.vn',
        skills: ['Java', 'Spring Boot', 'PostgreSQL'],
      ),
      TeamMember(
        studentId: 's_quynh',
        fullName: 'Quynh Nguyen',
        studentCode: 'SE170189',
        role: 'Frontend Dev',
        email: 'quynh.nguyen@fpt.edu.vn',
        skills: ['Flutter', 'React', 'TypeScript'],
      ),
    ];
    final existingIds = team.members.map((m) => m.studentId).toSet();
    final toAdd = candidates.where((c) => !existingIds.contains(c.studentId)).take(count).toList();
    if (team.members.isEmpty) return;
    final firstId = team.members.first.studentId;

    final votes = Map<String, String>.from(team.votes);
    if (!votes.containsKey(firstId)) {
      votes[firstId] = firstId;
    }
    for (final m in toAdd) {
      votes[m.studentId] = firstId;
    }
    for (final m in team.members) {
      if (candidates.any((c) => c.studentId == m.studentId)) {
        votes[m.studentId] = firstId;
      }
    }

    final nextMembers = [...team.members, ...toAdd];
    final votesForFirst = votes.values.where((id) => id == firstId).length;
    final votesNeeded = nextMembers.length ~/ 2 + 1;
    final winner = votesForFirst >= votesNeeded ? firstId : team.leaderId;

    _db.putTeam(team.copyWith(
      members: nextMembers,
      votes: votes,
      leaderId: winner,
    ));
  }
}
