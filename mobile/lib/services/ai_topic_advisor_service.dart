import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'services.dart';

class AiTopicProposal {
  final String teamName;
  final String refinedTitle;
  final String description;
  final List<String> suggestedTags;
  final List<String> suggestedRoles;

  const AiTopicProposal({
    this.teamName = '',
    required this.refinedTitle,
    required this.description,
    required this.suggestedTags,
    required this.suggestedRoles,
  });

  factory AiTopicProposal.fromJson(Map<String, dynamic> json) {
    final title = json['refinedTitle'] as String? ?? '';
    final rawName = json['teamName'] as String? ?? '';
    final name = rawName.isNotEmpty
        ? rawName
        : (title.isNotEmpty ? title.split(' ').take(2).join('') : 'EcoSmart');
    return AiTopicProposal(
      teamName: name,
      refinedTitle: title,
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
        'teamName': teamName,
        'refinedTitle': refinedTitle,
        'description': description,
        'suggestedTags': suggestedTags,
        'suggestedRoles': suggestedRoles,
      };
}

class AiTopicAdvisorService {
  static const defaultApiKey = 'AQ.Ab8RN6ItdExVkCIHMs4o5xE_K0sOk05ro2VfRBo3a88lwDcYYA';

  static int _themeCounter = 0;
  static const _subThemes = [
    'Smart Healthcare, Patient Telemetry & Telemedicine',
    'Interactive E-Learning, Skill Development & Gamified Education',
    'E-Commerce, Live Bidding & Digital Marketplaces',
    'Green Energy, CleanTech & Carbon Tracking',
    'Logistics, Supply Chain & Fleet Telemetry',
    'Cybersecurity, Identity Verification & Zero-Trust Access',
    'Smart Urban Transit, Tourism & Navigation',
    'Smart Agriculture, Precision Farming & Food Quality',
    'Media Streaming, Collaborative Content Creation & Entertainment',
    'FinTech, Micro-Investment & Fraud Detection',
  ];

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
                : (remoteConfig.getString('gemini_api_key').isNotEmpty
                    ? remoteConfig.getString('gemini_api_key')
                    : defaultApiKey));

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

    var model = _remoteConfig.getString('ai_model_name');
    if (model.isEmpty || model == 'gemini-2.5-flash' || model == 'gemini-2.5-flash-lite') {
      model = 'gemini-flash-lite-latest';
    }
    await _analytics.logAiRequest(feature: 'topic_advisor', model: model);

    final cleanTitle = sanitizePii(rawTitle);
    final cleanDesc = sanitizePii(rawDescription);

    // If Gemini API key is configured, call Gemini API via native HttpClient
    try {
      if (_apiKey.isNotEmpty) {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
        );

        final theme = _subThemes[(_themeCounter++) % _subThemes.length];
        final seed = DateTime.now().millisecondsSinceEpoch % 100000;
        final prompt = '''
You are an expert capstone project mentor at FPT University.
Generate a COMPLETELY NEW, UNIQUE, and INNOVATIVE graduation project proposal for students in category "$category", focused on the domain sub-theme: "$theme".
Session Seed: $seed.

CRITICAL INSTRUCTIONS:
1. Do NOT reuse formulas, patterns, or repetitive phrases like "Decentralized Edge-Cloud Platform".
2. The topic MUST be completely distinct and specific to the "$theme" sub-theme.
3. "teamName": Short catchy brand/startup name (1-2 words, e.g. "PulseCare", "SkillForge", "GreenRoute", "BidWave", "AgriSense").
4. "refinedTitle": A fresh, professional project topic title in English (5-10 words).
5. "description": An inspiring 2-sentence description explaining the problem solved and core technologies in English.
6. "suggestedTags": 3 to 5 relevant technical tags (e.g. Flutter, Firebase, FastAPI, Docker, PyTorch).
7. "suggestedRoles": 3 to 4 team member roles needed.

Return ONLY valid JSON matching this schema:
{
  "teamName": "string",
  "refinedTitle": "string",
  "description": "string",
  "suggestedTags": ["tag1", "tag2", "tag3"],
  "suggestedRoles": ["role1", "role2", "role3"]
}
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
            'temperature': 0.85,
          }
        }));

        final response = await request.close().timeout(const Duration(seconds: 15));
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

    // Graceful Fallback (deterministic rotating structured catalog)
    return _generateFallback(cleanTitle, cleanDesc, category);
  }

  static int _fallbackCounter = 0;

  static List<AiTopicProposal> _defaultCatalog(String category) => [
        AiTopicProposal(
          teamName: 'NextGenLab',
          refinedTitle: 'Smart $category Collaborative Platform with Real-Time Sync',
          description:
              'A modern cloud-enabled capstone project built with Flutter and Firebase, featuring secure role-based access control and live telemetry.',
          suggestedTags: const ['Cloud', 'Mobile', 'Firebase', 'Flutter'],
          suggestedRoles: const ['Frontend Dev', 'Backend Dev', 'UI/UX Designer', 'QA Tester'],
        ),
        AiTopicProposal(
          teamName: 'SmartEnterprise',
          refinedTitle: 'Multi-Tenant Cloud Resource & Analytics Management Suite',
          description:
              'A scalable cloud solution with real-time audit logging, automated reporting pipelines, and cross-departmental coordination.',
          suggestedTags: const ['Web/Cloud', 'Microservices', 'PostgreSQL', 'Docker'],
          suggestedRoles: const ['Backend Dev', 'Fullstack Dev', 'DevOps Engineer', 'Security Dev'],
        ),
      ];

  static final Map<String, List<AiTopicProposal>> _domainCatalog = {
    'webcloud': [
      const AiTopicProposal(
        teamName: 'CapstoneHub',
        refinedTitle: 'Collaborative University Capstone & Mentor Allocation Hub',
        description:
            'A multi-tenant cloud platform optimizing student team formation, weekly milestone tracking, and automated accreditation reporting.',
        suggestedTags: ['Web/Cloud', 'Flutter Web', 'Firebase', 'Docker', 'PostgreSQL'],
        suggestedRoles: ['Frontend Dev', 'Backend Dev', 'DevOps Engineer', 'UI/UX Designer'],
      ),
      const AiTopicProposal(
        teamName: 'MicroTransit',
        refinedTitle: 'Smart Campus Electric Shuttle Dispatch & Route Optimization',
        description:
            'Processing real-time GPS telemetry from electric vehicles with graph routing algorithms to minimize passenger wait times across campuses.',
        suggestedTags: ['Web/Cloud', 'Microservices', 'FastAPI', 'Redis', 'Google Maps'],
        suggestedRoles: ['Backend Dev', 'Cloud Architect', 'Mobile Dev', 'QA Engineer'],
      ),
      const AiTopicProposal(
        teamName: 'EventPass',
        refinedTitle: 'Secure Scalable Event Management with Dynamic QR Check-in',
        description:
            'High-throughput distributed event ticketing engine preventing ticket scalping and fraudulent sharing through rolling dynamic QR tokens.',
        suggestedTags: ['Web/Cloud', 'Security', 'NodeJS', 'MongoDB', 'Flutter'],
        suggestedRoles: ['Fullstack Dev', 'Security Specialist', 'Mobile Dev', 'UI/UX Designer'],
      ),
      const AiTopicProposal(
        teamName: 'LogiChain',
        refinedTitle: 'Multi-Tenant Cloud Warehouse & End-to-End Logistics Tracking',
        description:
            'Cloud platform featuring real-time telemetry dashboards and order synchronization across regional transit hubs.',
        suggestedTags: ['Web/Cloud', 'Cloud Run', 'GCP', 'PostgreSQL', 'Flutter'],
        suggestedRoles: ['Backend Dev', 'Frontend Dev', 'Database Admin', 'DevOps'],
      ),
    ],
    'aiml': [
      const AiTopicProposal(
        teamName: 'AeroDeliver',
        refinedTitle: 'Autonomous Campus Micro-Drone Delivery System',
        description:
            'An autonomous micro-drone network delivering educational supplies and emergency kits across campus using real-time computer vision routing.',
        suggestedTags: ['AI/ML', 'Computer Vision', 'IoT', 'Flutter', 'ROS2'],
        suggestedRoles: ['AI/ML Engineer', 'Embedded Engineer', 'Backend Dev', 'Mobile Dev'],
      ),
      const AiTopicProposal(
        teamName: 'EduNova',
        refinedTitle: 'AI-Powered Adaptive Learning & Code Review Assistant',
        description:
            'Leveraging large language models to assess student knowledge gaps, generate customized exercises, and provide instant code feedback.',
        suggestedTags: ['AI/ML', 'Gemini API', 'FastAPI', 'Python', 'Flutter'],
        suggestedRoles: ['AI Engineer', 'Fullstack Dev', 'UI/UX Designer', 'QA Engineer'],
      ),
      const AiTopicProposal(
        teamName: 'HealthPulse',
        refinedTitle: 'Smart Healthcare Telemetry & Cardiac Anomaly Detection',
        description:
            'Collecting real-time ECG and vital telemetry from wearable sensors with deep learning models predicting cardiac irregularities.',
        suggestedTags: ['AI/ML', 'HealthTech', 'Deep Learning', 'Firebase', 'Flutter'],
        suggestedRoles: ['Data Scientist', 'Mobile Dev', 'Backend Dev', 'Medical Advisor'],
      ),
      const AiTopicProposal(
        teamName: 'AgriVision',
        refinedTitle: 'Edge AI Crop Disease Detection & Automated Irrigation',
        description:
            'Deploying computer vision models to identify crop diseases in real time and trigger precision pesticide micro-spraying to reduce chemical waste.',
        suggestedTags: ['AI/ML', 'Edge AI', 'IoT', 'Python', 'Mobile'],
        suggestedRoles: ['Computer Vision Dev', 'IoT Engineer', 'Backend Dev', 'Mobile Dev'],
      ),
      const AiTopicProposal(
        teamName: 'SignBridge',
        refinedTitle: 'Real-Time Sign Language Interpretation for Accessibility',
        description:
            'Translating hand gestures and facial expressions into spoken audio and text bidirectionally with sub-200ms latency.',
        suggestedTags: ['AI/ML', 'MediaPipe', 'Flutter', 'TensorFlow Lite', 'Python'],
        suggestedRoles: ['AI Engineer', 'Flutter Mobile Dev', 'UI/UX Designer', 'Tester'],
      ),
    ],
    'mobile': [
      const AiTopicProposal(
        teamName: 'CampusGo',
        refinedTitle: 'Interactive Campus Navigation & Study Partner Matcher',
        description:
            'Indoor micro-navigation mobile app assisting freshmen in locating classrooms and discovering peer study groups nearby.',
        suggestedTags: ['Mobile', 'Flutter', 'Firebase', 'Google Maps', 'Figma'],
        suggestedRoles: ['Mobile Dev', 'UI/UX Designer', 'Backend Dev', 'Tester'],
      ),
      const AiTopicProposal(
        teamName: 'GreenHabit',
        refinedTitle: 'Gamified Eco-Friendly Habit Tracker & Recycling Rewards',
        description:
            'Rewarding students with redeemable points for recycling and utilizing green transit, featuring live community leaderboards.',
        suggestedTags: ['Mobile', 'Flutter', 'Gamification', 'Firebase', 'REST API'],
        suggestedRoles: ['Mobile Dev', 'Game Designer', 'Frontend Dev', 'Backend Dev'],
      ),
      const AiTopicProposal(
        teamName: 'StudyTogether',
        refinedTitle: 'Virtual Co-Working Space & Group Focus Management',
        description:
            'A cross-platform mobile app offering shared Pomodoro focus rooms, ambient soundscapes, and distraction-blocking capabilities.',
        suggestedTags: ['Mobile', 'Flutter', 'WebRTC', 'Firebase', 'Bloc'],
        suggestedRoles: ['Mobile Dev', 'Backend Dev', 'UI/UX Designer', 'QA/QC'],
      ),
    ],
    'fintech': [
      const AiTopicProposal(
        teamName: 'FinSmart',
        refinedTitle: 'Student Personal Finance & Smart Budget Allocation Assistant',
        description:
            'Scanning receipts using OCR and categorizing expenses into financial buckets with predictive month-end saving recommendations.',
        suggestedTags: ['FinTech', 'OCR', 'Flutter', 'Firebase', 'Python'],
        suggestedRoles: ['Mobile Dev', 'Backend Dev', 'Data Analyst', 'Security Dev'],
      ),
      const AiTopicProposal(
        teamName: 'SafePay',
        refinedTitle: 'Contactless Campus Wallet with Biometric & OTP Verification',
        description:
            'Low-latency digital payment ecosystem enabling secure cashless transactions at university cafeterias and libraries.',
        suggestedTags: ['FinTech', 'Security', 'Cryptography', 'PostgreSQL', 'Flutter'],
        suggestedRoles: ['Security Specialist', 'Backend Dev', 'Fullstack Dev', 'QA/Tester'],
      ),
    ],
    'iot': [
      const AiTopicProposal(
        teamName: 'EcoGrid',
        refinedTitle: 'Smart Campus Power Monitoring & Automated Classroom Shutdown',
        description:
            'An IoT sensing mesh detecting unoccupied classrooms to automatically power down air conditioning and lighting, saving up to 35% energy.',
        suggestedTags: ['IoT', 'Hardware', 'MQTT', 'ESP32', 'Flutter', 'Firebase'],
        suggestedRoles: ['IoT / Hardware', 'Firmware Dev', 'Mobile Dev', 'Backend Dev'],
      ),
      const AiTopicProposal(
        teamName: 'AgriSense',
        refinedTitle: 'High-Tech Automated Greenhouse Environmental Controller',
        description:
            'Regulating temperature, soil humidity, and drip irrigation via real-time telemetry with predictive pest alerts.',
        suggestedTags: ['IoT', 'MQTT', 'Flutter', 'Arduino', 'Cloud'],
        suggestedRoles: ['Embedded Engineer', 'Mobile Dev', 'Backend Dev', 'Tester'],
      ),
    ],
  };

  AiTopicProposal _generateFallback(String title, String desc, String category) {
    final catKey = category.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final catalog = _domainCatalog[catKey] ?? _defaultCatalog(category);

    // ALWAYS advance to the next distinct idea so every click yields a completely DIFFERENT topic!
    final index = (_fallbackCounter++) % catalog.length;
    return catalog[index];
  }
}
