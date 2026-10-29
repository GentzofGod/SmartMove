import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/guide_service.dart';
import '../../../core/services/location_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkInitialRoute();
  }

  Future<void> _checkInitialRoute() async {
    // Check if the user has already seen/dismissed the guide
    final hasSeenGuide = await GuideService.hasSeenGuide();

    // Compulsory scan of location on first launch or fallback to nothing
    try {
      final persisted = await LocationService.restorePersistedLocation();
      if (persisted == null || !persisted.isSet) {
        final scanned = await LocationService.getCurrentDeviceLocation();
        if (scanned != null && scanned.isSet) {
          await LocationService.persistLocation(scanned);
        }
      }
    } catch (_) {}

    if (!mounted) return;

    if (hasSeenGuide) {
      // Guide was already completed or dismissed; proceed directly to home
      context.go('/home');
    } else {
      // First-time user: display the start screen guide
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _proceedToOnboarding() async {
    await GuideService.markGuideSeen();
    if (mounted) {
      context.go('/onboarding');
    }
  }

  Future<void> _skipToHome() async {
    await GuideService.markGuideSeen();
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _proceedToAuth() async {
    await GuideService.markGuideSeen();
    if (mounted) {
      context.push('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF042419),
              Color(0xFF073B29),
              Color(0xFF0C4E37),
            ],
          ),
        ),
        child: SafeArea(
          child: _isChecking
              ? _buildLoadingSplash()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Logo & Header
                                _buildLogoAndHeader(),
                                const SizedBox(height: 12),

                                // Core Capabilities Cards
                                _buildCapabilitiesCard(),
                                const SizedBox(height: 12),

                                // Footer CTA Buttons
                                _buildFooterButtons(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingSplash() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SmartMove',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF57D9A3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoAndHeader() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'SmartMove',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Know the Prices. Plan the Trip.\nMake the Better Decision.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFC0D5CB),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCapabilitiesCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          _buildFeatureRow(
            icon: Icons.price_check,
            title: 'Market Price Intelligence',
            subtitle: 'Get local price updates from traders and community.',
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildFeatureRow(
            icon: Icons.compare_arrows_rounded,
            title: 'Commodity Price Comparison',
            subtitle: 'Compare verified prices across online stores, local markets, & SMBs.',
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildFeatureRow(
            icon: Icons.science_outlined,
            title: 'Decision Rehearsal Engine',
            subtitle: 'Compare scenarios, adjust budget, see real cost & time.',
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButtons() {
    return Column(
      children: [
        const Text(
          'Smarter choices, closer to home.',
          style: TextStyle(
            color: Color(0xFF90BBA8),
            fontStyle: FontStyle.italic,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _proceedToOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Get Started',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _skipToHome,
              child: const Text(
                'Skip to Home',
                style: TextStyle(
                  color: Color(0xFFC0D5CB),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _proceedToAuth,
              child: const Text(
                'Log In',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF57D9A3), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFB3CFC3),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
