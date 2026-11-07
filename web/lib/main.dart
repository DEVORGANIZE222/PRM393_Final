import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/admin_shell_screen.dart';
import 'services/admin_auth_service.dart';
import 'theme/admin_theme.dart';
import 'viewmodels/admin_session_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  runApp(const WebAdminApp());
}

class WebAdminApp extends StatelessWidget {
  const WebAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminSessionViewModel(AdminAuthService()),
      child: const _AdminRouter(),
    );
  }
}

class _AdminRouter extends StatefulWidget {
  const _AdminRouter();

  @override
  State<_AdminRouter> createState() => _AdminRouterState();
}

class _AdminRouterState extends State<_AdminRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final session = context.read<AdminSessionViewModel>();
    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: session,
      redirect: (_, state) {
        if (!session.ready || !session.isAuthorized) {
          return state.matchedLocation == '/login' ? null : '/login';
        }
        return state.matchedLocation == '/login' ? '/admin' : null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/admin', builder: (_, _) => const AdminShellScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'PRM393 Web Admin',
    debugShowCheckedModeBanner: false,
    theme: buildAdminTheme(),
    routerConfig: _router,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }
}
