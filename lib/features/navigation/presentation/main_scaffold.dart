import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/discover')) return 1;
    if (location.startsWith('/decision-lab')) return 2;
    if (location.startsWith('/community')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/discover');
        break;
      case 2:
        context.go('/decision-lab');
        break;
      case 3:
        context.go('/community');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
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
          selectedFontSize: 10.5,
          unselectedFontSize: 10.5,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10.5),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Price Lab',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: 'Community',
            ),
          ],
        ),
      ),
    );
  }
}
