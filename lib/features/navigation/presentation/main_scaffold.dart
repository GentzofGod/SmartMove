import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_language.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    try {
      final location = GoRouterState.of(context).uri.toString();
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/products') ||
          location.startsWith('/discover') ||
          location.startsWith('/community')) {
        return 1;
      }
      if (location.startsWith('/decision-lab')) return 2;
    } catch (_) {}
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/products');
        break;
      case 2:
        context.go('/decision-lab');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _calculateSelectedIndex(context);
    final homeLabel = AppStrings.tr(ref, 'navHome');
    final productsLabel = AppStrings.tr(ref, 'navProducts');
    final priceLabLabel = AppStrings.tr(ref, 'navPriceLab');

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.6), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => _onItemTapped(index, context),
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textTertiary,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home_rounded),
                label: homeLabel,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.storefront_outlined),
                activeIcon: const Icon(Icons.storefront_rounded),
                label: productsLabel,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.analytics_outlined),
                activeIcon: const Icon(Icons.analytics_rounded),
                label: priceLabLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
