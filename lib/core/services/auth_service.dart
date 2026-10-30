import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/seller_application.dart';

enum UserRole {
  customer,
  trader,
  admin,
  superAdmin;

  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.trader:
        return 'Trader';
      case UserRole.admin:
        return 'Admin';
      case UserRole.superAdmin:
        return 'SuperAdmin';
    }
  }

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.customer;
    switch (value.trim().toLowerCase()) {
      case 'trader':
      case 'seller':
        return UserRole.trader;
      case 'superadmin':
      case 'super_admin':
      case 'super-admin':
      case 'super administrator':
        return UserRole.superAdmin;
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }
}

class UserSession {
  final String id;
  final String email;
  final String displayName;
  final bool isGuest;
  final String role; // 'Customer', 'Trader', 'Admin', 'SuperAdmin'
  final String? businessName;
  final String? marketHub;
  final String? sellerChannel;
  final String? phone;
  final String? stallLocation;
  final SellerApplicationStatus sellerApplicationStatus;

  const UserSession({
    required this.id,
    required this.email,
    required this.displayName,
    this.isGuest = false,
    this.role = 'Customer',
    this.businessName,
    this.marketHub,
    this.sellerChannel,
    this.phone,
    this.stallLocation,
    this.sellerApplicationStatus = SellerApplicationStatus.none,
  });

  bool get isSeller => role == 'Trader' || role == 'Seller';
  bool get isSuperAdmin =>
      role == 'SuperAdmin' || role == 'super_admin' || role == 'superadmin';
  bool get isAdmin =>
      role == 'Admin' || role == 'Administrator' || isSuperAdmin;
  bool get isCustomer => !isSeller && !isAdmin;
  bool get canModerate => isAdmin || isSuperAdmin;
  bool get canSubmitVerifiedListing => isSeller || isAdmin;
  bool get isPendingSeller =>
      sellerApplicationStatus == SellerApplicationStatus.pending;
  bool get isApprovedSeller =>
      isSeller || sellerApplicationStatus == SellerApplicationStatus.approved;
  bool get isRejectedSeller =>
      sellerApplicationStatus == SellerApplicationStatus.rejected;
  bool get canApplyForSeller =>
      !isGuest &&
      isCustomer &&
      (sellerApplicationStatus == SellerApplicationStatus.none ||
          sellerApplicationStatus == SellerApplicationStatus.rejected);

  static const guest = UserSession(
    id: 'usr-guest-001',
    email: 'guest@smartmove',
    displayName: 'Guest',
    isGuest: true,
    role: 'Customer',
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'isGuest': isGuest,
        'role': role,
        'businessName': businessName,
        'marketHub': marketHub,
        'sellerChannel': sellerChannel,
        'phone': phone,
        'stallLocation': stallLocation,
        'sellerApplicationStatus': sellerApplicationStatus.name,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: json['id'] as String? ?? 'usr-unknown',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'User',
        isGuest: json['isGuest'] as bool? ?? false,
        role: json['role'] as String? ?? 'Customer',
        businessName: json['businessName'] as String?,
        marketHub: json['marketHub'] as String?,
        sellerChannel: json['sellerChannel'] as String?,
        phone: json['phone'] as String?,
        stallLocation: json['stallLocation'] as String?,
        sellerApplicationStatus: SellerApplicationStatus.values.firstWhere(
          (s) => s.name == json['sellerApplicationStatus'],
          orElse: () => json['role'] == 'Trader'
              ? SellerApplicationStatus.approved
              : SellerApplicationStatus.none,
        ),
      );

  UserSession copyWith({
    String? id,
    String? email,
    String? displayName,
    bool? isGuest,
    String? role,
    String? businessName,
    String? marketHub,
    String? sellerChannel,
    String? phone,
    String? stallLocation,
    SellerApplicationStatus? sellerApplicationStatus,
  }) {
    return UserSession(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isGuest: isGuest ?? this.isGuest,
      role: role ?? this.role,
      businessName: businessName ?? this.businessName,
      marketHub: marketHub ?? this.marketHub,
      sellerChannel: sellerChannel ?? this.sellerChannel,
      phone: phone ?? this.phone,
      stallLocation: stallLocation ?? this.stallLocation,
      sellerApplicationStatus:
          sellerApplicationStatus ?? this.sellerApplicationStatus,
    );
  }
}

class AuthService {
  static const String _sessionStorageKey = 'smartmove_user_session';
  static bool _isSupabaseInitialized = false;

  static void markSupabaseInitialized() {
    _isSupabaseInitialized = true;
  }

  static SupabaseClient? get _client {
    if (_isSupabaseInitialized) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Restore persisted user session on app launch and sync live role from Supabase
  static Future<UserSession> restorePersistedSession() async {
    UserSession? cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionStorageKey);
      if (sessionJson != null) {
        final decoded = jsonDecode(sessionJson) as Map<String, dynamic>;
        cached = UserSession.fromJson(decoded);
      }
    } catch (_) {}

    // Check if live Supabase has a logged in user and fetch fresh profile & role
    final client = _client;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        final liveSession = await fetchLiveSessionForUser(user);
        if (liveSession != null) {
          return liveSession;
        }
      }
    }

    if (cached != null) {
      return cached;
    }

    return UserSession.guest;
  }

  /// Live synchronization with public.profiles table and auth metadata
  static Future<UserSession?> fetchLiveSessionForUser(User user) async {
    final client = _client;
    if (client == null) return null;

    String? dbRole;
    String? displayName;
    String? businessName;
    String? marketHub;
    String? sellerChannel;
    String? phone;
    String? stallLocation;
    String? appStatus;

    // 1. Fetch live row from public.profiles table
    try {
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        dbRole = profile['role']?.toString();
        displayName = profile['display_name']?.toString();
        businessName = profile['business_name']?.toString();
        marketHub = profile['market_hub']?.toString();
        sellerChannel = profile['seller_channel']?.toString();
        phone = profile['phone']?.toString();
        stallLocation = profile['stall_location']?.toString();
        appStatus = profile['seller_application_status']?.toString();
      }
    } catch (_) {}

    // 2. Check auth.users app_metadata / user_metadata as fallback
    final appMeta = user.appMetadata;
    final userMeta = user.userMetadata ?? {};
    final rawRole = dbRole ??
        appMeta['role']?.toString() ??
        userMeta['role']?.toString() ??
        'Customer';

    final parsedRole = UserRole.fromString(rawRole);
    final canonicalRole = parsedRole.label; // 'Customer', 'Trader', 'Admin', 'SuperAdmin'

    final name = displayName ??
        (userMeta['name'] as String?) ??
        user.email?.split('@').first ??
        'User';

    final session = UserSession(
      id: user.id,
      email: user.email ?? 'user@smartmove.app',
      displayName: name,
      role: canonicalRole,
      businessName: businessName ?? (userMeta['business_name'] as String?),
      marketHub: marketHub ?? (userMeta['market_hub'] as String?),
      sellerChannel: sellerChannel ?? (userMeta['seller_channel'] as String?),
      phone: phone ?? (userMeta['phone'] as String?),
      stallLocation: stallLocation ?? (userMeta['stall_location'] as String?),
      sellerApplicationStatus: SellerApplicationStatus.values.firstWhere(
        (s) => s.name == (appStatus ?? userMeta['seller_application_status']),
        orElse: () => canonicalRole == 'Trader'
            ? SellerApplicationStatus.approved
            : SellerApplicationStatus.none,
      ),
      isGuest: false,
    );

    await persistSession(session);
    return session;
  }

  /// Sync the current logged-in user profile from Supabase profiles table
  static Future<UserSession?> syncCurrentUserProfile() async {
    final client = _client;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        return fetchLiveSessionForUser(user);
      }
    }
    return null;
  }

  /// Persist session to local disk
  static Future<void> persistSession(UserSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  /// Sign in with Email & Password
  static Future<UserSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final user = response.user;
        if (user != null) {
          final liveSession = await fetchLiveSessionForUser(user);
          if (liveSession != null) {
            return liveSession;
          }
          final meta = user.userMetadata ?? {};
          final role = (meta['role'] as String?) ?? 'Customer';
          final session = UserSession(
            id: user.id,
            email: user.email ?? email,
            displayName: (meta['name'] as String?) ??
                user.email?.split('@').first ??
                'User',
            role: role,
            businessName: meta['business_name'] as String?,
            marketHub: meta['market_hub'] as String?,
            sellerChannel: meta['seller_channel'] as String?,
            phone: meta['phone'] as String?,
            stallLocation: meta['stall_location'] as String?,
            sellerApplicationStatus: SellerApplicationStatus.values.firstWhere(
              (s) => s.name == meta['seller_application_status'],
              orElse: () => role == 'Trader'
                  ? SellerApplicationStatus.approved
                  : SellerApplicationStatus.none,
            ),
            isGuest: false,
          );
          await persistSession(session);
          return session;
        }
      } catch (e) {
        // If Supabase credentials fails, throw user-friendly error
        throw Exception(e.toString());
      }
    }

    // Offline / Demo fallback authentication
    final lower = email.toLowerCase();
    final role = lower.contains('superadmin')
        ? 'SuperAdmin'
        : lower.contains('admin')
            ? 'Admin'
            : (lower.contains('trader') || lower.contains('seller'))
                ? 'Trader'
                : 'Customer';
    final isTrader = role == 'Trader';
    final session = UserSession(
      id: 'usr-${email.hashCode.abs()}',
      email: email.trim(),
      displayName: email.split('@').first,
      role: role,
      businessName: isTrader ? '${email.split('@').first} Enterprise' : null,
      marketHub: isTrader ? 'Bodija Market' : null,
      sellerChannel: isTrader ? 'Local Market' : null,
      sellerApplicationStatus: isTrader
          ? SellerApplicationStatus.approved
          : SellerApplicationStatus.none,
      isGuest: false,
    );
    await persistSession(session);
    return session;
  }

  /// Sign up with Email & Password (all accounts initialize as Customer)
  static Future<UserSession> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String role = 'Customer',
  }) async {
    final client = _client;
    final metadata = {
      'name': displayName,
      'role': role,
      'seller_application_status': SellerApplicationStatus.none.name,
    };

    if (client != null) {
      try {
        final response = await client.auth.signUp(
          email: email.trim(),
          password: password,
          data: metadata,
        );
        final user = response.user;
        if (user != null) {
          final session = UserSession(
            id: user.id,
            email: user.email ?? email,
            displayName: displayName,
            isGuest: false,
            role: role,
            sellerApplicationStatus: SellerApplicationStatus.none,
          );
          await persistSession(session);
          return session;
        }
      } catch (e) {
        throw Exception(e.toString());
      }
    }

    final session = UserSession(
      id: 'usr-${email.hashCode.abs()}',
      email: email.trim(),
      displayName: displayName,
      isGuest: false,
      role: role,
      sellerApplicationStatus: SellerApplicationStatus.none,
    );
    await persistSession(session);
    return session;
  }

  /// Sign in as Guest (Instant exploration)
  static Future<UserSession> signInAsGuest() async {
    await persistSession(UserSession.guest);
    return UserSession.guest;
  }

  /// Sign out
  static Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionStorageKey);
    } catch (_) {}
  }
}
