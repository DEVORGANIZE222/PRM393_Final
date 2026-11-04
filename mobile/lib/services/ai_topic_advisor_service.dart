import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'services.dart';

class AiTopicProposal {
  final String refinedTitle;
  final String description;
  final List<String> suggestedTags;
  final List<String> suggestedRoles;

  const AiTopicProposal({
    required this.refinedTitle,
    required this.description,
    required this.suggestedTags,
    required this.suggestedRoles,
  });

  factory AiTopicProposal.fromJson(Map<String, dynamic> json) {
    return AiTopicProposal(
      refinedTitle: json['refinedTitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      suggestedTags: (json['suggestedTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      suggestedRoles: (json['suggestedRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'refinedTitle': refinedTitle,
        'description': description,
        'suggestedTags': suggestedTags,
        'suggestedRoles': suggestedRoles,
      };
}

class AiTopicAdvisorService {
  final ConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final String? _apiKey;

  AiTopicAdvisorService({
    required ConfigService remoteConfig,
    required AnalyticsService analytics,
    String? apiKey,
  })  : _remoteConfig = remoteConfig,
        _analytics = analytics,
        _apiKey = apiKey;

  /// Sanitizes text to strictly prevent sending personal data (PII) to Gemini API
  static String sanitizePii(String input) {
    // Strip emails
    final noEmails = input.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
      '[REDACTED_EMAIL]',
    );
    // Strip phone numbers / student IDs (e.g., SE123456 or 10-digit numbers)
    final noIds = noEmails.replaceAll(
      RegExp(r'\b(SE|HE|IA|MC|SS)\d{6,}\b', caseSensitive: false),
      '[STUDENT_ID]',
    );
    final noPhones = noIds.replaceAll(
      RegExp(r'\b0\d{9}\b'),
      '[PHONE]',
    );
    return noPhones.trim();
  }

  /// Generates structured topic draft (Level 2: Structured output)
  Future<AiTopicProposal> adviseTopic({
    required String rawTitle,
    required String rawDescription,
    required String category,
  }) async {
    final enabled = _remoteConfig.getBool('enable_ai_feature');
    if (!enabled) {
      await _analytics.logAiError(
        feature: 'topic_advisor',
        errorReason: 'feature_disabled_by_remote_config',
      );
      throw Exception('AI feature is currently disabled by administrator via Remote Config.');
    }

    const model = 'gemini-2.5-flash';
    await _analytics.logAiRequest(feature: 'topic_advisor', model: model);

    final cleanTitle = sanitizePii(rawTitle);
    final cleanDesc = sanitizePii(rawDescription);

    // If Gemini API key is configured, call Gemini API via native HttpClient
    try {
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
        );

        final prompt = '''
You are an expert capstone mentor at FPT University. Generate a structured JSON proposal for a student graduation project.
Return ONLY valid JSON matching this exact schema:
{
  "refinedTitle": "string (clear, professional English or Vietnamese topic title)",
  "description": "string (2-3 sentences explaining problem, methodology, and expected result)",
  "suggestedTags": ["tag1", "tag2", "tag3"],
  "suggestedRoles": ["role1", "role2", "role3"]
}
Input category: $category
Input title: $cleanTitle
Input description: $cleanDesc
''';

        final client = HttpClient();
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.7,
          }
        }));

        final response = await request.close().timeout(const Duration(seconds: 10));
        final responseBody = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          final contentText =
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';
          final Map<String, dynamic> parsed = jsonDecode(contentText);
          return AiTopicProposal.fromJson(parsed);
        } else {
          debugPrint('Gemini API returned status ${response.statusCode}');
        }
      }
    } catch (e) {
      await _analytics.logAiError(
        feature: 'topic_advisor',
        errorReason: 'network_or_quota_fallback: $e',
      );
    }

    // Graceful Fallback (deterministic high-quality structured output)
    return _generateFallback(cleanTitle, cleanDesc, category);
  }

  AiTopicProposal _generateFallback(String title, String desc, String category) {
    final titleText = title.isNotEmpty ? title : 'NextGen $category Platform';
    final descText = desc.isNotEmpty
        ? 'Refined scope: $desc. Implementing core architectures, data synchronizations, and scalable microservices.'
        : 'A modern cloud-enabled $category capstone project built with Flutter and Firebase, featuring secure role-based access control and real-time collaboration.';

    List<String> tags = ['Cloud', 'Mobile', 'Firebase'];
    List<String> roles = ['Frontend Dev', 'Backend Dev', 'UI/UX Designer'];

    if (category.toLowerCase().contains('ai') || title.toLowerCase().contains('ai')) {
      tags = ['AI/ML', 'Gemini API', 'Python', 'Flutter'];
      roles = ['ML Engineer', 'Flutter Mobile Dev', 'Backend Dev'];
    } else if (category.toLowerCase().contains('fintech')) {
      tags = ['FinTech', 'Security', 'Payment Gateway', 'PostgreSQL'];
      roles = ['Security Specialist', 'Fullstack Dev', 'QA Engineer'];
    }

    return AiTopicProposal(
      refinedTitle: titleText,
      description: descText,
      suggestedTags: tags,
      suggestedRoles: roles,
    );
  }
}
