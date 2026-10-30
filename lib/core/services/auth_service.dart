import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  customer,
  trader,
  admin;

  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.trader:
        return 'Trader';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.customer;
    switch (value.trim().toLowerCase()) {
      case 'trader':
      case 'seller':
        return UserRole.trader;
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
  final String role; // 'Customer', 'Trader', 'Admin'
  final String? businessName;
  final String? marketHub;
  final String? sellerChannel;
  final String? phone;

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
  });

  bool get isSeller => role == 'Trader' || role == 'Seller';
  bool get isAdmin => role == 'Admin' || role == 'Administrator';
  bool get isCustomer => !isSeller && !isAdmin;
  bool get canModerate => isAdmin;
  bool get canSubmitVerifiedListing => isSeller || isAdmin;

  static const guest = UserSession(
    id: 'usr-guest-001',
    email: 'guest@smartmove.app',
    displayName: 'Gent (Guest)',
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

  /// Restore persisted user session on app launch
  static Future<UserSession> restorePersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionStorageKey);
      if (sessionJson != null) {
        final decoded = jsonDecode(sessionJson) as Map<String, dynamic>;
        return UserSession.fromJson(decoded);
      }
    } catch (_) {}

    // Check if live Supabase has a logged in user
    final client = _client;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        final meta = user.userMetadata ?? {};
        final session = UserSession(
          id: user.id,
          email: user.email ?? 'user@smartmove.app',
          displayName: (meta['name'] as String?) ??
              user.email?.split('@').first ??
              'User',
          role: (meta['role'] as String?) ?? 'Customer',
          businessName: meta['business_name'] as String?,
          marketHub: meta['market_hub'] as String?,
          sellerChannel: meta['seller_channel'] as String?,
          phone: meta['phone'] as String?,
          isGuest: false,
        );
        await persistSession(session);
        return session;
      }
    }

    return UserSession.guest;
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
          final meta = user.userMetadata ?? {};
          final session = UserSession(
            id: user.id,
            email: user.email ?? email,
            displayName: (meta['name'] as String?) ??
                user.email?.split('@').first ??
                'User',
            role: (meta['role'] as String?) ?? 'Customer',
            businessName: meta['business_name'] as String?,
            marketHub: meta['market_hub'] as String?,
            sellerChannel: meta['seller_channel'] as String?,
            phone: meta['phone'] as String?,
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
    final role = lower.contains('admin')
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
      isGuest: false,
    );
    await persistSession(session);
    return session;
  }

  /// Sign up with Email & Password
  static Future<UserSession> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String role = 'Customer',
    String? businessName,
    String? marketHub,
    String? sellerChannel,
    String? phone,
  }) async {
    final client = _client;
    final metadata = {
      'name': displayName,
      'role': role,
      if (businessName != null && businessName.isNotEmpty) 'business_name': businessName,
      if (marketHub != null && marketHub.isNotEmpty) 'market_hub': marketHub,
      if (sellerChannel != null && sellerChannel.isNotEmpty) 'seller_channel': sellerChannel,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
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
            businessName: businessName,
            marketHub: marketHub,
            sellerChannel: sellerChannel,
            phone: phone,
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
      businessName: businessName,
      marketHub: marketHub,
      sellerChannel: sellerChannel,
      phone: phone,
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
