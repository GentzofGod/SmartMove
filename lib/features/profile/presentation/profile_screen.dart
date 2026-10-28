import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/state/app_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final decisionState = ref.watch(decisionLabProvider);

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
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary,
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Gent',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'gent@example.com',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Menu Options List
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'My Wallet',
                  trailingText:
                      '₦${decisionState.budget.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Saved Items',
                  trailingText: '12',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Saved Locations',
                  trailingText: '5',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                SwitchListTile(
                  secondary: Container(
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
                  activeThumbColor: AppColors.primary,
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                  },
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  trailingText: 'English',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  icon: Icons.security_outlined,
                  title: 'Data & Privacy',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56, color: AppColors.divider),
                _buildMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: 'About SmartMove',
                  trailingText: 'v1.0.0',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Log Out / Reset Demo Data Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session active.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset Demo Data State'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
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
            Text(
              trailingText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
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
