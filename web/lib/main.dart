import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'screens/login_screen.dart';
import 'screens/admin_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web needs explicit options; these come from --dart-define (see README).
  // Without them the app still opens as a layout preview.
  const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  if (apiKey.isNotEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: String.fromEnvironment('FIREBASE_WEB_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_WEB_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_WEB_PROJECT_ID'),
        authDomain: String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN'),
      ),
    );
  }
  runApp(const WebAdminApp());
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminShellScreen(),
    ),
  ],
);

class WebAdminApp extends StatelessWidget {
  const WebAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PRM393 Web Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF107C41), // Lab 2 primary green
          primary: const Color(0xFF107C41),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      routerConfig: _router,
    );
  }
}

