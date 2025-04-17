// lib/utils/text_styles.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Example: Using Google Fonts
import 'package:sizer/sizer.dart'; // Assuming you use sizer for responsive fonts
import 'package:mama_care/utils/app_colors.dart'; // Assuming you have AppColors

/// Centralized TextStyles for the MamaCare App.
/// Uses GoogleFonts (example) and Sizer for responsiveness.
class TextStyles {
  // Private constructor to prevent instantiation
  const TextStyles._();

  // --- Define Base Font Family ---
  // Choose your primary font. Ensure it's added to pubspec.yaml and assets/fonts if needed.
  // static final String _primaryFontFamily = GoogleFonts.lato().fontFamily ?? 'Roboto';
  static final String _primaryFontFamily = GoogleFonts.poppins().fontFamily ?? 'Roboto'; // Example with Poppins

  // --- Headline Styles ---

  /// Large headline, e.g., for major screen titles.
  static final TextStyle headline1 = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 24.sp, // Responsive size
    fontWeight: FontWeight.bold,
    color: AppColors.textDark, // Use theme color
  );

  /// Medium headline, e.g., for section titles.
  static final TextStyle headline2 = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 20.sp,
    fontWeight: FontWeight.w600, // Semi-bold
    color: AppColors.textDark,
  );

  // --- Title Styles ---

  /// Standard title style, e.g., AppBar titles, card titles.
  static final TextStyle title = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Title style specifically for cards.
  static final TextStyle titleCard = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 15.sp, // Slightly smaller for cards
    fontWeight: FontWeight.bold,
    color: AppColors.primary, // Example: Use primary color
  );

  /// White title for use on dark backgrounds.
  static final TextStyle titleWhite = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: Colors.white, // White color
  );

  // --- Body Text Styles ---

  /// Standard body text.
  static final TextStyle body = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 13.sp,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
    height: 1.5, // Line height for readability
  );

    /// Slightly bolder body text.
  static final TextStyle bodyBold = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 13.sp,
    fontWeight: FontWeight.w600, // Semi-bold
    color: AppColors.textDark,
    height: 1.5,
  );


  /// Body text with a standard dark color (explicit).
  static final TextStyle bodyBlack = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 13.sp,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark, // Explicit dark color
    height: 1.5,
  );

  /// Body text with a grey color for secondary information.
  static final TextStyle bodyGrey = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 13.sp,
    fontWeight: FontWeight.normal,
    color: AppColors.textGrey, // Use theme grey color
    height: 1.5,
  );

   /// White body text for use on dark backgrounds.
  static final TextStyle bodyWhite = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 13.sp,
    fontWeight: FontWeight.normal,
    color: Colors.white.withOpacity(0.9), // Slightly off-white
    height: 1.5,
  );

  // --- Smaller Text Styles ---

  /// Small text, often used for captions or metadata.
  static final TextStyle small = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 11.sp,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
  );

  /// Small text in grey color.
  static final TextStyle smallGrey = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 11.sp,
    fontWeight: FontWeight.normal,
    color: AppColors.textGrey,
  );

   /// Small text in primary color.
  static final TextStyle smallPrimary = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 11.sp,
    fontWeight: FontWeight.w500, // Medium weight
    color: AppColors.primary,
  );

  // --- Button and Link Styles ---

  /// Style for text inside primary buttons.
  static final TextStyle buttonText = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 14.sp,
    fontWeight: FontWeight.bold,
    color: Colors.white, // Assuming buttons have dark background
  );

  /// Style for text links.
  static final TextStyle linkText = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 13.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.primary, // Use primary color for links
    // decoration: TextDecoration.underline, // Optional: Underline links
  );

  // --- Specific Styles Used in Previous Examples ---

   /// Style for labels above TextFields.
  static final TextStyle textFieldLabel = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 12.sp,
    fontWeight: FontWeight.w500, // Medium weight
    color: AppColors.primary, // Example: Use primary color
  );


  // --- Add other specific styles as needed ---
  // Example: Error text style
  static final TextStyle errorText = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 11.sp,
    fontWeight: FontWeight.normal,
    color: AppColors.error, // Use theme error color
  );

}