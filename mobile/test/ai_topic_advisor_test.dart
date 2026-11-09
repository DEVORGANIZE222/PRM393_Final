import 'package:flutter_test/flutter_test.dart';
import 'package:exematching/services/ai_topic_advisor_service.dart';
import 'package:exematching/services/services.dart';
import 'package:exematching/services/local/local_services.dart';

class _FakeConfigService implements ConfigService {
  _FakeConfigService({this.enabled = true, this.model = 'gemini-2.5-flash'});

  final bool enabled;
  final String model;

  @override
  bool getBool(String key) => key == 'enable_ai_feature' ? enabled : true;

  @override
  int getInt(String key) => 5;

  @override
  String getString(String key) => key == 'ai_model_name' ? model : '';

  @override
  Future<bool> refresh() async => false;

  @override
  Stream<void> get changes => const Stream.empty();
}

void main() {
  group('AiTopicAdvisorService - PII Sanitization', () {
    test('strips personal emails, student codes, and phone numbers', () {
      const raw =
          'Contact leader Minh at minh.le@fpt.edu.vn or SE160234 via 0987654321 for details.';
      final clean = AiTopicAdvisorService.sanitizePii(raw);

      expect(clean.contains('minh.le@fpt.edu.vn'), isFalse);
      expect(clean.contains('SE160234'), isFalse);
      expect(clean.contains('0987654321'), isFalse);
      expect(clean, contains('[REDACTED_EMAIL]'));
      expect(clean, contains('[STUDENT_ID]'));
      expect(clean, contains('[PHONE]'));
    });
  });

  group('AiTopicAdvisorService - Graceful Fallback & Remote Config', () {
    test('throws when AI feature is disabled in Remote Config', () async {
      final advisor = AiTopicAdvisorService(
        remoteConfig: _FakeConfigService(enabled: false),
        analytics: DebugAnalyticsService(),
      );

      expect(
        () => advisor.adviseTopic(
          rawTitle: 'My Project',
          rawDescription: 'Testing AI',
          category: 'AI/ML',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('generates deterministic structured fallback proposal when no API key provided', () async {
      final advisor = AiTopicAdvisorService(
        remoteConfig: _FakeConfigService(enabled: true),
        analytics: DebugAnalyticsService(),
        apiKey: '',
      );

      final proposal = await advisor.adviseTopic(
        rawTitle: 'Smart Agriculture Drone',
        rawDescription: 'Automated pesticide spraying with IoT sensors',
        category: 'AI/ML',
      );

      expect(proposal.refinedTitle, 'Smart Agriculture Drone');
      expect(proposal.description, contains('Automated pesticide spraying with IoT sensors'));
      expect(proposal.description.contains('Refined scope:'), isFalse);
      expect(proposal.suggestedTags, contains('AI/ML'));
      expect(proposal.suggestedRoles, isNotEmpty);
    });

    test('never prepends "Refined scope:" when invoked repeatedly', () async {
      final advisor = AiTopicAdvisorService(
        remoteConfig: _FakeConfigService(enabled: true),
        analytics: DebugAnalyticsService(),
        apiKey: '',
      );

      // 1st invocation
      final first = await advisor.adviseTopic(
        rawTitle: 'NextGen Web/Cloud Platform',
        rawDescription: 'A modern cloud-enabled Web/Cloud capstone project',
        category: 'Web/Cloud',
      );
      expect(first.description.contains('Refined scope:'), isFalse);

      // 2nd invocation feeding back the first result (re-tapping suggest)
      final second = await advisor.adviseTopic(
        rawTitle: first.refinedTitle,
        rawDescription: first.description,
        category: 'Web/Cloud',
      );
      expect(second.description.contains('Refined scope:'), isFalse);

      // 3rd invocation even if input contained "Refined scope:"
      final third = await advisor.adviseTopic(
        rawTitle: 'Test',
        rawDescription: 'Refined scope: Refined scope: Some project description',
        category: 'Web/Cloud',
      );
      expect(third.description.contains('Refined scope:'), isFalse);
    });
  });
}

