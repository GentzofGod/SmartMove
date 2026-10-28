import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSession {
  final String id;
  final String email;
  final String displayName;
  final bool isGuest;
  final String role; // 'Customer', 'Trader'

  const UserSession({
    required this.id,
    required this.email,
    required this.displayName,
    this.isGuest = false,
    this.role = 'Customer',
  });

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
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: json['id'] as String? ?? 'usr-unknown',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'User',
        isGuest: json['isGuest'] as bool? ?? false,
        role: json['role'] as String? ?? 'Customer',
      );

  UserSession copyWith({
    String? id,
    String? email,
    String? displayName,
    bool? isGuest,
    String? role,
  }) {
    return UserSession(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isGuest: isGuest ?? this.isGuest,
      role: role ?? this.role,
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
        final session = UserSession(
          id: user.id,
          email: user.email ?? 'user@smartmove.app',
          displayName: (user.userMetadata?['name'] as String?) ??
              user.email?.split('@').first ??
              'User',
          role: (user.userMetadata?['role'] as String?) ?? 'Customer',
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
          final session = UserSession(
            id: user.id,
            email: user.email ?? email,
            displayName: (user.userMetadata?['name'] as String?) ??
                user.email?.split('@').first ??
                'User',
            role: (user.userMetadata?['role'] as String?) ?? 'Customer',
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
    final session = UserSession(
      id: 'usr-${email.hashCode.abs()}',
      email: email.trim(),
      displayName: email.split('@').first,
      role: 'Customer',
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
  }) async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'name': displayName, 'role': role},
        );
        final user = response.user;
        if (user != null) {
          final session = UserSession(
            id: user.id,
            email: user.email ?? email,
            displayName: displayName,
            isGuest: false,
            role: role,
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
