import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class SafeOutletLauncher {
  /// Safely prompt the user before opening an external ecommerce web site
  static Future<void> openExternalWebUrl(
    BuildContext context, {
    required String url,
    required String outletName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security_outlined, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            const Text(
              'External Store Redirect',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are leaving SmartMove to visit $outletName:',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFFF57F17)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SmartMove does not handle external checkout. Verify merchant credentials before making payments.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF5D4037)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Proceed to Store'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.errorText,
                content: Text('Could not launch URL: $url'),
              ),
            );
          }
        }
      }
    }
  }

  /// Trigger direct phone call dialer
  static Future<void> callSeller(
    BuildContext context, {
    required String phone,
    required String sellerName,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Contact $sellerName: $phone'),
          ),
        );
      }
    }
  }

  /// Launch WhatsApp with prefilled negotiation inquiry
  static Future<void> openWhatsAppNegotiation(
    BuildContext context, {
    required String phone,
    required String sellerName,
    required String commodityName,
    required double quantity,
    required String unit,
  }) async {
    final cleanPhone = phone
        .replaceAll(RegExp(r'[\s\-()+]'), '')
        .replaceFirst(RegExp(r'^0'), '234');

    final qtyStr = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString();
    final message = Uri.encodeComponent(
      'Hello $sellerName, I found your listing for $qtyStr $unit of $commodityName on SmartMove. Is this currently available for pickup or delivery?',
    );

    final whatsappUri = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    try {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('WhatsApp $sellerName at $phone'),
          ),
        );
      }
    }
  }

  /// Direct phone dialer
  static Future<void> callTraderPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Open WhatsApp with optional prefilled message
  static Future<void> openWhatsApp(
    String phone, {
    String? prefilledMessage,
  }) async {
    final cleanPhone = phone
        .replaceAll(RegExp(r'[\s\-()+]'), '')
        .replaceFirst(RegExp(r'^0'), '234');
    final query = prefilledMessage != null ? '?text=${Uri.encodeComponent(prefilledMessage)}' : '';
    final uri = Uri.parse('https://wa.me/$cleanPhone$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Check whether a phone number is a valid, dialable contact line (not null, not empty, not dummy/placeholder)
  static bool isValidPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return false;
    // Disallow dummy test repetitions like 0000000000 or 1111111111
    if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return false;
    return true;
  }
}

