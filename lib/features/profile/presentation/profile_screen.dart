import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/seller_application.dart';
import '../../../core/services/safe_outlet_launcher.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/presentation/widgets/language_selection_sheet.dart';

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


  @override
  Widget build(BuildContext context) {
    final rawUserSession = ref.watch(authProvider);
    final applications = ref.watch(sellerApplicationsProvider);
    final unreadMessages = ref.watch(unreadMessageCountProvider);

    final matchingApp = applications.cast<SellerApplication?>().firstWhere(
          (a) =>
              a != null &&
              (a.userId == rawUserSession.id ||
                  (!rawUserSession.isGuest &&
                      rawUserSession.email.isNotEmpty &&
                      a.applicantEmail.trim().toLowerCase() ==
                          rawUserSession.email.trim().toLowerCase())),
          orElse: () => null,
        );

    final userSession = (matchingApp != null &&
            matchingApp.status == SellerApplicationStatus.approved &&
            !rawUserSession.isApprovedSeller)
        ? rawUserSession.copyWith(
            role: 'Trader',
            sellerApplicationStatus: SellerApplicationStatus.approved,
            businessName:
                rawUserSession.businessName ?? matchingApp.businessName,
            marketHub: rawUserSession.marketHub ?? matchingApp.marketHub,
            sellerChannel:
                rawUserSession.sellerChannel ?? matchingApp.sellerChannel,
            phone: rawUserSession.phone ?? matchingApp.phone,
            stallLocation:
                rawUserSession.stallLocation ?? matchingApp.stallLocation,
            latitude: rawUserSession.latitude ?? matchingApp.latitude,
            longitude: rawUserSession.longitude ?? matchingApp.longitude,
          )
        : (matchingApp != null &&
                matchingApp.status == SellerApplicationStatus.pending &&
                !rawUserSession.isApprovedSeller &&
                !rawUserSession.isPendingSeller)
            ? rawUserSession.copyWith(
                sellerApplicationStatus: SellerApplicationStatus.pending,
                businessName:
                    rawUserSession.businessName ?? matchingApp.businessName,
                marketHub: rawUserSession.marketHub ?? matchingApp.marketHub,
                phone: rawUserSession.phone ?? matchingApp.phone,
              )
            : rawUserSession;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.tr(ref, 'profileAndSettings'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
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
                          : (userSession.isSeller || userSession.isApprovedSeller)
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
                              Expanded(
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
                              if (userSession.isAdmin || userSession.isSeller || userSession.isApprovedSeller) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: userSession.isAdmin
                                        ? const Color(0xFFEDE7F6)
                                        : AppColors.badgeSuccessBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    userSession.isSuperAdmin
                                        ? 'SuperAdmin'
                                        : (userSession.isAdmin
                                            ? 'Admin'
                                            : (userSession.role == 'Trader' ? 'Trader' : 'Verified Seller')),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: userSession.isAdmin
                                          ? const Color(0xFF673AB7)
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
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

          // Seller Application Card for Customers
          if (userSession.isCustomer) ...[
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
                            'Your application for "${userSession.businessName ?? "your store"}" at ${userSession.marketHub ?? (userSession.stallLocation ?? "your registered market")} is pending review by platform administrators.',
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
          ] else if (userSession.isSeller || userSession.isApprovedSeller) ...[
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
                      Expanded(
                        child: Row(
                          children: const [
                            Icon(Icons.storefront_rounded,
                                color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Registered Seller Profile',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                      Expanded(
                        child: Text(
                          userSession.marketHub ?? (userSession.stallLocation ?? 'Local Store'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Channel: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        userSession.sellerChannel ?? 'Local Market',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                  if (userSession.stallLocation != null && userSession.stallLocation!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stall Location: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(
                            userSession.stallLocation!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  if (userSession.hasPendingStoreEdit) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded,
                              color: Color(0xFFE65100), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userSession.pendingStoreEditSummary != null
                                  ? 'Store Edit Pending Review: ${userSession.pendingStoreEditSummary!}'
                                  : 'Store Edit Pending Admin Verification',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFBF360C)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const ValueKey('btn_open_seller_portal_profile'),
                      onPressed: () {
                        context.push('/seller-portal');
                      },
                      icon: const Icon(Icons.storefront_rounded, size: 16),
                      label: const Text('Open Seller Portal',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
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
                ListTile(
                  key: const ValueKey('menu_messages_inquiries'),
                  onTap: () => context.push('/messages'),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Message Box & Inquiries',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Buyer negotiations and seller inquiries',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unreadMessages > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadMessages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                    ],
                  ),
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
                  title: AppStrings.tr(ref, 'language'),
                  trailingText: ref.watch(appLanguageProvider),
                  onTap: () => _showLanguageSelectorSheet(context),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_data_privacy'),
                  icon: Icons.security_outlined,
                  title: AppStrings.tr(ref, 'dataAndPrivacy'),
                  onTap: () => _showDataAndPrivacySheet(context),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_legal_terms'),
                  icon: Icons.gavel_outlined,
                  title: AppStrings.tr(ref, 'legalAndTerms'),
                  onTap: () => context.push('/legal'),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_help_support'),
                  icon: Icons.help_outline_rounded,
                  title: AppStrings.tr(ref, 'helpAndSupport'),
                  onTap: () => _showHelpAndSupportSheet(context),
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  key: const ValueKey('menu_about_smartmove'),
                  icon: Icons.info_outline_rounded,
                  title: AppStrings.tr(ref, 'aboutSmartMove'),
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
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      title: Row(
                        children: const [
                          Icon(Icons.logout_rounded,
                              color: AppColors.badgeErrorText),
                          SizedBox(width: 8),
                          Text(
                            'Sign Out?',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      content: const Text(
                        'Are you sure you want to log out of your SmartMove account? You will need to sign in again to access verified seller privileges and saved data.',
                        style: TextStyle(fontSize: 13.5, height: 1.4),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.badgeErrorBg,
                            foregroundColor: AppColors.badgeErrorText,
                            elevation: 0,
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
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
    ),
  );
}

  void _showApplyToBecomeSeller(BuildContext context, UserSession session) {
    final bizController = TextEditingController(text: session.businessName ?? '');
    final phoneController = TextEditingController(text: session.phone ?? '');
    final stallController = TextEditingController(text: session.stallLocation ?? '');
    double? scannedLat = session.latitude;
    double? scannedLon = session.longitude;
    bool isScanningLocation = false;
    final userLoc = ref.read(locationProvider);
    String selectedHub = session.marketHub ?? (userLoc.isSet ? userLoc.displayLocation : 'Kuto Market, Abeokuta');
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stall Number / Location Address',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        if (scannedLat != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.badgeSuccessBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primary),
                                SizedBox(width: 3),
                                Text(
                                  'GPS Verified',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // High Accuracy GPS Stall Scanner
                    InkWell(
                      key: const ValueKey('btn_scan_stall_gps_profile'),
                      onTap: isScanningLocation
                          ? null
                          : () async {
                              setModalState(() => isScanningLocation = true);
                              try {
                                final activeLoc = ref.read(locationProvider);
                                final result = await LocationService.scanDetailedStallLocation(
                                  fallback: activeLoc.isSet ? activeLoc : null,
                                );
                                if (result != null) {
                                  final prefix = stallController.text.trim();
                                  final detailed = result.formatStallAddress(
                                    prefix: prefix.isNotEmpty && !prefix.contains('Lat:') ? prefix : null,
                                  );
                                  stallController.text = detailed;
                                  scannedLat = result.latitude;
                                  scannedLon = result.longitude;
                                  if (result.closestHub.isNotEmpty) {
                                    selectedHub = result.closestHub;
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Accurate GPS locked: ${result.town}, ${result.city} (GPS Verified)'),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not acquire your GPS location. Please check location permissions or enter stall address manually.'),
                                        backgroundColor: AppColors.badgeErrorText,
                                      ),
                                    );
                                  }
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Location scan encountered an issue. Please enter your stall address manually.'),
                                      backgroundColor: AppColors.badgeErrorText,
                                    ),
                                  );
                                }
                              } finally {
                                setModalState(() => isScanningLocation = false);
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: scannedLat != null ? AppColors.badgeSuccessBg : AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scannedLat != null
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isScanningLocation)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            else
                              Icon(
                                scannedLat != null ? Icons.gps_fixed_rounded : Icons.my_location_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isScanningLocation
                                        ? 'Scanning high-accuracy GPS location...'
                                        : (scannedLat != null
                                            ? 'Physical Stall GPS Locked & Verified'
                                            : 'Scan Precise Stall GPS Location'),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    scannedLat != null
                                        ? 'High-accuracy coordinates locked for buyer map navigation'
                                        : 'Auto-detect your stall address & GPS so buyers can navigate to you',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scannedLat != null ? AppColors.primaryDark : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: stallController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Shop 14, Commercial District, Abeokuta',
                        helperText: 'Buyers will navigate to this precise physical address or stall GPS.',
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

                          final stallText = stallController.text.trim();
                          final hubToSave = selectedHub.isNotEmpty
                              ? selectedHub
                              : (stallText.isNotEmpty
                                  ? stallText
                                  : (userLoc.isSet ? userLoc.displayLocation : 'Local Market'));

                          ref.read(sellerApplicationsProvider.notifier).submitApplication(
                                user: session,
                                businessName: bizController.text.trim(),
                                marketHub: hubToSave,
                                sellerChannel: selectedChannel,
                                stallLocation: stallText.isNotEmpty
                                    ? stallText
                                    : null,
                                latitude: scannedLat,
                                longitude: scannedLon,
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
    final stallController = TextEditingController(text: session.stallLocation ?? session.marketHub ?? '');
    double? scannedLat = session.latitude;
    double? scannedLon = session.longitude;
    bool isScanningLocation = false;
    final userLoc = ref.read(locationProvider);
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
                    if (session.isApprovedSeller) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.shield_outlined,
                                color: Color(0xFFE65100), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Market Credibility Verification: Changes to verified seller store details are submitted to administrators for verification before taking effect.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF795548),
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Physical Store / Stall Address',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        if (scannedLat != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.badgeSuccessBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primary),
                                SizedBox(width: 3),
                                Text(
                                  'GPS Verified',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: stallController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Shop 14, Commercial District, Abeokuta',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isScanningLocation
                          ? null
                          : () async {
                              setModalState(() => isScanningLocation = true);
                              try {
                                final activeLoc = ref.read(locationProvider);
                                final result = await LocationService.scanDetailedStallLocation(
                                  fallback: activeLoc.isSet ? activeLoc : null,
                                );
                                if (result != null) {
                                  final prefix = stallController.text.trim();
                                  final detailed = result.formatStallAddress(
                                    prefix: prefix.isNotEmpty && !prefix.contains('Lat:') ? prefix : null,
                                  );
                                  stallController.text = detailed;
                                  scannedLat = result.latitude;
                                  scannedLon = result.longitude;
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Accurate GPS locked: ${result.town}, ${result.city} (GPS Verified)'),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                }
                              } catch (_) {
                              } finally {
                                setModalState(() => isScanningLocation = false);
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scannedLat != null ? AppColors.badgeSuccessBg : AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: scannedLat != null
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              scannedLat != null ? Icons.gps_fixed_rounded : Icons.my_location_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isScanningLocation
                                    ? 'Scanning GPS location...'
                                    : (scannedLat != null
                                        ? 'GPS Location Locked (Accurate Plain-Text Address)'
                                        : '📍 Scan Current GPS Location'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                          final newBizName = bizController.text.trim().isNotEmpty
                              ? bizController.text.trim()
                              : (session.businessName ?? '');
                          final newPhone = phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : (session.phone ?? '');
                          final newStall = stallController.text.trim().isNotEmpty
                              ? stallController.text.trim()
                              : session.stallLocation;
                          final hubLocation = newStall != null && newStall.isNotEmpty
                              ? newStall
                              : (userLoc.isSet ? userLoc.displayLocation : 'Local Store');

                          if (session.isApprovedSeller) {
                            ref
                                .read(storeEditRequestsProvider.notifier)
                                .submitRequest(
                                  seller: session,
                                  proposedBusinessName: newBizName,
                                  proposedMarketHub: hubLocation,
                                  proposedStallLocation: newStall,
                                  proposedPhone: newPhone,
                                  proposedSellerChannel: selectedChannel,
                                );
                            ref.read(authProvider.notifier).updateSellerProfile(
                                  businessName: newBizName,
                                  marketHub: hubLocation,
                                  stallLocation: newStall,
                                  latitude: scannedLat,
                                  longitude: scannedLon,
                                  phone: newPhone,
                                  sellerChannel: selectedChannel,
                                  hasPendingStoreEdit: true,
                                  pendingStoreEditSummary: '$newBizName ($hubLocation)',
                                );
                            ref.read(sellerApplicationsProvider.notifier).updateApplicationStoreDetails(
                                  userId: session.id,
                                  userEmail: session.email,
                                  businessName: newBizName,
                                  marketHub: hubLocation,
                                  stallLocation: newStall,
                                  phone: newPhone,
                                  sellerChannel: selectedChannel,
                                );
                            Navigator.pop(bottomSheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Store details updated & queued for admin verification!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          } else {
                            ref.read(authProvider.notifier).updateSellerProfile(
                                  businessName: newBizName,
                                  marketHub: hubLocation,
                                  sellerChannel: selectedChannel,
                                  stallLocation: newStall,
                                  latitude: scannedLat,
                                  longitude: scannedLon,
                                  phone: newPhone,
                                );
                            ref.read(sellerApplicationsProvider.notifier).updateApplicationStoreDetails(
                                  userId: session.id,
                                  userEmail: session.email,
                                  businessName: newBizName,
                                  marketHub: hubLocation,
                                  stallLocation: newStall,
                                  phone: newPhone,
                                  sellerChannel: selectedChannel,
                                );
                            Navigator.pop(bottomSheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Store profile updated successfully!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        },
                        child: Text(
                          session.isApprovedSeller
                              ? 'Submit Changes for Admin Review'
                              : 'Save Store Profile',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
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
    LanguageSelectionSheet.show(context);
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
                  subtitle: const Text('Voice inputs are processed securely in real time and discarded immediately.', style: TextStyle(fontSize: 11)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storage_outlined, color: AppColors.primary),
                  title: const Text('Local Offline Cache Encrypted', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Your itineraries and preferences remain stored safely on your device.', style: TextStyle(fontSize: 11)),
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    key: const ValueKey('btn_open_full_privacy_policy'),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Read Privacy Policy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      context.push('/legal?tab=privacy');
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
                              'SmartMove combines real-time physical market stalls (Bodija, Mile 12, Wuse) with verified e-commerce platforms (Jumia, Konga, Supermart.ng). SmartMove AI Assistant normalizes units to compare true landed cost including transport.',
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
                              'Snap a photo of your handwritten shopping list or receipt. SmartMove AI extracts the items, units, and suggested budget, generating structured comparison options.',
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
                  ),
                ),
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
                    'AI Architecture: SmartMove AI Assistant',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF512DA8)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SmartMove is a commodity price comparison platform designed for everyday shoppers, market merchants, and consumers across Nigeria.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Compare live prices across local open markets (Bodija, Mile 12, Wuse) and verified online stores, calculate transport costs, and find the best local deals.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '© 2026 SmartMove Technologies. All rights reserved.',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
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
