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
  static const defaultApiKey = '';

  final ConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final String _apiKey;

  AiTopicAdvisorService({
    required ConfigService remoteConfig,
    required AnalyticsService analytics,
    String? apiKey,
  })  : _remoteConfig = remoteConfig,
        _analytics = analytics,
        _apiKey = apiKey ??
            (const String.fromEnvironment('GEMINI_API_KEY').isNotEmpty
                ? const String.fromEnvironment('GEMINI_API_KEY')
                : remoteConfig.getString('gemini_api_key'));

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
      RegExp(r'\b(?:\+84|0)\d{9,10}\b'),
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

    final model = _remoteConfig.getString('ai_model_name').isNotEmpty
        ? _remoteConfig.getString('ai_model_name')
        : 'gemini-2.5-flash';
    await _analytics.logAiRequest(feature: 'topic_advisor', model: model);

    final cleanTitle = sanitizePii(rawTitle);
    final cleanDesc = sanitizePii(rawDescription);

    // If Gemini API key is configured, call Gemini API via native HttpClient
    try {
      if (_apiKey.isNotEmpty) {
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
          var contentText =
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '{}';
          contentText = contentText.trim();
          if (contentText.startsWith('```json')) {
            contentText = contentText.substring(7);
          } else if (contentText.startsWith('```')) {
            contentText = contentText.substring(3);
          }
          if (contentText.endsWith('```')) {
            contentText = contentText.substring(0, contentText.length - 3);
          }
          final Map<String, dynamic> parsed = jsonDecode(contentText.trim());
          return AiTopicProposal.fromJson(parsed);
        } else {
          debugPrint('Gemini API returned status ${response.statusCode}: $responseBody');
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

  static int _fallbackCounter = 0;

  static List<AiTopicProposal> _defaultCatalog(String category) => [
        AiTopicProposal(
          refinedTitle: 'NextGen $category Platform',
          description:
              'A modern cloud-enabled $category capstone project built with Flutter and Firebase, featuring secure role-based access control and real-time collaboration.',
          suggestedTags: const ['Cloud', 'Mobile', 'Firebase', 'Flutter'],
          suggestedRoles: const ['Frontend Dev', 'Backend Dev', 'UI/UX Designer'],
        ),
        AiTopicProposal(
          refinedTitle: 'Smart Enterprise $category Management Suite',
          description:
              'A scalable multi-tenant $category solution with real-time audit trails, automated reporting, and role-based permissions.',
          suggestedTags: const ['Web/Cloud', 'Microservices', 'PostgreSQL', 'Docker'],
          suggestedRoles: const ['Backend Dev', 'Fullstack Dev', 'DevOps Engineer'],
        ),
      ];

  static final Map<String, List<AiTopicProposal>> _domainCatalog = {
    'webcloud': [
      const AiTopicProposal(
        refinedTitle: 'NextGen Web & Cloud Platform',
        description:
            'A modern cloud-enabled Web/Cloud capstone project built with Flutter and Firebase, featuring secure role-based access control and real-time collaboration.',
        suggestedTags: ['Cloud', 'Flutter', 'Firebase', 'Docker'],
        suggestedRoles: ['Frontend Dev', 'Backend Dev', 'UI/UX Designer'],
      ),
      const AiTopicProposal(
        refinedTitle: 'Smart Enterprise Resource & Cloud Suite',
        description:
            'A scalable multi-tenant cloud application offering real-time distributed telemetry, role-based auditing, and automated reporting pipelines.',
        suggestedTags: ['Web/Cloud', 'Microservices', 'PostgreSQL', 'NodeJS'],
        suggestedRoles: ['Backend Dev', 'Fullstack Dev', 'DevOps Engineer'],
      ),
      const AiTopicProposal(
        refinedTitle: 'Collaborative Student Capstone Portal',
        description:
            'An end-to-end digital collaboration hub connecting university students, mentors, and administrators with instant notifications and progress tracking.',
        suggestedTags: ['Web/Cloud', 'Firebase', 'Flutter', 'CI/CD'],
        suggestedRoles: ['Fullstack Dev', 'UI/UX Designer', 'QA/Tester'],
      ),
    ],
    'aiml': [
      const AiTopicProposal(
        refinedTitle: 'Autonomous Campus Micro-Drone Delivery System',
        description:
            'An autonomous micro-drone network designed to deliver educational supplies across university campuses with real-time waypoint routing and telemetry.',
        suggestedTags: ['AI/ML', 'Computer Vision', 'Python', 'Flutter', 'IoT'],
        suggestedRoles: ['AI/ML Engineer', 'Mobile Dev', 'Backend Dev'],
      ),
      const AiTopicProposal(
        refinedTitle: 'Intelligent Adaptive Learning & Exam Proctoring Platform',
        description:
            'An AI-driven educational platform providing personalized study paths, knowledge gap analysis, and real-time student engagement analytics.',
        suggestedTags: ['AI/ML', 'Gemini API', 'FastAPI', 'Python', 'Flutter'],
        suggestedRoles: ['AI/ML Engineer', 'Fullstack Dev', 'UI/UX Designer'],
      ),
    ],
    'mobile': [
      const AiTopicProposal(
        refinedTitle: 'CampusLife: Real-Time Student Community & Service Hub',
        description:
            'A cross-platform mobile application delivering instant campus announcements, student team formation, peer mentoring, and interactive event coordination.',
        suggestedTags: ['Mobile', 'Flutter', 'Firebase', 'Figma'],
        suggestedRoles: ['Mobile Dev', 'UI/UX Designer', 'Backend Dev'],
      ),
      const AiTopicProposal(
        refinedTitle: 'Smart Transit & Campus Navigation Assistant',
        description:
            'An interactive mobile routing system featuring indoor campus maps, bus schedule tracking, and proximity-based peer meetup notifications.',
        suggestedTags: ['Mobile', 'Flutter', 'Google Maps', 'Firebase'],
        suggestedRoles: ['Mobile Dev', 'Frontend Dev', 'QA/Tester'],
      ),
    ],
    'fintech': [
      const AiTopicProposal(
        refinedTitle: 'Decentralized Micro-Payment Platform for Student Services',
        description:
            'A secure, low-latency digital payment ecosystem enabling instant peer-to-peer settlements and automated merchant reconciliations for university campuses.',
        suggestedTags: ['FinTech', 'Security', 'Payment Gateway', 'PostgreSQL'],
        suggestedRoles: ['Security Specialist', 'Fullstack Dev', 'QA/Tester'],
      ),
    ],
    'iot': [
      const AiTopicProposal(
        refinedTitle: 'Smart Campus Environmental Telemetry & Energy Monitoring',
        description:
            'An IoT sensing network monitoring power usage, ambient temperature, and classroom air quality with predictive maintenance alerts.',
        suggestedTags: ['IoT', 'Hardware', 'MQTT', 'Flutter', 'Firebase'],
        suggestedRoles: ['IoT / Hardware', 'Backend Dev', 'Mobile Dev'],
      ),
    ],
  };

  AiTopicProposal _generateFallback(String title, String desc, String category) {
    // 1. Strip any previous "Refined scope:" or "Refined:" prefixes
    final strippedTitle = title
        .replaceAll(RegExp(r'^(Refined(\s+scope)?:\s*)+', caseSensitive: false), '')
        .trim();
    var strippedDesc = desc
        .replaceAll(RegExp(r'^(Refined(\s+scope)?:\s*)+', caseSensitive: false), '')
        .trim();

    // 2. Strip previous boilerplate suffixes if already present
    final suffixes = [
      'Implementing core architectures, data synchronizations, and scalable microservices.',
      'Implementing core architectures, real-time collaboration, and scalable cloud microservices.',
      'Implementing modern system architecture, secure role-based access control, and real-time cloud data synchronization.',
    ];
    for (final s in suffixes) {
      if (strippedDesc.endsWith(s)) {
        strippedDesc = strippedDesc.substring(0, strippedDesc.length - s.length).trim();
      }
    }
    while (strippedDesc.endsWith('.')) {
      strippedDesc = strippedDesc.substring(0, strippedDesc.length - 1).trim();
    }

    // 3. Select category ideas catalog
    final catKey = category.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final catalog = _domainCatalog[catKey] ?? _defaultCatalog(category);

    // If user clicked suggest without typing or is re-tapping on an existing generated proposal,
    // cycle to the next idea in the catalog
    final isCatalogIdea = catalog.any((e) => e.refinedTitle == strippedTitle);
    final isGeneratedText = strippedTitle.isEmpty || isCatalogIdea;

    if (isGeneratedText) {
      final index = (_fallbackCounter++) % catalog.length;
      return catalog[index];
    }

    // 4. If user provided their own custom keywords, build a polished proposal WITHOUT "Refined scope:"
    final titleText = strippedTitle.isNotEmpty ? strippedTitle : 'Smart $category Solution';
    final descText =
        '$strippedDesc. Implementing modern system architecture, secure role-based access control, and real-time cloud data synchronization.';

    List<String> tags = ['Cloud', 'Mobile', 'Firebase'];
    List<String> roles = ['Frontend Dev', 'Backend Dev', 'UI/UX Designer'];

    if (catKey.contains('ai')) {
      tags = ['AI/ML', 'Gemini API', 'Python', 'Flutter'];
      roles = ['AI/ML Engineer', 'Flutter Mobile Dev', 'Backend Dev'];
    } else if (catKey.contains('fintech')) {
      tags = ['FinTech', 'Security', 'Payment Gateway', 'PostgreSQL'];
      roles = ['Security Specialist', 'Fullstack Dev', 'QA/Tester'];
    } else if (catKey.contains('iot')) {
      tags = ['IoT', 'Hardware', 'MQTT', 'Flutter'];
      roles = ['IoT / Hardware', 'Backend Dev', 'Mobile Dev'];
    } else if (catKey.contains('mobile')) {
      tags = ['Mobile', 'Flutter', 'Firebase', 'Figma'];
      roles = ['Mobile Dev', 'UI/UX Designer', 'Backend Dev'];
    }

    return AiTopicProposal(
      refinedTitle: titleText,
      description: descText,
      suggestedTags: tags,
      suggestedRoles: roles,
    );
  }
}
