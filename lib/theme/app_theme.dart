import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF08A66E);
  static const Color amber = Color(0xFFE69500);
  static const Color bg = Color(0xFFF4F3EA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color text = Color(0xFF0F172A);
  static const Color mutedText = Color(0xFF64748B);
}

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.tajawalTextTheme(base.textTheme).copyWith(
    headlineLarge: GoogleFonts.manrope(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    ),
    headlineMedium: GoogleFonts.manrope(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    ),
    titleLarge: GoogleFonts.manrope(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    titleSmall: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    bodyLarge: GoogleFonts.tajawal(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.text,
    ),
    bodyMedium: GoogleFonts.tajawal(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.text,
    ),
    bodySmall: GoogleFonts.tajawal(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.mutedText,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.amber,
      surface: AppColors.surface,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F8FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: textTheme.bodySmall,
    ),
  );
}