import 'package:flutter/foundation.dart';

import '../models/student.dart';
import '../models/team.dart';
import '../models/view_state.dart';
import '../services/services.dart';
import 'guard.dart';

class CreateTeamViewModel extends ChangeNotifier {
  CreateTeamViewModel(this._student, this._teams, this._analytics, this._crash);

  final Student _student;
  final TeamRepository _teams;
  final AnalyticsService _analytics;
  final CrashReporter _crash;

  bool creating = false;
  AppFailure? failure;

  static const defaultCategories = [
    'Web/Cloud',
    'Mobile',
    'AI/ML',
    'IoT',
    'Fintech',
    'EdTech',
    'E-Commerce',
    'HealthTech',
  ];
  static const suggestedRoles = [
    'Frontend Dev',
    'Backend Dev',
    'Fullstack Dev',
    'Mobile Dev',
    'AI/ML Engineer',
    'UI/UX Designer',
    'QA/Tester',
    'DevOps Engineer',
    'Business Analyst (BA)',
    'Data Engineer',
    'Product Owner',
  ];
  static const suggestedTags = [
    'Flutter',
    'React',
    'React Native',
    'NodeJS',
    'Python',
    'Firebase',
    'Spring Boot',
    'Docker',
    'Next.js',
    'Vue.js',
    'NestJS',
    'FastAPI',
    '.NET',
    'Golang',
    'Swift',
    'Kotlin',
    'AWS',
    'Kubernetes',
    'GraphQL',
    'PostgreSQL',
    'MongoDB',
    'MySQL',
    'Redis',
    'TensorFlow',
    'PyTorch',
    'OpenCV',
    'IoT / Hardware',
    'Figma',
    'CI/CD',
    'Microservices',
  ];

  Future<Team?> createTeam({
    required String name,
    required String topic,
    required String category,
    String? description,
    List<String> tags = const [],
    List<String> openRoles = const [],
  }) async {
    creating = true;
    failure = null;
    notifyListeners();

    try {
      final team = await _teams.createTeam(
        student: _student,
        name: name,
        topic: topic,
        category: category,
        description: description,
        tags: tags,
        openRoles: openRoles,
      );
      await _analytics.logCreateTeam(teamId: team.id, teamCode: team.code);
      creating = false;
      notifyListeners();
      return team;
    } on AlreadyInTeamException catch (e) {
      creating = false;
      failure = AppFailure(
        'Already in a team',
        'You are already a member of team ${e.teamCode}. Leave your current team on My Team first.',
        code: 'already-in-team',
      );
      notifyListeners();
      return null;
    } catch (e, st) {
      creating = false;
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('permission-denied') || errStr.contains('permission')) {
        failure = const AppFailure(
          'Chưa mở quyền tạo nhóm trên Firestore',
          'Vui lòng cập nhật "allow create: if isRosterMember()..." trong tab Rules của Firestore Database trên Firebase Console rồi nhấn Publish.',
          code: 'permission-denied',
        );
      } else {
        failure = await toFailure(e, st, crash: _crash, reason: 'create_team');
      }
      notifyListeners();
      return null;
    }
  }
}

