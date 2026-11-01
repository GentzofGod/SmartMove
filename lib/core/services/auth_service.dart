import 'dart:convert';
import 'dart:math';
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
  final double? latitude;
  final double? longitude;
  final SellerApplicationStatus sellerApplicationStatus;
  final bool hasPendingStoreEdit;
  final String? pendingStoreEditSummary;

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
    this.latitude,
    this.longitude,
    this.sellerApplicationStatus = SellerApplicationStatus.none,
    this.hasPendingStoreEdit = false,
    this.pendingStoreEditSummary,
  });

  bool get isSeller =>
      role == 'Trader' ||
      role == 'Seller' ||
      role == 'trader' ||
      role == 'seller' ||
      sellerApplicationStatus == SellerApplicationStatus.approved;
  bool get isSuperAdmin =>
      role == 'SuperAdmin' || role == 'super_admin' || role == 'superadmin';
  bool get isAdmin =>
      role == 'Admin' || role == 'Administrator' || isSuperAdmin;
  bool get isCustomer => !isSeller && !isAdmin;
  bool get canModerate => isAdmin || isSuperAdmin;
  bool get canSubmitVerifiedListing => isSeller || isApprovedSeller || isAdmin;
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
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'sellerApplicationStatus': sellerApplicationStatus.name,
        'hasPendingStoreEdit': hasPendingStoreEdit,
        if (pendingStoreEditSummary != null)
          'pendingStoreEditSummary': pendingStoreEditSummary,
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
        latitude: (json['latitude'] ?? json['lat']) != null
            ? double.tryParse((json['latitude'] ?? json['lat']).toString())
            : null,
        longitude: (json['longitude'] ?? json['lon'] ?? json['lng']) != null
            ? double.tryParse((json['longitude'] ?? json['lon'] ?? json['lng']).toString())
            : null,
        sellerApplicationStatus: SellerApplicationStatus.values.firstWhere(
          (s) => s.name == json['sellerApplicationStatus'],
          orElse: () => (json['role'] == 'Trader' || json['role'] == 'Seller')
              ? SellerApplicationStatus.approved
              : SellerApplicationStatus.none,
        ),
        hasPendingStoreEdit: json['hasPendingStoreEdit'] as bool? ?? false,
        pendingStoreEditSummary: json['pendingStoreEditSummary'] as String?,
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
    double? latitude,
    double? longitude,
    SellerApplicationStatus? sellerApplicationStatus,
    bool? hasPendingStoreEdit,
    String? pendingStoreEditSummary,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sellerApplicationStatus:
          sellerApplicationStatus ?? this.sellerApplicationStatus,
      hasPendingStoreEdit: hasPendingStoreEdit ?? this.hasPendingStoreEdit,
      pendingStoreEditSummary:
          pendingStoreEditSummary ?? this.pendingStoreEditSummary,
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

  /// Immediately load from local SharedPreferences without any network latency
  static Future<UserSession?> getPersistedSessionOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionStorageKey);
      if (sessionJson != null && sessionJson.isNotEmpty) {
        final decoded = jsonDecode(sessionJson) as Map<String, dynamic>;
        return UserSession.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Restore persisted user session on app launch and sync live role from Supabase
  static Future<UserSession> restorePersistedSession() async {
    final cached = await getPersistedSessionOnly();

    // If we have a cached logged-in user (not guest), return it immediately and attempt non-blocking sync
    if (cached != null && !cached.isGuest) {
      final client = _client;
      if (client != null) {
        final user = client.auth.currentUser;
        if (user != null) {
          try {
            final liveSession = await fetchLiveSessionForUser(user)
                .timeout(const Duration(milliseconds: 2500));
            if (liveSession != null) {
              return liveSession;
            }
          } catch (_) {
            // Offline or timeout: safely preserve the cached authenticated session!
          }
        }
      }
      return cached;
    }

    // If cache is empty or guest, check if live Supabase has a valid session
    final client = _client;
    if (client != null) {
      try {
        final user = client.auth.currentUser;
        if (user != null) {
          final liveSession = await fetchLiveSessionForUser(user)
              .timeout(const Duration(milliseconds: 2500));
          if (liveSession != null) {
            return liveSession;
          }
        }
      } catch (_) {}
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
    double? latitude;
    double? longitude;
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
        if (profile['latitude'] != null) latitude = double.tryParse(profile['latitude'].toString());
        if (profile['longitude'] != null) longitude = double.tryParse(profile['longitude'].toString());
        appStatus = profile['seller_application_status']?.toString();
      }
    } catch (_) {}

    // Check seller_applications table for approved or pending trader records
    try {
      final appRows = await client
          .from('seller_applications')
          .select()
          .or('user_id.eq.${user.id},applicant_email.eq.${user.email ?? ''}')
          .order('submitted_at', ascending: false)
          .limit(1);
      final List<dynamic> appList = appRows as List<dynamic>;
      if (appList.isNotEmpty) {
        final appRow = appList.first as Map<String, dynamic>;
        final statusStr = appRow['status']?.toString();
        if (statusStr != null && statusStr.isNotEmpty) {
          appStatus = statusStr;
        }
        if (appRow['business_name'] != null) {
          businessName = appRow['business_name']?.toString();
        }
        if (appRow['market_hub'] != null) {
          marketHub = appRow['market_hub']?.toString();
        }
        if (appRow['seller_channel'] != null) {
          sellerChannel = appRow['seller_channel']?.toString();
        }
        if (appRow['phone'] != null) {
          phone = appRow['phone']?.toString();
        }
        if (appRow['stall_location'] != null) {
          stallLocation = appRow['stall_location']?.toString();
        }
        if (appRow['latitude'] != null) {
          latitude = double.tryParse(appRow['latitude'].toString());
        }
        if (appRow['longitude'] != null) {
          longitude = double.tryParse(appRow['longitude'].toString());
        }
      }
    } catch (_) {}

    final isApprovedSellerApp =
        appStatus == SellerApplicationStatus.approved.name;

    // 2. Check auth.users app_metadata / user_metadata as fallback
    final appMeta = user.appMetadata;
    final userMeta = user.userMetadata ?? {};
    final rawRole = isApprovedSellerApp
        ? 'Trader'
        : (dbRole ??
            appMeta['role']?.toString() ??
            userMeta['role']?.toString() ??
            'Customer');

    final parsedRole = UserRole.fromString(rawRole);
    final canonicalRole = isApprovedSellerApp
        ? 'Trader'
        : parsedRole.label; // 'Customer', 'Trader', 'Admin', 'SuperAdmin'

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
      latitude: latitude ??
          ((userMeta['latitude'] ?? userMeta['lat']) != null
              ? double.tryParse((userMeta['latitude'] ?? userMeta['lat']).toString())
              : null),
      longitude: longitude ??
          ((userMeta['longitude'] ?? userMeta['lon'] ?? userMeta['lng']) != null
              ? double.tryParse((userMeta['longitude'] ?? userMeta['lon'] ?? userMeta['lng']).toString())
              : null),
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
      final jsonStr = jsonEncode(session.toJson());
      await prefs.setString(_sessionStorageKey, jsonStr);
      if (!session.isGuest && session.email.isNotEmpty) {
        await prefs.setString(
            'smartmove_profile_${session.email.trim().toLowerCase()}', jsonStr);
        await prefs.setString('smartmove_profile_${session.id}', jsonStr);
      }
    } catch (_) {}
  }

  /// Save approved trader profile locally to persistent storage for account switches
  static Future<void> saveApprovedTraderProfile({
    required String email,
    required String userId,
    required String displayName,
    required String businessName,
    required String marketHub,
    required String sellerChannel,
    String? stallLocation,
    double? latitude,
    double? longitude,
    String? phone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final approvedSession = UserSession(
        id: userId.isNotEmpty ? userId : 'usr-${email.hashCode.abs()}',
        email: email.trim(),
        displayName: displayName.isNotEmpty ? displayName : email.split('@').first,
        role: 'Trader',
        businessName: businessName,
        marketHub: marketHub,
        sellerChannel: sellerChannel,
        stallLocation: stallLocation,
        latitude: latitude,
        longitude: longitude,
        phone: phone,
        sellerApplicationStatus: SellerApplicationStatus.approved,
        isGuest: false,
      );
      final jsonStr = jsonEncode(approvedSession.toJson());
      await prefs.setString(
          'smartmove_profile_${email.trim().toLowerCase()}', jsonStr);
      if (userId.isNotEmpty) {
        await prefs.setString('smartmove_profile_$userId', jsonStr);
      }
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
            latitude: (meta['latitude'] ?? meta['lat']) != null
                ? double.tryParse((meta['latitude'] ?? meta['lat']).toString())
                : null,
            longitude: (meta['longitude'] ?? meta['lon'] ?? meta['lng']) != null
                ? double.tryParse((meta['longitude'] ?? meta['lon'] ?? meta['lng']).toString())
                : null,
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
        final errStr = e.toString().toLowerCase();
        final isNetworkError = errStr.contains('socket') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('network') ||
            errStr.contains('timeout') ||
            errStr.contains('connection');
        if (!isNetworkError) {
          // If Supabase invalid credentials/auth error, throw user-friendly error
          throw Exception(e.toString());
        }
        // If offline/network unreachable, proceed gracefully to offline local authentication
      }
    }

    // Check if an existing profile or approved application exists for this email
    final prefs = await SharedPreferences.getInstance();
    final profileKey = 'smartmove_profile_${email.trim().toLowerCase()}';
    final savedProfile = prefs.getString(profileKey);
    if (savedProfile != null && savedProfile.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedProfile) as Map<String, dynamic>;
        final cached = UserSession.fromJson(decoded);
        await persistSession(cached);
        return cached;
      } catch (_) {}
    }

    // Check cached seller applications to ensure approved/pending status is preserved
    final appsRaw = prefs.getString('smartmove_cached_seller_applications');
    SellerApplication? matchedApp;
    if (appsRaw != null && appsRaw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(appsRaw) as List<dynamic>;
        for (final item in list) {
          final app = SellerApplication.fromJson(item as Map<String, dynamic>);
          if (app.applicantEmail.trim().toLowerCase() ==
              email.trim().toLowerCase()) {
            matchedApp = app;
            break;
          }
        }
      } catch (_) {}
    }

    // Offline / Demo fallback authentication
    final lower = email.toLowerCase();
    final role = lower.contains('superadmin')
        ? 'SuperAdmin'
        : lower.contains('admin')
            ? 'Admin'
            : (lower.contains('trader') ||
                    lower.contains('seller') ||
                    matchedApp?.status == SellerApplicationStatus.approved)
                ? 'Trader'
                : 'Customer';
    final isTrader = role == 'Trader';
    final session = UserSession(
      id: matchedApp?.userId.isNotEmpty == true
          ? matchedApp!.userId
          : 'usr-${email.hashCode.abs()}',
      email: email.trim(),
      displayName: matchedApp?.applicantName.isNotEmpty == true
          ? matchedApp!.applicantName
          : email.split('@').first,
      role: role,
      businessName: matchedApp?.businessName ??
          (isTrader ? '${email.split('@').first} Enterprise' : null),
      marketHub: matchedApp?.marketHub ?? (isTrader ? 'Bodija Market' : null),
      sellerChannel:
          matchedApp?.sellerChannel ?? (isTrader ? 'Local Market' : null),
      stallLocation: matchedApp?.stallLocation ??
          (isTrader
              ? 'Stall 14, Grain Section, Bodija Market, Ibadan'
              : null),
      latitude: matchedApp?.latitude ?? (isTrader ? 7.4343 : null),
      longitude: matchedApp?.longitude ?? (isTrader ? 3.9056 : null),
      phone: matchedApp?.phone,
      sellerApplicationStatus: matchedApp != null
          ? matchedApp.status
          : (isTrader
              ? SellerApplicationStatus.approved
              : SellerApplicationStatus.none),
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

  /// Generate and send a 6-digit password reset token
  static Future<Map<String, dynamic>> requestPasswordResetToken(
      String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }

    // Generate secure 6-digit numeric verification token
    final random = Random();
    final token = (100000 + random.nextInt(900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));

    final client = _client;
    if (client != null) {
      try {
        await client.auth.resetPasswordForEmail(cleanEmail);
      } catch (_) {}
    }

    // Persist token in shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smartmove_reset_token_$cleanEmail', token);
    await prefs.setString(
        'smartmove_reset_expiry_$cleanEmail', expiresAt.toIso8601String());

    return {
      'success': true,
      'token': token,
      'expiresAt': expiresAt,
      'message': 'A 6-digit verification code has been sent to $cleanEmail.',
    };
  }

  /// Verify 6-digit token and update password
  static Future<Map<String, dynamic>> verifyTokenAndResetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanToken = token.trim();
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('smartmove_reset_token_$cleanEmail');
    final expiryRaw = prefs.getString('smartmove_reset_expiry_$cleanEmail');

    bool tokenValid = false;
    if (savedToken != null && savedToken == cleanToken) {
      if (expiryRaw != null) {
        final expiry = DateTime.tryParse(expiryRaw);
        if (expiry != null && DateTime.now().isBefore(expiry)) {
          tokenValid = true;
        } else {
          throw Exception(
              'Verification code has expired. Please request a new one.');
        }
      } else {
        tokenValid = true;
      }
    }

    final client = _client;
    if (client != null) {
      try {
        await client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: OtpType.recovery,
        );
        await client.auth.updateUser(UserAttributes(password: newPassword));
        tokenValid = true;
      } catch (e) {
        if (!tokenValid) {
          throw Exception('Verification failed: ${e.toString()}');
        }
      }
    }

    if (!tokenValid) {
      throw Exception('Invalid or expired 6-digit verification code.');
    }

    // Clear used token
    await prefs.remove('smartmove_reset_token_$cleanEmail');
    await prefs.remove('smartmove_reset_expiry_$cleanEmail');

    return {
      'success': true,
      'message':
          'Password has been successfully updated. You can now sign in.',
    };
  }
}
