import 'package:flutter/foundation.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

import '../services/services.dart';

/// Firebase Analytics implementation for user actions tracking.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService([FirebaseAnalytics? analytics]) : _analytics = analytics ?? FirebaseAnalytics.instance;
  final FirebaseAnalytics _analytics;

  Future<void> _event(String name, Map<String, Object> parameters) async {
    debugPrint('analytics_event $name $parameters');
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      // Measurement must never turn a saved user action into an error message;
      // keep the cause visible in the log instead.
      debugPrint('analytics_event_failed $name: $e');
    }
  }

  @override
  Future<void> setUserId(String? id) async {
    debugPrint('analytics_event set_user_id {id: $id}');
    await _analytics.setUserId(id: id);
  }

  @override
  Future<void> logLogin({required String method}) async {
    debugPrint('analytics_event login {method: $method}');
    await _analytics.logLogin(loginMethod: method);
  }

  @override
  Future<void> logLogout() async {
    await _event('logout', {});
  }

  @override
  Future<void> logSearch({required String term, required int resultCount, required List<String> filters}) async {
    debugPrint('analytics_event search {search_term: $term, result_count: $resultCount}');
    await _event('search_teams', {
      'query_length': term.length,
      'result_count': resultCount,
      'filter_count': filters.length,
    });
  }

  @override
  Future<void> logViewTeam({required String teamId, required String teamCode}) async {
    await _event('view_team', {'team_id': teamId, 'team_code': teamCode});
  }

  @override
  Future<void> logCreateTeam({required String teamId, required String teamCode}) async {
    debugPrint('analytics_event create_team {team_id: $teamId, team_code: $teamCode}');
    await _event('create_team', {'team_id': teamId, 'team_code': teamCode});
  }

  @override
  Future<void> logJoinTeam({required String teamId, required int memberCount}) async {
    debugPrint('analytics_event join_group {group_id: $teamId, member_count: $memberCount}');
    await _event('join_team', {'team_id': teamId, 'member_count': memberCount});
  }

  @override
  Future<void> logVote({required String teamId, required bool changed}) async {
    // Analytics parameters must be String or num; a bool fails the SDK's check.
    await _event('cast_vote', {'team_id': teamId, 'changed': changed ? 1 : 0});
  }

  @override
  Future<void> logInviteFromPool({required String teamId, required int invited}) async {
    debugPrint('analytics_event invite_from_pool {team_id: $teamId, invited: $invited}');
    await _event('invite_pool', {'team_id': teamId, 'invited_count': invited});
  }

  @override
  Future<void> logLockRoster({required String teamId, required int memberCount}) async {
    await _event('lock_roster', {'team_id': teamId, 'member_count': memberCount});
  }

  @override
  Future<void> logExportReport({required String teamId, required int fileSizeKb}) async {
    await _event('export_report', {'team_id': teamId, 'file_size_kb': fileSizeKb});
  }

  @override
  Future<void> logViewMentor({required String mentorId}) async {
    await _event('view_mentor', {'mentor_id': mentorId});
  }

  @override
  Future<void> logRequestMentor({required String teamId, required String mentorId}) async {
    await _event('request_mentor', {'team_id': teamId, 'mentor_id': mentorId});
  }

  @override
  Future<void> logAiRequest({required String feature, required String model}) async {
    debugPrint('analytics_event ai_request {feature: $feature, model: $model}');
    await _event('ai_request', {'feature': feature, 'model': model});
  }

  @override
  Future<void> logAiResultAccepted({required String feature}) async {
    debugPrint('analytics_event ai_result_accepted {feature: $feature}');
    await _event('ai_result_accepted', {'feature': feature});
  }

  @override
  Future<void> logAiError({required String feature, required String errorReason}) async {
    debugPrint('analytics_event ai_error {feature: $feature, reason: $errorReason}');
    await _event('ai_error', {'feature': feature, 'reason': errorReason});
  }
}
