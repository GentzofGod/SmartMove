import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/navigation/presentation/main_scaffold.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/decision_lab/presentation/decision_lab_screen.dart';
import '../../features/itinerary/presentation/itinerary_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/admin/presentation/superadmin_panel_screen.dart';
import '../../features/legal/presentation/legal_screen.dart';
import '../../features/seller/presentation/seller_portal_screen.dart';
import '../../features/messages/presentation/message_box_screen.dart';
import '../../features/messages/presentation/chat_thread_screen.dart';

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
          path: '/products',
          builder: (context, state) => const ProductsScreen(),
        ),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const ProductsScreen(),
        ),
        GoRoute(
          path: '/community',
          builder: (context, state) => const ProductsScreen(),
        ),
        GoRoute(
          path: '/errands',
          redirect: (context, state) => '/products',
        ),
        GoRoute(
          path: '/decision-lab',
          builder: (context, state) => const DecisionLabScreen(),
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
    GoRoute(
      path: '/messages',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final keyParam = state.uri.queryParameters['key'];
        return MessageBoxScreen(initialConversationKey: keyParam);
      },
    ),
    GoRoute(
      path: '/messages/thread',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final convKey = state.uri.queryParameters['key'] ?? '';
        final partner = state.uri.queryParameters['partner'];
        final commodity = state.uri.queryParameters['commodity'];
        final priceStr = state.uri.queryParameters['price'];
        final unit = state.uri.queryParameters['unit'];
        return ChatThreadScreen(
          conversationKey: convKey,
          initialPartnerName: partner,
          initialCommodityName: commodity,
          initialPrice: priceStr != null ? double.tryParse(priceStr) : null,
          initialUnit: unit,
        );
      },
    ),
    GoRoute(
      path: '/auth',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/superadmin',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SuperAdminPanelScreen(),
    ),
    GoRoute(
      path: '/seller-portal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SellerPortalScreen(),
    ),
    GoRoute(
      path: '/legal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final tabParam = state.uri.queryParameters['tab'];
        return LegalScreen(initialTab: tabParam);
      },
    ),
  ],
);
