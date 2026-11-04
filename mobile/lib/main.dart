import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'firebase/firebase_messaging_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/session_viewmodel.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final uid = message.data['recipientId'] as String?;
  if (uid == null) return;
  await FirebaseFirestore.instance
      .collection('students')
      .doc(uid)
      .collection('notifications')
      .doc(message.messageId)
      .set({
        'kind': message.data['kind'] ?? 'system',
        'title': message.notification?.title ?? message.data['title'] ?? 'Notification',
        'body': message.notification?.body ?? message.data['body'] ?? '',
        'teamId': message.data['teamId'],
        'actionLabel': message.data['actionLabel'],
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  // Keep the semantics tree on even without TalkBack, so UI Automator and
  // ARTEMIS always see the Semantics identifiers (Android resource-id). Not in
  // release builds unless built for E2E with --dart-define=E2E_SEMANTICS=true (CR-09).
  if (kDebugMode || kProfileMode || const bool.fromEnvironment('E2E_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }
  final services = await AppServices.create();
  runApp(MultiProvider(providers: services.providers, child: const App()));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router = buildRouter(context.read<SessionViewModel>());
  StreamSubscription<String>? _openedTeamSubscription;
  StreamSubscription<void>? _permissionDeniedSubscription;

  @override
  void initState() {
    super.initState();
    _openedTeamSubscription = context.read<FirebaseMessagingService>().openedTeamIds.listen((teamId) {
      _router.go('/browse/team/$teamId');
    });
    _permissionDeniedSubscription = context.read<FirebaseMessagingService>().notificationPermissionDenied.listen((_) {
      appScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Notifications are off. You can still use the app, but new team updates will not appear as alerts.'),
        ),
      );
    });
  }

  @override
  void dispose() {
    _openedTeamSubscription?.cancel();
    _permissionDeniedSubscription?.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EXEMatching',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: buildAppTheme(),
      routerConfig: _router,
      // Android's KEYCODE_PASTE (a keyboard Paste key, and how ARTEMIS types
      // text) has no default text-editing shortcut in Flutter, only Ctrl+V.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.paste): const PasteTextIntent(SelectionChangedCause.keyboard),
      },
    );
  }
}
