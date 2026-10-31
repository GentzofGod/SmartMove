import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/safe_outlet_launcher.dart';
import '../../../core/localization/app_language.dart';
import '../../home/presentation/widgets/location_picker_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _priceAlertsEnabled = true;
  bool _marketHoursEnabled = true;
  bool _errandDeadlinesEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshProfileFromDatabase();
    });
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('smartmove_app_language') ?? 'English';
    ref.read(appLanguageProvider.notifier).setLanguage(savedLang);
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('smartmove_notifications_enabled') ?? true;
        _priceAlertsEnabled = prefs.getBool('smartmove_price_alerts_enabled') ?? true;
        _marketHoursEnabled = prefs.getBool('smartmove_market_hours_enabled') ?? true;
        _errandDeadlinesEnabled = prefs.getBool('smartmove_errand_deadlines_enabled') ?? true;
      });
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _updateLanguageSetting(String language) async {
    ref.read(appLanguageProvider.notifier).setLanguage(language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smartmove_app_language', language);
  }

  @override
  Widget build(BuildContext context) {
    final userSession = ref.watch(authProvider);
    final currentLocation = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppColors.textPrimary),
            tooltip: 'Sync Role with Database',
            onPressed: () async {
              await ref.read(authProvider.notifier).refreshProfileFromDatabase();
              if (context.mounted) {
                final currentRole = ref.read(authProvider).role;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text('Profile synced with database! Current role: $currentRole'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: [
          // User Profile Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: userSession.isAdmin
                          ? const Color(0xFF673AB7)
                          : userSession.isSeller
                              ? AppColors.primary
                              : const Color(0xFF0052CC),
                      child: Text(
                        userSession.displayName.isNotEmpty
                            ? userSession.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  userSession.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: userSession.isAdmin
                                      ? const Color(0xFFEDE7F6)
                                      : userSession.isSeller
                                          ? AppColors.badgeSuccessBg
                                          : AppColors.badgeWarningBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  userSession.isGuest
                                      ? 'Guest'
                                      : (userSession.isSuperAdmin
                                          ? 'SuperAdmin'
                                          : userSession.role),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: userSession.isAdmin
                                        ? const Color(0xFF673AB7)
                                        : userSession.isSeller
                                            ? AppColors.primary
                                            : AppColors.badgeWarningText,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                key: const ValueKey('btn_edit_user_profile'),
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                tooltip: 'Edit Profile',
                                onPressed: () => _showEditUserProfile(context, userSession),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            userSession.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (userSession.phone != null && userSession.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              userSession.phone!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (userSession.isGuest) ...[
                  const Divider(height: 24, color: AppColors.divider),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/auth'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        'Sign In or Create Account',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
                if (userSession.isSuperAdmin) ...[
                  const Divider(height: 20, color: AppColors.divider),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'SuperAdmin Role Mode:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF673AB7),
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Customer'),
                            selected: userSession.role == 'Customer',
                            selectedColor: AppColors.badgeSuccessBg,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: userSession.role == 'Customer'
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (val) {
                              if (val) {
                                ref
                                    .read(authProvider.notifier)
                                    .updateRole('Customer');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Trader / Seller'),
                            selected: userSession.role == 'Trader',
                            selectedColor: AppColors.badgeSuccessBg,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: userSession.role == 'Trader'
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (val) {
                              if (val) {
                                ref
                                    .read(authProvider.notifier)
                                    .updateRole('Trader');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Admin'),
                            selected: userSession.role == 'Admin',
                            selectedColor: const Color(0xFFEDE7F6),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: userSession.role == 'Admin'
                                  ? const Color(0xFF673AB7)
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (val) {
                              if (val) {
                                ref
                                    .read(authProvider.notifier)
                                    .updateRole('Admin');
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('SuperAdmin'),
                            selected: userSession.role == 'SuperAdmin',
                            selectedColor: const Color(0xFFFFD54F),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: userSession.role == 'SuperAdmin'
                                  ? const Color(0xFF1E1145)
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                            onSelected: (val) {
                              if (val) {
                                ref
                                    .read(authProvider.notifier)
                                    .updateRole('SuperAdmin');
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Guest Banner vs Seller Application Card for Customers
          if (userSession.isGuest) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_add_outlined,
                          color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Unlock Full SmartMove Access',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in or create a free account to apply as a verified seller, save itineraries, and contribute verified commodity prices.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/auth'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Sign In / Register',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (userSession.isCustomer) ...[
            if (userSession.canApplyForSeller) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00875A), Color(0xFF0052CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Sell on SmartMove',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Are you a commodity trader, market stall vendor, or supermarket store owner? Apply to become a Verified Seller to publish your prices directly to local shoppers.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showApplyToBecomeSeller(context, userSession),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.assignment_turned_in_rounded,
                          size: 16),
                      label: Text(
                        userSession.isRejectedSeller
                            ? 'Reapply as Verified Seller'
                            : 'Apply to Become a Verified Seller',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (userSession.isPendingSeller) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded,
                        color: Color(0xFFE65100), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seller Application Under Review',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFBF360C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your application for "${userSession.businessName ?? "your store"}" at ${userSession.marketHub ?? "Bodija Market"} is pending review by platform administrators.',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF795548),
                                height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ] else if (userSession.isSeller) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.storefront_rounded,
                              color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Registered Seller Profile',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _showEditBusinessProfile(context, userSession),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const Divider(height: 14, color: AppColors.divider),
                  Row(
                    children: [
                      const Text('Store Name: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Expanded(
                        child: Text(
                          userSession.businessName ?? '${userSession.displayName}\'s Store',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Market Hub: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        userSession.marketHub ?? 'Bodija Market',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 12),
                      const Text('Channel: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        userSession.sellerChannel ?? 'Local Market',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                  if (userSession.phone != null && userSession.phone!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Phone: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          userSession.phone!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (userSession.isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security_rounded,
                          color: Color(0xFF673AB7), size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userSession.isSuperAdmin
                                  ? 'SuperAdmin Console Active'
                                  : 'Platform Administrator Mode',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4A148C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Platform moderation privileges enabled: verify quotes, approve seller applications, and moderate listings.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF6A1B9A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      key: const ValueKey('btn_open_superadmin_from_profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF673AB7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_rounded,
                          size: 18, color: Colors.white),
                      label: const Text(
                        'Open SuperAdmin Moderation Panel',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      onPressed: () => context.push('/superadmin'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 20),

          // Menu Options List
          Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                if (userSession.isAdmin) ...[
                  _buildMenuItem(
                    key: const ValueKey('menu_superadmin_panel'),
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'SuperAdmin Moderation Panel',
                    trailingText: 'Open',
                    onTap: () => context.push('/superadmin'),
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.divider),
                ],

                _buildMenuItem(
                  key: const ValueKey('menu_market_location'),
                  icon: Icons.location_on_outlined,
                  title: 'Market Hub & Location',
                  trailingText: currentLocation.displayLocation,
                  onTap: () => LocationPickerSheet.show(context),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                ListTile(
                  key: const ValueKey('menu_notifications_tile'),
                  onTap: () => _showNotificationPreferencesSheet(context),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Price alerts, market hours & order deadlines',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  trailing: Switch(
                    key: const ValueKey('switch_notifications'),
                    value: _notificationsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _notificationsEnabled = val);
                      _updateNotificationSetting('smartmove_notifications_enabled', val);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_language'),
                  icon: Icons.language_outlined,
                  title: 'Language',
                  trailingText: ref.watch(appLanguageProvider),
                  onTap: () => _showLanguageSelectorSheet(context),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_data_privacy'),
                  icon: Icons.security_outlined,
                  title: 'Data & Privacy',
                  onTap: () => _showDataAndPrivacySheet(context),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_help_support'),
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  trailingText: 'FAQs & Desk',
                  onTap: () => _showHelpAndSupportSheet(context),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_app_guide'),
                  icon: Icons.school_outlined,
                  title: 'App Guide & Tour',
                  trailingText: 'Replay',
                  onTap: () => context.push('/onboarding'),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_about_smartmove'),
                  icon: Icons.info_outline_rounded,
                  title: 'About SmartMove',
                  trailingText: 'v1.2.0',
                  onTap: () => _showAboutSmartMoveDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Log Out / Reset Demo Data Button
          if (!userSession.isGuest) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Logged out successfully.'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.badgeErrorBg,
                  foregroundColor: AppColors.badgeErrorText,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Log Out of Account',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showApplyToBecomeSeller(BuildContext context, UserSession session) {
    final bizController = TextEditingController(text: session.businessName ?? '');
    final phoneController = TextEditingController(text: session.phone ?? '');
    final stallController = TextEditingController(text: session.stallLocation ?? '');
    String selectedHub = session.marketHub ?? 'Bodija Market';
    String selectedChannel = session.sellerChannel ?? 'Local Market';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Seller Verification Application',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Provide your business credentials. All applications undergo verification by market hub administrators before publishing access is granted.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Store / Stall Business Name',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bizController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Mama Bello Provisions & Grains',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Market Hub Base',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedHub,
                      items: const [
                        'Bodija Market',
                        'Dugbe Market',
                        'Oje Market',
                        'Oja Oba Market',
                        'Gbagi Market',
                        'Online Store',
                      ].map((hub) => DropdownMenuItem(value: hub, child: Text(hub))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedHub = val);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Seller Channel Type',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['Local Market', 'SMB Store', 'Online Retailer'].map((ch) {
                        final isSel = selectedChannel == ch;
                        return ChoiceChip(
                          label: Text(ch),
                          selected: isSel,
                          selectedColor: AppColors.badgeSuccessBg,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSel ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedChannel = ch);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Stall Number / Location Address',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: stallController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Stall B44, Main Grain Section, Bodija',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'WhatsApp / Phone Number',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. +234 803 123 4567',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (bizController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please provide your business name and contact phone.'),
                                backgroundColor: AppColors.badgeErrorText,
                              ),
                            );
                            return;
                          }

                          ref.read(sellerApplicationsProvider.notifier).submitApplication(
                                user: session,
                                businessName: bizController.text.trim(),
                                marketHub: selectedHub,
                                sellerChannel: selectedChannel,
                                stallLocation: stallController.text.trim().isNotEmpty
                                    ? stallController.text.trim()
                                    : null,
                                phone: phoneController.text.trim(),
                              );

                          Navigator.pop(bottomSheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Seller verification application submitted! Awaiting administrator approval.'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        child: const Text(
                          'Submit Seller Application',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditBusinessProfile(BuildContext context, UserSession session) {
    final bizController = TextEditingController(text: session.businessName ?? '');
    final phoneController = TextEditingController(text: session.phone ?? '');
    String selectedHub = session.marketHub ?? 'Bodija Market';
    String selectedChannel = session.sellerChannel ?? 'Local Market';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Update Store Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Business / Stall Name',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bizController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Mama Bello Provisions & Grains',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Market Hub Base',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedHub,
                      items: const [
                        'Bodija Market',
                        'Dugbe Market',
                        'Oje Market',
                        'Oja Oba Market',
                        'Gbagi Market',
                        'Online Store',
                      ].map((hub) => DropdownMenuItem(value: hub, child: Text(hub))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedHub = val);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Channel Type',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['Local Market', 'SMB Store', 'Online Retailer'].map((ch) {
                        final isSel = selectedChannel == ch;
                        return ChoiceChip(
                          label: Text(ch),
                          selected: isSel,
                          selectedColor: AppColors.badgeSuccessBg,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSel ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedChannel = ch);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Phone / WhatsApp',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. +234 803 123 4567',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ref.read(authProvider.notifier).updateSellerProfile(
                                businessName: bizController.text.trim().isNotEmpty
                                    ? bizController.text.trim()
                                    : null,
                                marketHub: selectedHub,
                                sellerChannel: selectedChannel,
                                phone: phoneController.text.trim().isNotEmpty
                                    ? phoneController.text.trim()
                                    : null,
                              );
                          Navigator.pop(bottomSheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Store profile updated successfully!'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        child: const Text(
                          'Save Store Profile',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditUserProfile(BuildContext context, UserSession session) {
    final nameController = TextEditingController(text: session.displayName);
    final emailController = TextEditingController(text: session.email);
    final phoneController = TextEditingController(text: session.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Personal Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Update your profile details and contact number for shopping and order updates.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Full Name / Display Name',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const ValueKey('input_profile_name'),
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Adebayo Johnson',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Email Address',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const ValueKey('input_profile_email'),
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'e.g. adebayo@example.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Phone Number / WhatsApp',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const ValueKey('input_profile_phone'),
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'e.g. +234 802 345 6789',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const ValueKey('btn_save_user_profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Display name cannot be empty.'),
                            backgroundColor: AppColors.badgeErrorText,
                          ),
                        );
                        return;
                      }

                      ref.read(authProvider.notifier).updateUserProfile(
                            displayName: name,
                            email: emailController.text.trim().isNotEmpty
                                ? emailController.text.trim()
                                : null,
                            phone: phoneController.text.trim().isNotEmpty
                                ? phoneController.text.trim()
                                : null,
                          );

                      Navigator.pop(bottomSheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Personal profile updated successfully!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationPreferencesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notification Preferences',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Configure market price drop alerts, opening hours, and grocery errand notifications.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    key: const ValueKey('pref_switch_notifications'),
                    title: const Text('Master Push Notifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Enable or disable all notifications from SmartMove', style: TextStyle(fontSize: 11)),
                    value: _notificationsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _notificationsEnabled = val);
                      setModalState(() {});
                      _updateNotificationSetting('smartmove_notifications_enabled', val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const ValueKey('pref_switch_price_alerts'),
                    title: const Text('Commodity Price Drop Alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Get notified when monitored commodities drop >5% in Bodija, Mile 12, or e-commerce stores', style: TextStyle(fontSize: 11)),
                    value: _priceAlertsEnabled && _notificationsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _notificationsEnabled
                        ? (val) {
                            setState(() => _priceAlertsEnabled = val);
                            setModalState(() {});
                            _updateNotificationSetting('smartmove_price_alerts_enabled', val);
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const ValueKey('pref_switch_market_hours'),
                    title: const Text('Market Hours & Trading Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Reminders for early morning market rush hours and weekly wholesale market days', style: TextStyle(fontSize: 11)),
                    value: _marketHoursEnabled && _notificationsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _notificationsEnabled
                        ? (val) {
                            setState(() => _marketHoursEnabled = val);
                            setModalState(() {});
                            _updateNotificationSetting('smartmove_market_hours_enabled', val);
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const ValueKey('pref_switch_errand_deadlines'),
                    title: const Text('Errand & Delivery Deadlines', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: const Text('Alerts when scheduled errands or deliveries approach their target deadline', style: TextStyle(fontSize: 11)),
                    value: _errandDeadlinesEnabled && _notificationsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _notificationsEnabled
                        ? (val) {
                            setState(() => _errandDeadlinesEnabled = val);
                            setModalState(() {});
                            _updateNotificationSetting('smartmove_errand_deadlines_enabled', val);
                          }
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageSelectorSheet(BuildContext context) {
    final currentLanguage = ref.read(appLanguageProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Dialect / Language',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(bottomSheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Choose from 15 common Nigerian languages and dialects across all geopolitical zones for localized navigation and price comparison.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: AppStrings.supportedLanguages.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 12, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final lang = AppStrings.supportedLanguages[index];
                      final isSelected = currentLanguage == lang.name;
                      return ListTile(
                        key: ValueKey('lang_option_${lang.name}'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        selected: isSelected,
                        selectedTileColor: AppColors.primaryTint.withValues(alpha: 0.5),
                        title: Row(
                          children: [
                            Text(
                              lang.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lang.code.toUpperCase(),
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang.nativeName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                            Text(lang.region, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                            : null,
                        onTap: () {
                          _updateLanguageSetting(lang.name);
                          Navigator.pop(bottomSheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Language set to ${lang.name}!'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDataAndPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Data & Privacy Security',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Transparent, secure, and privacy-first market intelligence.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                  title: const Text('Zero Financial Credential Storage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: const Text('SmartMove never collects or stores bank account passwords or debit card credentials.', style: TextStyle(fontSize: 11)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mic_none_rounded, color: AppColors.primary),
                  title: const Text('Transient Audio Processing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Voice inputs are processed transiently in RAM and discarded immediately.', style: TextStyle(fontSize: 11)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storage_outlined, color: AppColors.primary),
                  title: const Text('Local Offline Cache Encrypted', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Your itineraries and preferences reside encrypted on this device.', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    key: const ValueKey('btn_clear_offline_cache_from_privacy'),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear Offline Price Cache'),
                    onPressed: () async {
                      await ref.read(productsProvider.notifier).fetchLive();
                      if (context.mounted) {
                        Navigator.pop(bottomSheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Offline price cache cleared and refreshed with live data!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpAndSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Help & Customer Support',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Quick answers to common questions and direct trader assistance.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                // FAQs
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Column(
                    children: [
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('How does SmartMove compare commodity prices?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'SmartMove combines real-time physical market stalls (Bodija, Mile 12, Wuse) with verified e-commerce platforms (Jumia, Konga, Supermart.ng). Meta Muse normalizes units to compare true landed cost including transport.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('How do I become a verified seller?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Apply directly from your Profile by providing your business name, market hub base, stall number, and WhatsApp number. Market moderators review and approve your application within 24 hours.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('How does the paper shopping list scanner work?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Snap a photo of your handwritten shopping list or receipt. Meta Muse Vision extracts the items, units, and suggested budget, generating a structured comparison plan.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('What if a market price is different from the app?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Commodity prices in open markets fluctuate depending on arrival times and supply. You can submit real-time price reports on the Discover tab to help the entire community.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey('btn_whatsapp_support'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('WhatsApp Desk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          SafeOutletLauncher.openExternalWebUrl(
                            context,
                            url: 'https://wa.me/2348000000000?text=Hello%20SmartMove%20Support%20Desk',
                            outletName: 'SmartMove WhatsApp Support',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('btn_email_support'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: const Text('Email Support', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          SafeOutletLauncher.openEmailSupport(
                            context,
                            email: 'support@smartmove.ng',
                            subject: 'SmartMove Support Inquiry',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAboutSmartMoveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SmartMove', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text('v1.2.0 (Build 2026.10)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Meta AI Architecture: Meta Muse Spark 1.3',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF512DA8)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SmartMove is an intelligent commodity price comparison and errand planning platform built for everyday shoppers, market merchants, and consumers across Nigeria.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Key Innovations:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text('• Dual-Layer Web Search Grounding for fresh produce and appliances', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                const Text('• Push-to-Talk Multi-Dialect Voice Transcribe (Pidgin, Yorùbá, Hausa, Igbo)', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                const Text('• Standardized Landed Cost & Transport Fare Engine', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                const Text('• Supabase Realtime Moderation & Verified Trader Badges', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    '© 2026 SmartMove Technologies. All rights reserved.',
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuItem({
    Key? key,
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                trailingText,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
