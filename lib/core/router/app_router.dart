import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/navigation/presentation/main_scaffold.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/errands/presentation/errands_screen.dart';
import '../../features/decision_lab/presentation/decision_lab_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/itinerary/presentation/itinerary_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const DiscoverScreen(),
        ),
        GoRoute(
          path: '/errands',
          builder: (context, state) => const ErrandsScreen(),
        ),
        GoRoute(
          path: '/decision-lab',
          builder: (context, state) => const DecisionLabScreen(),
        ),
        GoRoute(
          path: '/community',
          builder: (context, state) => const CommunityScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/itinerary',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ItineraryScreen(),
    ),
    GoRoute(
      path: '/profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);
