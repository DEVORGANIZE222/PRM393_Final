import 'package:flutter_test/flutter_test.dart';
import 'package:exematching/services/ai_topic_advisor_service.dart';
import 'package:exematching/services/services.dart';
import 'package:exematching/services/local/local_services.dart';

class _FakeConfigService implements ConfigService {
  _FakeConfigService({
    this.enabled = true,
    this.geminiApiKey = '',
  });

  final bool enabled;
  final String geminiApiKey;
  int refreshCount = 0;
  final List<String> requestedStringKeys = [];

  @override
  bool getBool(String key) => key == 'enable_ai_feature' ? enabled : true;

  @override
  int getInt(String key) => 5;

  @override
  String getString(String key) {
    requestedStringKeys.add(key);
    if (key == 'ai_model_name') return 'gemini-2.5-flash';
    if (key == 'gemini_api_key') return geminiApiKey;
    return '';
  }

  @override
  Future<bool> refresh() async {
    refreshCount++;
    return false;
  }

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

      expect(proposal.refinedTitle.isNotEmpty, isTrue);
      expect(proposal.description.isNotEmpty, isTrue);
      expect(proposal.description.contains('Refined scope:'), isFalse);
      expect(proposal.suggestedTags, isNotEmpty);
      expect(proposal.suggestedRoles, isNotEmpty);
    });

    test('each repeated suggest tap returns a completely different topic', () async {
      final advisor = AiTopicAdvisorService(
        remoteConfig: _FakeConfigService(enabled: true),
        analytics: DebugAnalyticsService(),
        apiKey: '',
      );

      // 1st invocation
      final first = await advisor.adviseTopic(
        rawTitle: '',
        rawDescription: '',
        category: 'AI/ML',
      );

      // 2nd invocation feeding back the first result (re-tapping suggest)
      final second = await advisor.adviseTopic(
        rawTitle: first.refinedTitle,
        rawDescription: first.description,
        category: 'AI/ML',
      );

      // 3rd invocation
      final third = await advisor.adviseTopic(
        rawTitle: second.refinedTitle,
        rawDescription: second.description,
        category: 'AI/ML',
      );

      // Every invocation must yield a distinct, brand-new topic
      expect(first.refinedTitle != second.refinedTitle, isTrue);
      expect(second.refinedTitle != third.refinedTitle, isTrue);
      expect(first.refinedTitle != third.refinedTitle, isTrue);
      expect(first.description.contains('Refined scope:'), isFalse);
      expect(second.description.contains('Refined scope:'), isFalse);
      expect(third.description.contains('Refined scope:'), isFalse);
    });

    test('fetches gemini_api_key exclusively from Remote Config when no override passed', () async {
      final config = _FakeConfigService(enabled: true, geminiApiKey: '');
      final advisor = AiTopicAdvisorService(
        remoteConfig: config,
        analytics: DebugAnalyticsService(),
      );

      final proposal = await advisor.adviseTopic(
        rawTitle: 'Campus Food Rescue',
        rawDescription: 'Connect surplus canteen meals with students',
        category: 'Web/Cloud',
      );

      expect(config.requestedStringKeys, contains('gemini_api_key'));
      expect(config.refreshCount, 1);
      expect(proposal.refinedTitle.isNotEmpty, isTrue);
    });
  });
}

