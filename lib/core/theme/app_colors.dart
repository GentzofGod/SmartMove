import 'package:flutter/material.dart';

/// Central design tokens and color palette for SmartMove
/// Matches the master UI design board: Emerald green primary, deep forest accents,
/// clean light background, and semantic status badges.
class AppColors {
  // Brand Primary Greens
  static const Color primary = Color(0xFF00875A); // Emerald green for CTAs & key accents
  static const Color primaryDark = Color(0xFF073B29); // Deep forest green for splash & headers
  static const Color primaryLight = Color(0xFF0E794D);
  static const Color primaryTint = Color(0xFFE3FCEF); // Soft mint for badges & active states

  // Neutral Background & Surfaces
  static const Color background = Color(0xFFF8F9FA); // Clean off-white surface
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFE8ECE9);
  static const Color divider = Color(0xFFEFF2F0);

  // Text Colors
  static const Color textPrimary = Color(0xFF172B4D); // Deep navy charcoal
  static const Color textSecondary = Color(0xFF5E6C84); // Slate gray for captions
  static const Color textTertiary = Color(0xFF97A0AF); // Muted hint

  // Semantic Status Badges
  static const Color successBg = Color(0xFFE3FCEF);
  static const Color successText = Color(0xFF006644);

  static const Color warningBg = Color(0xFFFFFAE6);
  static const Color warningText = Color(0xFFFF8B00);

  static const Color infoBg = Color(0xFFDEEBFF);
  static const Color infoText = Color(0xFF0052CC);

  static const Color errorBg = Color(0xFFFFEBE6);
  static const Color errorText = Color(0xFFDE350B);

  // Accent Tints
  static const Color amber = Color(0xFFFFAB00);
  static const Color blue = Color(0xFF0052CC);
}
