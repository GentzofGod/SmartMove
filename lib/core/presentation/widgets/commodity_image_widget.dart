import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CommodityImageWidget extends StatelessWidget {
  final String commodityName;
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final BoxFit fit;

  const CommodityImageWidget({
    super.key,
    required this.commodityName,
    this.imageUrl,
    this.size = 52,
    this.borderRadius = 14,
    this.fit = BoxFit.cover,
  });

  static String? resolveCuratedImageUrl(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rice')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('bean')) {
      return 'https://images.unsplash.com/photo-1551462147-37885acc36f1?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('garri') || lower.contains('cassava') || lower.contains('elubo')) {
      return 'https://images.unsplash.com/photo-1590779033100-9f60a05a013d?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('palm oil') || lower.contains('epo pupa')) {
      return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('oil') || lower.contains('groundnut oil') || lower.contains('vegetable oil')) {
      return 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('yam') || lower.contains('potato') || lower.contains('tuber')) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('tomato') || lower.contains('pepper') || lower.contains('ata')) {
      return 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('onion')) {
      return 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('egg')) {
      return 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('fish') || lower.contains('titus') || lower.contains('panla') || lower.contains('sardine')) {
      return 'https://images.unsplash.com/photo-1534948216015-843149f72be3?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('chicken') || lower.contains('meat') || lower.contains('beef') || lower.contains('goat')) {
      return 'https://images.unsplash.com/photo-1587593810167-a84920ea0781?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('cooker') || lower.contains('stove')) {
      return 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('blender')) {
      return 'https://images.unsplash.com/photo-1570222094114-d054a817e56b?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('cement')) {
      return 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=400&q=80';
    }
    return null;
  }

  IconData _resolveIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rice') || lower.contains('bean') || lower.contains('grain') || lower.contains('garri')) {
      return Icons.grain_rounded;
    }
    if (lower.contains('oil')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('yam') || lower.contains('tomato') || lower.contains('pepper') || lower.contains('onion') || lower.contains('produce')) {
      return Icons.eco_rounded;
    }
    if (lower.contains('fish') || lower.contains('meat') || lower.contains('chicken') || lower.contains('egg')) {
      return Icons.set_meal_rounded;
    }
    if (lower.contains('cooker') || lower.contains('blender') || lower.contains('microwave') || lower.contains('fan') || lower.contains('electronics')) {
      return Icons.kitchen_rounded;
    }
    if (lower.contains('cement') || lower.contains('hardware') || lower.contains('paint')) {
      return Icons.build_rounded;
    }
    return Icons.shopping_basket_rounded;
  }

  Color _resolveBgColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rice') || lower.contains('garri')) {
      return const Color(0xFFFFF8E1);
    }
    if (lower.contains('bean') || lower.contains('yam')) {
      return const Color(0xFFEFEBE9);
    }
    if (lower.contains('oil')) {
      return const Color(0xFFFFF3E0);
    }
    if (lower.contains('tomato') || lower.contains('pepper') || lower.contains('meat')) {
      return const Color(0xFFFFEBEE);
    }
    if (lower.contains('fish')) {
      return const Color(0xFFE1F5FE);
    }
    if (lower.contains('cooker') || lower.contains('blender') || lower.contains('electronics')) {
      return const Color(0xFFEDE7F6);
    }
    return AppColors.primaryTint;
  }

  Color _resolveIconColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rice') || lower.contains('garri')) {
      return const Color(0xFFF57F17);
    }
    if (lower.contains('bean') || lower.contains('yam')) {
      return const Color(0xFF6D4C41);
    }
    if (lower.contains('oil')) {
      return const Color(0xFFE65100);
    }
    if (lower.contains('tomato') || lower.contains('pepper') || lower.contains('meat')) {
      return const Color(0xFFC62828);
    }
    if (lower.contains('fish')) {
      return const Color(0xFF0277BD);
    }
    if (lower.contains('cooker') || lower.contains('blender') || lower.contains('electronics')) {
      return const Color(0xFF512DA8);
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = (imageUrl != null && imageUrl!.trim().isNotEmpty)
        ? imageUrl!.trim()
        : resolveCuratedImageUrl(commodityName);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: effectiveUrl != null
            ? Image.network(
                effectiveUrl,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildFallbackIcon();
                },
              )
            : _buildFallbackIcon(),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    final bg = _resolveBgColor(commodityName);
    final iconColor = _resolveIconColor(commodityName);
    final iconData = _resolveIcon(commodityName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: iconColor,
          size: size * 0.5,
        ),
      ),
    );
  }
}

