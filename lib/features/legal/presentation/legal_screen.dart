import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_language.dart';

class LegalScreen extends ConsumerStatefulWidget {
  final String? initialTab; // 'terms', 'privacy', 'fairtrade' or '0', '1', '2'

  const LegalScreen({super.key, this.initialTab});

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    int index = 0;
    if (widget.initialTab != null) {
      final t = widget.initialTab!.toLowerCase();
      if (t == 'privacy' || t == '1') {
        index = 1;
      } else if (t == 'fairtrade' || t == 'guidelines' || t == '2') {
        index = 2;
      }
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.tr(ref, 'legalAndTerms'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: AppStrings.tr(ref, 'termsOfService')),
            Tab(text: AppStrings.tr(ref, 'privacyPolicy')),
            Tab(text: AppStrings.tr(ref, 'fairTradeRules')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsOfServiceTab(),
          _buildPrivacyPolicyTab(),
          _buildFairTradeGuidelinesTab(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('btn_accept_legal_terms'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terms & Privacy Policy acknowledged.'),
                        backgroundColor: AppColors.primary,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.of(context).maybePop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'I Understand & Accept',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsOfServiceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildDocHeader(
          title: 'Terms of Service & User Agreement',
          subtitle: 'Effective: November 2026 • Governed under the Federal Competition and Consumer Protection Act (FCCPA 2018) of Nigeria.',
          badge: 'FCCPC Compliant',
        ),
        const SizedBox(height: 16),
        _buildSection(
          number: '1',
          title: 'Acceptance of Terms & Nigerian Commerce Eligibility',
          content:
              'By accessing or using the SmartMove mobile application and related price discovery services in Nigeria, you agree to be bound by these Terms of Service. Users must be at least 18 years of age or possess legal capacity under Nigerian law to negotiate, publish commodity quotes, or register as a verified trader.',
        ),
        _buildSection(
          number: '2',
          title: 'Real-Time Commodity Price Intelligence & Variance Disclaimer',
          content:
              'SmartMove provides algorithmic price intelligence derived from crowdsourced shopper observations, official market vendor submissions, and e-commerce channel indexing. While SmartMove enforces strict anti-anomaly verification filters, commodity prices in physical Nigerian hubs (including Bodija, Mile 12, Alaba, Onitsha Main, and Wuse) fluctuate rapidly due to transport logistics, seasonal harvest, currency movements, and informal in-person haggling. Displayed figures are standardized benchmark references.',
        ),
        _buildSection(
          number: '3',
          title: 'Verified Trader & Seller Obligations',
          content:
              'Traders applying for or holding a Verified Seller Badge agree to:\n'
              '• Publish truthful, uninflated prices for all food commodities, building supplies, and energy products.\n'
              '• Adhere to standardized Nigerian retail measures (e.g. 50kg bag, 25kg bag, 1 derica, 4-litre paint rubber, kilogram).\n'
              '• Maintain accurate physical stall addresses and geocoordinates to facilitate buyer navigation.\n'
              '• Promptly honor agreed quotes when a SmartMove shopper arrives with an active shopping plan.',
        ),
        _buildSection(
          number: '4',
          title: 'Shopper Code of Conduct & Fair Bargaining',
          content:
              'Shoppers and buyers using SmartMove agree to negotiate in good faith. Abuse of in-app messaging, spamming unfeasible counter-offers, or providing fraudulent price discrepancy reports will result in formal warnings or permanent account suspension.',
        ),
        _buildSection(
          number: '5',
          title: 'Decision Rehearsal & Route Navigation Guidance',
          content:
              'SmartMove\'s Inference Lab simulates shopping options, estimated transit cost, and multi-seller stops. Traffic congestion, sudden road diversions, and weather conditions remain the user\'s responsibility. Navigation routes are advisory and designed to minimize transit overhead.',
        ),
        _buildSection(
          number: '6',
          title: 'SuperAdmin Moderation & Sanctions',
          content:
              'SmartMove Platform Administrators and SuperAdmins maintain unilateral discretion to audit, moderate, flag, or remove anomalous price listings, and to revoke Verified Trader badges upon substantiated reports of deceptive trade practices or consumer misrepresentation.',
        ),
        _buildSection(
          number: '7',
          title: 'Limitation of Liability & Dispute Jurisdiction',
          content:
              'To the fullest extent permitted by Nigerian law, SmartMove Technologies and its affiliates shall not be liable for indirect, punitive, or consequential damages resulting from transactions conducted between independent buyers and physical market sellers. Disputes shall be subject to the exclusive jurisdiction of the courts of the Federal Republic of Nigeria.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPrivacyPolicyTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildDocHeader(
          title: 'Data & Privacy Protection Policy',
          subtitle: 'Effective: November 2026 • Full Compliance with Nigeria Data Protection Act (NDPA 2023) and NDPR Regulatory Standards.',
          badge: 'NDPA 2023 Compliant',
        ),
        const SizedBox(height: 16),
        _buildSection(
          number: '1',
          title: 'Identity of Data Controller',
          content:
              'SmartMove Technologies Nigeria is the data controller for personal information processed through the SmartMove platform. For inquiries or data subject rights requests, contact our Data Protection Officer at: privacy@smartmove.app.',
        ),
        _buildSection(
          number: '2',
          title: 'Categories of Information We Collect',
          content:
              'We collect only the minimum information necessary to power local commodity price comparison:\n'
              '• Account Information: Full name / display name, email address, optional phone number for trader orders, and chosen dialect.\n'
              '• Trader Data: Registered business name, market hub (e.g. Bodija Market), physical stall address, and verified coordinates.\n'
              '• Price Observations: Crowdsourced commodity prices, store names, and photos of physical price tags or receipts.',
        ),
        _buildSection(
          number: '3',
          title: 'Strict Non-Collection of Financial Credentials',
          content:
              'SmartMove strictly never collects, processes, or stores bank account passwords, debit card ATM PIN numbers, Bank Verification Numbers (BVN), or card CVV credentials. All transactions are direct buyer-to-seller settlements.',
        ),
        _buildSection(
          number: '4',
          title: 'Voice Input & Audio Processing Safeguards',
          content:
              'Voice search inputs (in English, Nigerian Pidgin, Yorùbá, Hausa, Igbo, etc.) are processed securely in real time exclusively to transcribe commodity search queries. Raw voice recordings are never retained, never shared with third parties, and discarded immediately after transcription.',
        ),
        _buildSection(
          number: '5',
          title: 'Local On-Device Storage & Offline Availability',
          content:
              'Your shopping basket, commodity price cache, and language preferences remain stored securely on your local device. This ensures you can access prices and saved itineraries offline without requiring an active internet connection.',
        ),
        _buildSection(
          number: '6',
          title: 'Geolocation Usage & Privacy',
          content:
              'When you allow location permissions, your GPS coordinates are resolved into human-readable Nigerian towns (e.g. "Ibadan, Oyo State" or "Ikeja, Lagos") to show nearest stores. Exact residential GPS coordinates are never exposed publicly or shared with other shoppers.',
        ),
        _buildSection(
          number: '7',
          title: 'User Rights & Data Erasure',
          content:
              'Under the NDPA 2023, you retain the fundamental right to access your stored profile, update your information, export your data, or request permanent deletion of your account and submitted price observations by contacting privacy@smartmove.app.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFairTradeGuidelinesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildDocHeader(
          title: 'Market Fair Trade & Price Integrity Guidelines',
          subtitle: 'Standards established in collaboration with Nigerian Market Trader Associations and Agricultural Commodity Boards.',
          badge: 'Fair Trade Standard',
        ),
        const SizedBox(height: 16),
        _buildSection(
          number: '1',
          title: 'Standardized Commodity Measurement Units',
          content:
              'To eliminate buyer confusion and prevent underweight deception, prices must specify standardized retail units:\n'
              '• Grains & Staples: 50kg bag, 25kg bag, 10kg bag, Derica (~850g), or 4-litre Paint Rubber (~3.2kg).\n'
              '• Tubers & Fresh Produce: Per kilogram, heap of 5 tubers, or net basket.\n'
              '• Cooking Oil & Fuel: 25-litre keg, 5-litre gallon, or 75cl bottle.\n'
              '• Building Materials: 50kg cement bag, 12mm rebar length, or cubic yard.',
        ),
        _buildSection(
          number: '2',
          title: 'Anti-Price Gouging & Quote Integrity',
          content:
              'Verified sellers may not quote artificially reduced prices on SmartMove only to demand an inflated price when a customer visits the physical stall. Prices quoted on SmartMove must be honored in good faith for confirmed itineraries.',
        ),
        _buildSection(
          number: '3',
          title: 'Criteria for Verified Seller Badge',
          content:
              'To earn and retain a Verified Trader Badge, vendors must:\n'
              '• Have an established, verifiable stall within a recognized Nigerian market or storefront.\n'
              '• Successfully pass SuperAdmin phone and physical location coordinate check.\n'
              '• Maintain a verified quote accuracy rate exceeding 90% across shopper reviews.\n'
              '• Submit price updates at least twice weekly during major market days.',
        ),
        _buildSection(
          number: '4',
          title: 'Reporting Price Fraud & Anomaly Whistleblowing',
          content:
              'Shoppers and community members who observe deceptive packaging, fake weight alterations, or counterfeit goods are encouraged to use the "Flag Price Anomaly" feature in the Community Feed. Confirmed offenders face immediate badge forfeiture and administrative ban.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDocHeader({
    required String title,
    required String subtitle,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
