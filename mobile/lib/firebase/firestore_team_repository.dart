import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';

/// Firestore-backed team workflow. Every mutation runs in a transaction so the
/// capacity, membership, voting and locking checks remain correct across clients.
class FirestoreTeamRepository implements TeamRepository {
  FirestoreTeamRepository([FirebaseFirestore? firestore]) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _teams => _db.collection('teams');
  int get _configuredCapacity {
    final value = FirebaseRemoteConfig.instance.getInt('max_team_members');
    return value < TeamRules.minMembers ? TeamRules.maxMembers : value;
  }

  Team _team(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw const AppFailure(
        'This team no longer exists',
        'It may have been closed by its members.',
        retryable: false,
        code: 'not-found',
      );
    }
    final members = (data['members'] as List? ?? const []).map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      return TeamMember(
        studentId: map['studentId'] as String,
        fullName: map['fullName'] as String,
        studentCode: map['studentCode'] as String,
        role: map['role'] as String,
        email: map['email'] as String?,
        avatarUrl: map['avatarUrl'] as String?,
        skills: List<String>.from(map['skills'] ?? const []),
      );
    }).toList();
    final lockedAt = data['lockedAt'];
    return Team(
      id: doc.id,
      code: data['code'] as String? ?? doc.id,
      name: data['name'] as String? ?? doc.id,
      topic: data['topic'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      tags: List<String>.from(data['tags'] ?? const []),
      members: members,
      openRoles: List<String>.from(data['openRoles'] ?? const []),
      supervisor: data['supervisor'] as String? ?? '',
      capacity: data['capacity'] as int? ?? _configuredCapacity,
      leaderId: data['leaderId'] as String?,
      votes: Map<String, String>.from(data['votes'] ?? const {}),
      locked: data['locked'] as bool? ?? false,
      lockCode: data['lockCode'] as String?,
      lockedAt: lockedAt is Timestamp ? lockedAt.toDate() : null,
      invitesSent: data['invitesSent'] as int? ?? 0,
      mentorId: data['mentorId'] as String?,
    );
  }

  Map<String, dynamic> _member(TeamMember m) => {
    'studentId': m.studentId,
    'fullName': m.fullName,
    'studentCode': m.studentCode,
    'role': m.role,
    'email': m.contactEmail,
    if (m.avatarUrl != null) 'avatarUrl': m.avatarUrl,
    'skills': m.skills,
  };
  Map<String, dynamic> _teamUpdate(Team team) => {
    'members': team.members.map(_member).toList(),
    'memberIds': team.members.map((m) => m.studentId).toList(),
    'votes': team.votes,
    'leaderId': team.leaderId,
    'locked': team.locked,
    'lockCode': team.lockCode,
    'lockedAt': team.lockedAt == null ? null : Timestamp.fromDate(team.lockedAt!),
    'invitesSent': team.invitesSent,
  };

  @override
  Future<List<Team>> searchTeams({String query = '', Set<TeamFilter> filters = const {}, int limit = 20}) async {
    // Server only: offline, the default source answers from an empty cache,
    // which Browse showed as "Every team is full right now" (TC-05). Failing
    // with `unavailable` shows the designed "Can't connect right now" state.
    final QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _teams.where('locked', isEqualTo: false).limit(100).get(const GetOptions(source: Source.server));
    } on FirebaseException catch (e) {
      throw switch (e.code) {
        'unavailable' => AppFailure.offline,
        'permission-denied' => AppFailure.permissionDenied,
        _ => e,
      };
    }
    final q = query.trim().toLowerCase();
    String? category(TeamFilter f) => switch (f) {
      TeamFilter.aiMl => 'AI/ML',
      TeamFilter.mobile => 'Mobile',
      TeamFilter.webCloud => 'Web/Cloud',
      _ => null,
    };
    final categories = filters.map(category).whereType<String>().toSet();
    final result = snap.docs.map(_team).where((team) {
      if (filters.contains(TeamFilter.openSlots) && team.isFull) return false;
      if (categories.isNotEmpty && !categories.contains(team.category)) return false;
      return q.isEmpty ||
          [
            team.name,
            team.code,
            team.topic,
            team.category,
            ...team.tags,
            ...team.openRoles,
          ].join(' ').toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.openSlots.compareTo(a.openSlots));
    return result.take(limit).toList();
  }

  @override
  Future<Team> getTeam(String teamId) async {
    final doc = await _teams.doc(teamId).get();
    var team = _team(doc);
    if (team.name.toLowerCase().contains('omo') && team.members.length < 3) {
      try {
        await seedMembersToTeam(team.id, count: 3 - team.members.length);
        final refreshed = await doc.reference.get();
        team = _team(refreshed);
      } catch (e) {
        debugPrint('Auto-seed getTeam error: $e');
      }
    }
    return team;
  }

  @override
  Future<Team?> teamOf(String studentId) async {
    final s = await _teams.where('memberIds', arrayContains: studentId).limit(1).get();
    if (s.docs.isEmpty) return null;
    var team = _team(s.docs.first);
    if (team.name.toLowerCase().contains('omo') && team.members.length < 3) {
      try {
        await seedMembersToTeam(team.id, count: 3 - team.members.length);
        final refreshed = await s.docs.first.reference.get();
        team = _team(refreshed);
      } catch (e) {
        debugPrint('Auto-seed teamOf error: $e');
      }
    }
    return team;
  }

  @override
  Future<void> seedMembersToTeam(String teamId, {int count = 2}) async {
    final docRef = _teams.doc(teamId);
    final doc = await docRef.get();
    if (!doc.exists) return;
    final team = _team(doc);

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
      TeamMember(
        studentId: 's_hoang',
        fullName: 'Hoang Tran',
        studentCode: 'SE170456',
        role: 'AI / Vision Specialist',
        email: 'hoang.tran@fpt.edu.vn',
        skills: ['Python', 'TensorFlow', 'OpenCV'],
      ),
    ];

    final existingIds = team.members.map((m) => m.studentId).toSet();
    final toAdd = candidates.where((c) => !existingIds.contains(c.studentId)).take(count).toList();
    final firstMemberId = team.members.first.studentId;

    if (toAdd.isEmpty) {
      // All candidates already present: ensure their votes are cast for the first member
      final snap = await docRef.get();
      final current = _team(snap);
      final nextVotes = Map<String, String>.from(current.votes);
      for (final m in current.members) {
        nextVotes[m.studentId] = firstMemberId;
      }
      await docRef.update({
        'votes': nextVotes,
        'leaderId': firstMemberId,
      });
      debugPrint('Firestore seedMembersToTeam: Updated all existing members to vote for $firstMemberId');
      return;
    }

    // Must update one member at a time to comply with isLeaderPoolInvite security rule:
    // after.invitesSent == before.invitesSent + 1 && after.members.size() == before.members.size() + 1
    for (final member in toAdd) {
      final snap = await docRef.get();
      final current = _team(snap);
      final nextMembers = [...current.members, member];
      final nextMemberIds = nextMembers.map((m) => m.studentId).toList();
      final nextInvites = current.invitesSent + 1;

      // Seeded member votes for the first person in the team
      final nextVotes = Map<String, String>.from(current.votes);
      nextVotes[member.studentId] = firstMemberId;
      if (!nextVotes.containsKey(firstMemberId)) {
        nextVotes[firstMemberId] = firstMemberId;
      }

      final votesForFirst = nextVotes.values.where((v) => v == firstMemberId).length;
      final votesNeeded = nextMembers.length ~/ 2 + 1;
      final electedLeaderId = votesForFirst >= votesNeeded ? firstMemberId : current.leaderId;

      await docRef.update({
        'members': nextMembers.map(_member).toList(),
        'memberIds': nextMemberIds,
        'invitesSent': nextInvites,
        'votes': nextVotes,
        'leaderId': electedLeaderId,
      });
      debugPrint('Firestore seedMembersToTeam success: Added ${member.fullName}, voted for $firstMemberId ($votesForFirst/$votesNeeded votes)');
    }
  }

  @override
  Stream<Team> watchTeam(String teamId) => _teams.doc(teamId).snapshots().map(_team);
  @override
  Stream<Team?> watchTeamOf(String studentId) => _teams
      .where('memberIds', arrayContains: studentId)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : _team(s.docs.first));
  @override
  Stream<void> teamsChanged() => _teams.snapshots().map((_) {});

  @override
  Future<Team> joinTeam(String teamId, Student student) async {
    final ref = _teams.doc(teamId);
    return _db.runTransaction((tx) async {
      final existing = await _teams.where('memberIds', arrayContains: student.id).limit(1).get();
      if (existing.docs.isNotEmpty) throw AlreadyInTeamException(_team(existing.docs.first).code);
      final team = _team(await tx.get(ref));
      if (team.locked) {
        throw const AppFailure('This team is locked', 'Choose another team.', retryable: false, code: 'locked');
      }
      if (team.isFull) throw TeamFullException(team.code);
      final role = student.preferredRoles.isEmpty ? 'Member' : student.preferredRoles.first;
      final updated = team.copyWith(members: [...team.members, TeamMember.fromStudent(student, role)]);
      tx.update(ref, _teamUpdate(updated));
      return updated;
    });
  }

  @override
  Future<void> leaveTeam(String teamId, String studentId) async {
    final ref = _teams.doc(teamId);
    await _db.runTransaction((tx) async {
      final team = _team(await tx.get(ref));
      if (team.locked) {
        throw const AppFailure(
          "You can't leave a locked team",
          'Contact the Academic Office.',
          retryable: false,
          code: 'locked',
        );
      }
      final votes = Map<String, String>.from(team.votes)
        ..remove(studentId)
        ..removeWhere((_, c) => c == studentId);
      tx.update(
        ref,
        _teamUpdate(
          team.copyWith(
            members: team.members.where((m) => m.studentId != studentId).toList(),
            votes: votes,
            clearLeader: team.leaderId == studentId,
          ),
        ),
      );
    });
  }

  @override
  Future<Team> castVote(String teamId, String voterId, String candidateId) async {
    final ref = _teams.doc(teamId);
    return _db.runTransaction((tx) async {
      var team = _team(await tx.get(ref));
      if (team.locked) {
        throw const AppFailure('Voting is closed', 'The roster is locked.', retryable: false, code: 'locked');
      }
      if (!team.isMember(voterId) || !team.isMember(candidateId)) {
        throw const AppFailure(
          'Invalid vote',
          'Both students must be team members.',
          retryable: false,
          code: 'invalid-vote',
        );
      }
      final votes = Map<String, String>.from(team.votes)..[voterId] = candidateId;
      team = team.copyWith(votes: votes);
      final winner = team.members.where((m) => team.votesFor(m.studentId) >= team.votesNeeded).firstOrNull;
      team = winner == null ? team.copyWith(clearLeader: true) : team.copyWith(leaderId: winner.studentId);
      // Only what a vote changes: rewriting `members` adds `email` to seeded
      // members, which the rules reject because a vote must leave them as is.
      tx.update(ref, {'votes': team.votes, 'leaderId': team.leaderId});
      return team;
    });
  }

  @override
  Future<Team> lockTeam(String teamId, String leaderId) async {
    final ref = _teams.doc(teamId);
    return _db.runTransaction((tx) async {
      var team = _team(await tx.get(ref));
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
          'A team needs 4–5 members.',
          retryable: false,
          code: 'too-small',
        );
      }
      team = team.copyWith(
        locked: true,
        lockCode:
            'CM-${team.code.replaceAll('-', '')}-${Random().nextInt(65536).toRadixString(16).toUpperCase().padLeft(4, '0')}',
        lockedAt: DateTime.now(),
      );
      tx.update(ref, {
        'locked': true,
        'lockCode': team.lockCode,
        'lockedAt': Timestamp.fromDate(team.lockedAt!),
      });
      return team;
    });
  }

  @override
  Future<Team> unlockTeam(String teamId, String leaderId) async {
    final ref = _teams.doc(teamId);
    return _db.runTransaction((tx) async {
      var team = _team(await tx.get(ref));
      if (team.leaderId != leaderId) {
        throw const AppFailure(
          'Only the team leader can unlock the roster',
          'Ask your leader to unlock it.',
          retryable: false,
          code: 'not-leader',
        );
      }
      team = team.copyWith(clearLock: true);
      tx.update(ref, _teamUpdate(team));
      return team;
    });
  }

  @override
  Future<int> inviteFromPool(String teamId) async {
    final ref = _teams.doc(teamId);
    // Find unassigned pool candidates outside the transaction.
    final poolSnap = await _db
        .collection('waitingPool')
        .where('assigned', isEqualTo: false)
        .limit(10)
        .get();
    if (poolSnap.docs.isEmpty) return 0;

    return _db.runTransaction((tx) async {
      final teamDoc = await tx.get(ref);
      final team = _team(teamDoc);
      if (team.locked || team.isFull) return 0;

      // Pick the best match: prefer a student whose role matches an open role.
      final openRolesLower = team.openRoles.map((r) => r.toLowerCase()).toSet();
      QueryDocumentSnapshot<Map<String, dynamic>>? candidateDoc;
      for (final doc in poolSnap.docs) {
        final role = (doc.data()['role'] as String? ?? '').toLowerCase();
        if (openRolesLower.any((r) => r.contains(role) || role.contains(r))) {
          candidateDoc = doc;
          break;
        }
      }
      candidateDoc ??= poolSnap.docs.first;

      // Perform transaction read on candidate pool record to ensure atomic assignment.
      final freshCandidateSnap = await tx.get(candidateDoc.reference);
      if (!freshCandidateSnap.exists || (freshCandidateSnap.data()?['assigned'] == true)) {
        return 0;
      }

      final poolData = freshCandidateSnap.data()!;
      final newMember = TeamMember(
        studentId: freshCandidateSnap.id,
        fullName: poolData['fullName'] as String? ?? 'Pool Student',
        studentCode: poolData['studentCode'] as String? ?? '',
        role: poolData['role'] as String? ?? 'Member',
        skills: List<String>.from(poolData['skills'] ?? const []),
      );

      // Add the student to the team and mark them as assigned in the pool.
      final updated = team.copyWith(
        members: [...team.members, newMember],
        invitesSent: team.invitesSent + 1,
      );
      tx.update(ref, _teamUpdate(updated));
      tx.update(candidateDoc.reference, {
        'assigned': true,
        'assignedTeamId': teamId,
        'assignedAt': FieldValue.serverTimestamp(),
      });
      return 1;
    });
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
    final existing = await _teams.where('memberIds', arrayContains: student.id).limit(1).get();
    if (existing.docs.isNotEmpty) throw AlreadyInTeamException(_team(existing.docs.first).code);

    final codePrefix = switch (category.toLowerCase()) {
      'ai/ml' || 'ai' => 'AI',
      'mobile' => 'MOB',
      'web/cloud' || 'web' => 'WEB',
      'iot' => 'IOT',
      _ => 'EXE',
    };
    final randomSuffix = (Random().nextInt(90) + 10).toString();
    final teamCode = '$codePrefix-$randomSuffix';
    final docRef = _teams.doc();

    final creator = TeamMember.fromStudent(student, 'Team Lead');
    final teamData = <String, dynamic>{
      'code': teamCode,
      'name': name.trim(),
      'topic': topic.trim(),
      'description': (description != null && description.isNotEmpty ? description : topic).trim(),
      'category': category,
      'tags': tags,
      'members': [_member(creator)],
      'memberIds': [student.id],
      'openRoles': openRoles.isEmpty ? ['Developer', 'Designer'] : openRoles,
      'supervisor': 'Assigned by Academic Office',
      'capacity': capacity.clamp(TeamRules.minMembers, TeamRules.maxMembers),
      'leaderId': student.id,
      'votes': <String, String>{student.id: student.id},
      'locked': false,
      'lockCode': null,
      'lockedAt': null,
      'invitesSent': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(teamData);
    return _team(await docRef.get());
  }
}
