import 'package:flutter/material.dart';

/// Single source of truth for every colour in the app.
/// Import this file — never hardcode a Color() anywhere else.
class AppColors {
  AppColors._(); // Prevent instantiation

  // ── Primary ──
  static const Color primary = Color(0xFF14528C);          // Dark blue
  static const Color primaryDark = Color(0xFF0E3A63);      // Pressed / deeper state
  static const Color primaryLight = Color(0xFF1A6AB0);     // Lighter variant

  // ── Accents ──
  static const Color accentTeal = Color(0xFFCDD9D5);       // Light teal
  static const Color accentCream = Color(0xFFF0E4C4);      // Cream
  static const Color accentPink = Color(0xFFE91E8C);       // Pink (spec: "Enter Manually")

  // ── Surfaces ──
  static const Color surface = Color(0xFFFFFFFF);          // Cards, modals
  static const Color background = Color(0xFFF8FAFC);       // Page background
  static const Color border = Color(0xFFE2E8F0);           // Dividers, card borders

  // ── Text ──
  static const Color textPrimary = Color(0xFF1E2833);      // Near-black headings & body
  static const Color textSecondary = Color(0xFF5A6670);    // Subtitles, placeholders
  static const Color textOnPrimary = Color(0xFFFFFFFF);    // White text on dark blue
  static const Color textOnPrimaryMuted = Color(0xFFB8CAD9); // Muted text on dark blue

  // ── Semantic ──
  static const Color success = Color(0xFF2E7D32);          // Green confirmations
  static const Color error = Color(0xFFD32F2F);            // Errors, destructive actions
  static const Color warning = Color(0xFFF9A825);          // Warnings, caution
}
