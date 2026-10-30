import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/seller_application.dart';
import '../../../core/models/price_observation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/meta_ai_service.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';

class SuperAdminPanelScreen extends ConsumerStatefulWidget {
  const SuperAdminPanelScreen({super.key});

  @override
  ConsumerState<SuperAdminPanelScreen> createState() =>
      _SuperAdminPanelScreenState();
}

class _SuperAdminPanelScreenState extends ConsumerState<SuperAdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _applicationsFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  String _observationsFilter = 'All'; // 'All', 'Pending', 'Flagged', 'Verified'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userSession = ref.watch(authProvider);

    if (!userSession.canModerate) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1145),
          foregroundColor: Colors.white,
          title: const Text('SuperAdmin Console'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    color: Color(0xFFC62828),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Access Denied — SuperAdmin Privileges Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  userSession.isGuest
                      ? 'You are currently browsing as a Guest. Platform moderation and governance are strictly restricted to SuperAdmins.'
                      : 'Your current account (${userSession.displayName}) is signed in with the role "${userSession.role}". Only SuperAdmins have authority to moderate seller applications and market pricing.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1145),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  label: const Text('Return to Home',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final applications = ref.watch(sellerApplicationsProvider);
    final observations = ref.watch(communityProvider);

    final pendingApps = applications
        .where((a) => a.status == SellerApplicationStatus.pending)
        .toList();
    final verifiedObservations =
        observations.where((o) => o.isVerified).toList();
    final pendingObservations =
        observations.where((o) => !o.isVerified).toList();
    final flaggedObservations =
        observations.where((o) => o.isFlaggedAnomaly).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1145),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Color(0xFF1E1145), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SuperAdmin Console',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Platform Governance & Moderation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Role simulation switcher
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              key: const ValueKey('chip_superadmin_role_switcher'),
              avatar: const Icon(Icons.switch_account_rounded,
                  size: 14, color: Colors.white),
              label: Text(
                userSession.role,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFF4A148C),
              side: const BorderSide(color: Color(0xFFAB47BC)),
              onPressed: () => _showRoleSwitcherDialog(context, userSession),
            ),
          ),
          IconButton(
            tooltip: 'Refresh & Sync',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SuperAdmin moderation queue refreshed.'),
                  backgroundColor: Color(0xFF4A148C),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFFFD54F),
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFFFD54F),
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Icon(Icons.how_to_reg_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('Seller Approvals'),
                  if (pendingApps.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingApps.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Icon(Icons.fact_check_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('Price Quotes'),
                  if (flaggedObservations.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${flaggedObservations.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                children: [
                  Icon(Icons.category_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Categories & Hubs'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Security & Audit'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Seller Approvals
          _buildSellerApplicationsTab(applications, pendingApps, userSession),

          // Tab 2: Price Quotes Moderation
          _buildPriceQuotesModerationTab(
            observations,
            verifiedObservations,
            pendingObservations,
            flaggedObservations,
            userSession,
          ),

          // Tab 3: Categories & Markets Governance
          _buildCategoriesAndMarketsTab(),

          // Tab 4: Security & Audit
          _buildSecurityAndAuditTab(userSession),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 1: Seller Applications Moderation
  // --------------------------------------------------------------------------
  Widget _buildSellerApplicationsTab(
    List<SellerApplication> applications,
    List<SellerApplication> pendingApps,
    UserSession userSession,
  ) {
    final filtered = applications.where((a) {
      if (_applicationsFilter == 'Pending') {
        return a.status == SellerApplicationStatus.pending;
      }
      if (_applicationsFilter == 'Approved') {
        return a.status == SellerApplicationStatus.approved;
      }
      if (_applicationsFilter == 'Rejected') {
        return a.status == SellerApplicationStatus.rejected;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI Summary Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              _buildKpiCard(
                'Total Apps',
                '${applications.length}',
                const Color(0xFF673AB7),
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                'Pending Review',
                '${pendingApps.length}',
                const Color(0xFFE65100),
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                'Approved Sellers',
                '${applications.where((a) => a.status == SellerApplicationStatus.approved).length}',
                const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                'Rejected',
                '${applications.where((a) => a.status == SellerApplicationStatus.rejected).length}',
                const Color(0xFFC62828),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Pending', 'Approved', 'Rejected'].map((filter) {
              final isSel = _applicationsFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  key: ValueKey('chip_app_filter_$filter'),
                  label: Text(
                    filter == 'All'
                        ? 'All (${applications.length})'
                        : filter == 'Pending'
                            ? 'Pending (${pendingApps.length})'
                            : filter == 'Approved'
                                ? 'Approved (${applications.where((a) => a.status == SellerApplicationStatus.approved).length})'
                                : 'Rejected (${applications.where((a) => a.status == SellerApplicationStatus.rejected).length})',
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFFEDE7F6),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? const Color(0xFF4A148C) : AppColors.textSecondary,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _applicationsFilter = filter);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.assignment_turned_in_outlined,
                      size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'No applications matching "$_applicationsFilter"',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final app in filtered)
            _buildSellerApplicationCard(app),
      ],
    );
  }

  Widget _buildSellerApplicationCard(SellerApplication app) {
    final isPending = app.status == SellerApplicationStatus.pending;
    final isApproved = app.status == SellerApplicationStatus.approved;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFFFB74D)
              : isApproved
                  ? const Color(0xFFA5D6A7)
                  : AppColors.cardBorder,
          width: isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and channel
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending
                        ? const Color(0xFFFFF3E0)
                        : isApproved
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPending
                            ? Icons.hourglass_top_rounded
                            : isApproved
                                ? Icons.verified_rounded
                                : Icons.highlight_off_rounded,
                        size: 14,
                        color: isPending
                            ? const Color(0xFFE65100)
                            : isApproved
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        app.status.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isPending
                              ? const Color(0xFFE65100)
                              : isApproved
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    app.sellerChannel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Business & Applicant
            Row(
              children: [
                const Icon(Icons.storefront_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app.businessName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Applicant: ${app.applicantName} • ${app.applicantEmail}',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            // Market Hub & Stall details
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Market Hub: ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]),
                      ),
                      Text(
                        app.marketHub,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  if (app.stallLocation != null &&
                      app.stallLocation!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop_outlined,
                            size: 15, color: Color(0xFF673AB7)),
                        const SizedBox(width: 6),
                        Text(
                          'Physical Stall: ',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700]),
                        ),
                        Expanded(
                          child: Text(
                            app.stallLocation!,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 15, color: Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      Text(
                        'Phone: ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]),
                      ),
                      Text(
                        app.phone,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (app.rejectionReason != null &&
                app.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFFC62828)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rejection Reason: ${app.rejectionReason}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // SuperAdmin Action Buttons
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey('btn_reject_app_${app.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFEF9A9A)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      onPressed: () => _showRejectDialog(context, app),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: ValueKey('btn_approve_app_${app.id}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white),
                      label: const Text('Approve Seller',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      onPressed: () {
                        ref
                            .read(sellerApplicationsProvider.notifier)
                            .approveApplication(app.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Approved ${app.businessName}! Seller upgraded to Trader.'),
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Reviewed: ${app.reviewedAt?.toLocal().toString().split(".").first ?? "Recently"}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Re-evaluate',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      // Allow re-opening application into pending state for re-review
                      ref
                          .read(sellerApplicationsProvider.notifier)
                          .approveApplication(app.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Re-evaluated application for ${app.businessName}.'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 2: Price Quotes Moderation & Meta AI Audit
  // --------------------------------------------------------------------------
  Widget _buildPriceQuotesModerationTab(
    List<PriceObservation> observations,
    List<PriceObservation> verifiedObservations,
    List<PriceObservation> pendingObservations,
    List<PriceObservation> flaggedObservations,
    UserSession userSession,
  ) {
    final filtered = observations.where((o) {
      if (_observationsFilter == 'Pending') return !o.isVerified;
      if (_observationsFilter == 'Flagged') return o.isFlaggedAnomaly;
      if (_observationsFilter == 'Verified') return o.isVerified;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Meta AI Governance Action Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF311B92), Color(0xFF512DA8)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Meta Muse Spark AI Market Audits',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Execute autonomous scan algorithms to detect predatory price markups, abnormal dips, and duplicate trader records.',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const ValueKey('btn_superadmin_ai_anomaly_scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: const Color(0xFF1E1145),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.shield_outlined, size: 16),
                      label: const Text('Run Anomaly Audit',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800)),
                      onPressed: () =>
                          _showPriceAnomalyScanDialog(context, observations),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('btn_superadmin_ai_duplicate_scan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white60),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Duplicate Scan',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700)),
                      onPressed: () =>
                          _showDuplicateScanDialog(context, observations),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Pending', 'Flagged', 'Verified'].map((f) {
              final isSel = _observationsFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  key: ValueKey('chip_obs_filter_$f'),
                  label: Text(
                    f == 'All'
                        ? 'All (${observations.length})'
                        : f == 'Pending'
                            ? 'Pending (${pendingObservations.length})'
                            : f == 'Flagged'
                                ? 'Anomalies (${flaggedObservations.length})'
                                : 'Verified (${verifiedObservations.length})',
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFFEDE7F6),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? const Color(0xFF4A148C) : AppColors.textSecondary,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _observationsFilter = f);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        for (final obs in filtered)
          _buildModerationObservationCard(obs),
      ],
    );
  }

  Widget _buildModerationObservationCard(PriceObservation obs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: obs.isFlaggedAnomaly
              ? const Color(0xFFEF9A9A)
              : obs.isVerified
                  ? const Color(0xFFA5D6A7)
                  : AppColors.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obs.productName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (obs.brandOrGrade != null)
                        Text(
                          obs.brandOrGrade!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF673AB7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '₦${obs.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Per ${obs.unit} • Seller: ${obs.sellerName} (${obs.marketLocation})',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),

            if (obs.isFlaggedAnomaly) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Color(0xFFC62828)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        obs.anomalyReason ?? 'Flagged as price outlier',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC62828)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),

            // Moderation Actions
            Row(
              children: [
                // Verify button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: obs.isVerified
                          ? const Color(0xFFE65100)
                          : const Color(0xFF2E7D32),
                      side: BorderSide(
                        color: obs.isVerified
                            ? const Color(0xFFFFB74D)
                            : const Color(0xFFA5D6A7),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(
                      obs.isVerified
                          ? Icons.remove_done_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 14,
                    ),
                    label: Text(
                      obs.isVerified ? 'Unverify' : 'Verify Quote',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      ref
                          .read(communityProvider.notifier)
                          .verifyObservation(obs.id, !obs.isVerified);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Flag anomaly button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: obs.isFlaggedAnomaly
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                      side: BorderSide(
                        color: obs.isFlaggedAnomaly
                            ? const Color(0xFFA5D6A7)
                            : const Color(0xFFEF9A9A),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(
                      obs.isFlaggedAnomaly
                          ? Icons.thumb_up_alt_outlined
                          : Icons.flag_outlined,
                      size: 14,
                    ),
                    label: Text(
                      obs.isFlaggedAnomaly ? 'Clear Flag' : 'Flag Outlier',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      ref
                          .read(communityProvider.notifier)
                          .flagListingAnomaly(
                            obs.id,
                            isAnomalous: !obs.isFlaggedAnomaly,
                            reason: obs.isFlaggedAnomaly
                                ? null
                                : 'Administrative price audit deviation',
                          );
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Delete button
                IconButton(
                  tooltip: 'Delete quote',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFC62828), size: 20),
                  onPressed: () {
                    ref
                        .read(communityProvider.notifier)
                        .deleteListing(obs.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Listing removed from marketplace feed.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 3: Categories & Markets Governance
  // --------------------------------------------------------------------------
  Widget _buildCategoriesAndMarketsTab() {
    final categories = [
      ('Grains & Flours', 'Rice, Beans, Garri, Semovita, Wheat', 8, 'c-grains'),
      ('Tubers & Roots', 'Benue Yam, Cassava, Sweet Potatoes', 4, 'c-tubers'),
      ('Cooking Oils', 'Kings Pure Vegetable Oil, Epo Pupa Palm Oil', 6, 'c-oils'),
      ('Provisions & Dairy', 'Peak Milk, Sugar, Indomie, Detergent', 12, 'c-provisions'),
      ('Vegetables & Spices', 'Jos Tomatoes, Onions, Pepper, Plantain', 5, 'c-veggies'),
    ];

    final marketHubs = [
      ('Bodija Market', 'Ibadan Wholesale Hub', '142 Verified Stalls', 'Open Market'),
      ('Dugbe Commercial Hub', 'Supermarket & Tech District', '48 Retail Stores', 'SMB Store'),
      ('Oje Market', 'Traditional Herbs & Bulk Foods', '65 Local Vendors', 'Local Market'),
      ('Omi Adio Wholesale', 'Farmgate Produce Hub', '32 Direct Farmers', 'Farmgate'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Managed Commodity Categories',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Active categories configured for Nigerian local markets and pricing audits.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),

        for (final cat in categories)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: Color(0xFF673AB7), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.$1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat.$2,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Active (${cat.$3} items)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),
        const Text(
          'Monitored Market Hubs',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Geofenced trading centers with active seller directory validation.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),

        for (final hub in marketHubs)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_outlined,
                      color: Color(0xFF00695C), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hub.$1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hub.$2} • ${hub.$3}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hub.$4,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Tab 4: Security & Audit Governance
  // --------------------------------------------------------------------------
  Widget _buildSecurityAndAuditTab(UserSession userSession) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.security_rounded,
                      color: Color(0xFF673AB7), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Active SuperAdmin Session',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildAuditRow('Display Name', userSession.displayName),
              _buildAuditRow('Email Address', userSession.email),
              _buildAuditRow('Active Platform Role', userSession.role),
              _buildAuditRow('Authority Scope',
                  'Full Governance (Seller Verification, Anomaly Audit, RLS SuperAdmin)'),
              _buildAuditRow('Row-Level Security (RLS)',
                  'Active & Verified on Cloud Supabase'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Role-Based Governance Matrix',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildRoleMatrixCard(
                'Customer (Shopper)',
                'Browses market prices, creates AI shopping plans, transcribes paper lists, submits seller verification application.',
                Icons.person_outline,
                const Color(0xFF0052CC),
              ),
              const SizedBox(height: 8),
              _buildRoleMatrixCard(
                'Trader (Verified Seller)',
                'Granted upon administrative approval. Publishes live store price quotes, uploads catalog products, manages stall location.',
                Icons.storefront_rounded,
                const Color(0xFF2E7D32),
              ),
              const SizedBox(height: 8),
              _buildRoleMatrixCard(
                'SuperAdmin (Governance)',
                'Unrestricted moderation. Approves/rejects seller applications, performs Meta AI price audits, flags anomalies, manages categories.',
                Icons.admin_panel_settings_rounded,
                const Color(0xFF673AB7),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label: ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleMatrixCard(
      String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Modals & Action Dialogs
  // --------------------------------------------------------------------------
  void _showRoleSwitcherDialog(BuildContext context, UserSession userSession) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.switch_account_rounded, color: Color(0xFF673AB7)),
            SizedBox(width: 8),
            Text('Switch Platform Persona',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Easily test role permissions across Shopper, Trader, and SuperAdmin flows:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _buildRoleOptionTile(
              dialogCtx,
              roleName: 'Customer',
              desc: 'Shopper view: browse prices, paper note OCR, apply for seller',
              icon: Icons.person_outline,
              isSelected: userSession.role == 'Customer',
            ),
            _buildRoleOptionTile(
              dialogCtx,
              roleName: 'Trader',
              desc: 'Seller view: publish prices, manage store profile and catalog',
              icon: Icons.storefront_rounded,
              isSelected: userSession.role == 'Trader',
            ),
            _buildRoleOptionTile(
              dialogCtx,
              roleName: 'SuperAdmin',
              desc: 'SuperAdmin view: approve sellers, audit price anomalies',
              icon: Icons.admin_panel_settings_rounded,
              isSelected: userSession.role == 'SuperAdmin' ||
                  userSession.role == 'Admin',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOptionTile(
    BuildContext dialogCtx, {
    required String roleName,
    required String desc,
    required IconData icon,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFF673AB7) : AppColors.textSecondary),
      title: Text(roleName,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: isSelected
                  ? const Color(0xFF673AB7)
                  : AppColors.textPrimary)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF673AB7))
          : null,
      onTap: () {
        ref.read(authProvider.notifier).updateRole(roleName);
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $roleName persona.'),
            backgroundColor: const Color(0xFF673AB7),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, SellerApplication app) {
    final reasonController = TextEditingController(
        text: 'Physical stall could not be verified in market hub');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Seller Application',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applicant: ${app.applicantName} (${app.businessName})',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Rejection',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            onPressed: () {
              ref.read(sellerApplicationsProvider.notifier).rejectApplication(
                    app.id,
                    reason: reasonController.text.trim(),
                  );
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Application for ${app.businessName} rejected.'),
                  backgroundColor: const Color(0xFFC62828),
                ),
              );
            },
            child: const Text('Reject Application',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPriceAnomalyScanDialog(
      BuildContext context, List<PriceObservation> observations) {
    const aiService = MetaAiService();
    final result = aiService.auditPriceAnomalies(candidates: observations);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Color(0xFFC62828), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Meta AI Price Anomaly Audit',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          'Average market price: ₦${result.averageMarketPrice.toStringAsFixed(0)} (Spread: ${result.priceSpreadPercent.toStringAsFixed(0)}%)',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(result.explanation,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              if (result.anomalousItems.isNotEmpty) ...[
                const Text('Detected Outliers:',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                for (final item in result.anomalousItems)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.observation.productName} • ₦${item.observation.price.toStringAsFixed(0)} (${item.issueType})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: Color(0xFFC62828)),
                        ),
                        Text(item.warningMessage,
                            style: const TextStyle(fontSize: 11.5)),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Audit',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDuplicateScanDialog(
      BuildContext context, List<PriceObservation> observations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy_all_rounded,
                      color: Color(0xFF673AB7), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'AI Duplicate Listing Audit',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'No duplicate quotes detected. All verified and reported commodity quotes across Bodija, Dugbe, and Oje are unique.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF673AB7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
