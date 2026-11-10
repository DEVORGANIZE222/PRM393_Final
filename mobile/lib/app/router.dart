import 'package:flutter/material.dart';
import 'package:core/core.dart' show TeamSubmissionService;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/student.dart';
import '../screens/browse/browse_screen.dart';
import '../screens/create_team/create_team_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/lock_review/lock_review_screen.dart';
import '../screens/mentor/mentor_detail_screen.dart';
import '../screens/mentor/mentor_list_screen.dart';
import '../screens/mentor/mentor_portal_screen.dart';
import '../screens/mentor/mentor_team_screen.dart';
import '../screens/my_team/my_team_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/pool/random_pool_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/sign_in/sign_in_screen.dart';
import '../screens/team_detail/team_detail_screen.dart';
import '../screens/voting/leader_voting_screen.dart';
import '../services/services.dart';
import '../viewmodels/browse_viewmodel.dart';
import '../viewmodels/create_team_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/lock_review_viewmodel.dart';
import '../viewmodels/mentor_detail_viewmodel.dart';
import '../viewmodels/mentor_list_viewmodel.dart';
import '../viewmodels/mentor_portal_viewmodel.dart';
import '../viewmodels/mentor_team_viewmodel.dart';
import '../viewmodels/my_team_viewmodel.dart';
import '../viewmodels/pool_status_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';
import '../viewmodels/sign_in_viewmodel.dart';
import '../viewmodels/team_detail_viewmodel.dart';
import '../viewmodels/voting_viewmodel.dart';
import '../widgets/app_navigation_shell.dart';
import '../widgets/states.dart';
import 'providers.dart';

/// Routes follow the Lab 2 IA: 4 top-level tabs inside the shell; nested
/// screens (Team Detail, Voting, Lock Review, Random Pool, Profile) open on the
/// root navigator, so they hide the bottom bar and show Back.
GoRouter buildRouter(SessionViewModel session) {
  Student me(BuildContext context) => context.read<SessionViewModel>().student!;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: session,
    redirect: (context, state) {
      final at = state.matchedLocation;
      // Every shell screen reads the signed-in student, so nothing builds
      // until the first auth event (a restored session arrives async).
      if (!session.ready) return at == '/splash' ? null : '/splash';
      if (!session.isSignedIn) return at == '/sign-in' ? null : '/sign-in';
      // Lecturers only have the portal; students never see it.
      final home = session.isMentor ? '/mentor-portal' : '/home';
      if (at == '/sign-in' || at == '/splash') return home;
      if (session.isMentor && at != '/alerts' && !at.startsWith('/mentor-portal')) return home;
      if (!session.isMentor && at.startsWith('/mentor-portal')) return home;
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, _) => const Scaffold(body: LoadingState(message: 'Signing you in…')),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, _) => ChangeNotifierProvider(
          create: (c) => SignInViewModel(c.read<AuthService>(), c.read<AnalyticsService>()),
          child: const SignInScreen(),
        ),
      ),
      GoRoute(
        path: '/alerts',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/mentor-portal',
        builder: (context, _) => ChangeNotifierProvider(
          create: (c) => MentorPortalViewModel(
            me(c),
            c.read<MentorRepository>(),
            c.read<AnalyticsService>(),
            c.read<CrashReporter>(),
            registration: c.read<RegistrationService>(),
            config: c.read<ConfigService>(),
          )..load(),
          child: const MentorPortalScreen(),
        ),
        routes: [
          GoRoute(
            path: 'team/:teamId',
            builder: (context, state) => ChangeNotifierProvider(
              create: (c) => MentorTeamViewModel(
                state.pathParameters['teamId']!,
                me(c),
                c.read<TeamRepository>(),
                c.read<CrashReporter>(),
              )..load(),
              child: const MentorTeamScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/mentors',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, _) => ChangeNotifierProvider(
          create: (c) => MentorListViewModel(
            c.read<MentorRepository>(),
            c.read<AnalyticsService>(),
            c.read<CrashReporter>(),
          )..load(),
          child: const MentorListScreen(),
        ),
        routes: [
          GoRoute(
            path: ':mentorId',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => ChangeNotifierProvider(
              create: (c) => MentorDetailViewModel(
                state.pathParameters['mentorId']!,
                me(c),
                c.read<MentorRepository>(),
                c.read<TeamRepository>(),
                c.read<AnalyticsService>(),
                c.read<CrashReporter>(),
              )..load(),
              child: const MentorDetailScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/create-team',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, _) => ChangeNotifierProvider(
          create: (c) =>
              CreateTeamViewModel(me(c), c.read<TeamRepository>(), c.read<AnalyticsService>(), c.read<CrashReporter>()),
          child: const CreateTeamScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppNavigationShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, _) => ChangeNotifierProvider(
                  create: (c) => DashboardViewModel(
                    me(c),
                    c.read<TeamRepository>(),
                    c.read<RegistrationService>(),
                    c.read<ConfigService>(),
                    c.read<CrashReporter>(),
                  )..load(),
                  child: const DashboardScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'pool',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, _) => ChangeNotifierProvider(
                      create: (c) =>
                          PoolStatusViewModel(me(c), c.read<PoolRepository>(), c.read<CrashReporter>())..load(),
                      child: const RandomPoolScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browse',
                builder: (context, _) => ChangeNotifierProvider(
                  create: (c) => BrowseViewModel(
                    c.read<TeamRepository>(),
                    c.read<ConfigService>(),
                    c.read<AnalyticsService>(),
                    c.read<CrashReporter>(),
                  )..search(),
                  child: const BrowseScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'team/:teamId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ChangeNotifierProvider(
                      create: (c) => TeamDetailViewModel(
                        me(c),
                        c.read<TeamRepository>(),
                        c.read<AnalyticsService>(),
                        c.read<CrashReporter>(),
                        state.pathParameters['teamId']!,
                      )..load(),
                      child: const TeamDetailScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/team',
                builder: (context, _) => ChangeNotifierProvider(
                  create: (c) => MyTeamViewModel(
                    me(c),
                    c.read<TeamRepository>(),
                    c.read<MentorRepository>(),
                    c.read<CrashReporter>(),
                  )..load(),
                  child: const MyTeamScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'vote',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, _) => ChangeNotifierProvider(
                      create: (c) => VotingViewModel(
                        me(c),
                        c.read<TeamRepository>(),
                        c.read<AnalyticsService>(),
                        c.read<CrashReporter>(),
                      )..load(),
                      child: const LeaderVotingScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'lock',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, _) => ChangeNotifierProvider(
                      create: (c) => LockReviewViewModel(
                        me(c),
                        c.read<TeamRepository>(),
                        c.read<TeamSubmissionService>(),
                        c.read<AnalyticsService>(),
                        c.read<CrashReporter>(),
                      )..load(),
                      child: const LockReviewScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, _) => ChangeNotifierProvider(
                  create: (c) => ProfileViewModel(
                    me(c),
                    c.read<TeamRepository>(),
                    c.read<ReportService>(),
                    c.read<StorageService>(),
                    c.read<ConfigService>(),
                    c.read<CrashReporter>(),
                    c.read<AnalyticsService>(),
                  ),
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
