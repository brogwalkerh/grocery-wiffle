import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modern, fluid design system for GroceryCompare.
/// Inspired by iOS 18 and Material You with glass-morphism accents.
class ModernTheme {
  ModernTheme._();

  // ============================================================
  // BRAND COLORS
  // ============================================================
  
  // Primary palette - Fresh gradient greens
  static const Color mint = Color(0xFF34D399);      // Bright mint
  static const Color emerald = Color(0xFF10B981);   // Primary emerald
  static const Color teal = Color(0xFF0D9488);      // Deep teal
  
  // Accent colors
  static const Color coral = Color(0xFFF97316);     // Warm coral for sales
  static const Color sky = Color(0xFF0EA5E9);       // Sky blue for info
  static const Color violet = Color(0xFF8B5CF6);    // Violet for premium
  static const Color rose = Color(0xFFF43F5E);      // Rose for warnings
  
  // Neutral palette
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF4F4F5);
  static const Color gray200 = Color(0xFFE4E4E7);
  static const Color gray300 = Color(0xFFD4D4D8);
  static const Color gray400 = Color(0xFFA1A1AA);
  static const Color gray500 = Color(0xFF71717A);
  static const Color gray600 = Color(0xFF52525B);
  static const Color gray700 = Color(0xFF3F3F46);
  static const Color gray800 = Color(0xFF27272A);
  static const Color gray900 = Color(0xFF18181B);
  static const Color gray950 = Color(0xFF09090B);

  // ============================================================
  // SPACING SYSTEM (4px base)
  // ============================================================
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
  static const double space10 = 40.0;
  static const double space12 = 48.0;
  static const double space16 = 64.0;

  // ============================================================
  // BORDER RADIUS
  // ============================================================
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 24.0;
  static const double radius3xl = 32.0;
  static const double radiusFull = 9999.0;

  // ============================================================
  // SHADOWS
  // ============================================================
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowColored(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: color.withOpacity(0.15),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // ============================================================
  // GRADIENTS
  // ============================================================
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [mint, emerald, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get warmGradient => const LinearGradient(
    colors: [Color(0xFFFBBF24), coral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get coolGradient => const LinearGradient(
    colors: [sky, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get surfaceGradient => LinearGradient(
    colors: [gray50, gray100.withOpacity(0.5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================================
  // ANIMATION DURATIONS
  // ============================================================
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Duration durationSlower = Duration(milliseconds: 500);

  // ============================================================
  // ANIMATION CURVES
  // ============================================================
  static const Curve curveEase = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;

  // ============================================================
  // LIGHT THEME
  // ============================================================
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.light,
      primary: emerald,
      secondary: sky,
      tertiary: coral,
      surface: Colors.white,
      surfaceContainerLowest: gray50,
      surfaceContainerLow: gray100,
      surfaceContainer: gray200,
      surfaceContainerHigh: gray300,
      onSurface: gray900,
      onSurfaceVariant: gray600,
      outline: gray300,
      outlineVariant: gray200,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: gray50,
      
      // Typography
      textTheme: _buildTextTheme(colorScheme),
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: space6, vertical: space4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: gray100,
        contentPadding: const EdgeInsets.symmetric(horizontal: space4, vertical: space4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: emerald, width: 2),
        ),
        hintStyle: const TextStyle(
          color: gray400,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: gray600,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: gray500,
        suffixIconColor: gray500,
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: emerald,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: space6),
        extendedTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius2xl)),
        ),
        dragHandleColor: gray300,
        dragHandleSize: Size(40, 4),
        showDragHandle: true,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius2xl),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: gray900,
          letterSpacing: -0.3,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: gray100,
        selectedColor: emerald.withOpacity(0.15),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: space3, vertical: space2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        side: BorderSide.none,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: gray200,
        thickness: 1,
        space: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: gray900,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(space4),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: emerald,
      ),

      // Icon themes
      iconTheme: const IconThemeData(
        color: gray700,
        size: 24,
      ),
    );
  }

  // ============================================================
  // DARK THEME
  // ============================================================
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.dark,
      primary: mint,
      secondary: sky,
      tertiary: coral,
      surface: gray900,
      surfaceContainerLowest: gray950,
      surfaceContainerLow: gray900,
      surfaceContainer: gray800,
      surfaceContainerHigh: gray700,
      onSurface: gray50,
      onSurfaceVariant: gray400,
      outline: gray700,
      outlineVariant: gray800,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: gray950,
      
      textTheme: _buildTextTheme(colorScheme),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        color: gray900,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: space6, vertical: space4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          backgroundColor: mint,
          foregroundColor: gray950,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: gray800,
        contentPadding: const EdgeInsets.symmetric(horizontal: space4, vertical: space4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: mint, width: 2),
        ),
        hintStyle: const TextStyle(color: gray500),
        prefixIconColor: gray500,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: mint,
        foregroundColor: gray950,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: gray900,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius2xl)),
        ),
        dragHandleColor: gray700,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: gray900,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius2xl),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: gray800,
        selectedColor: mint.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: gray800,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: gray800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: mint,
      ),
    );
  }

  // ============================================================
  // TEXT THEME BUILDER
  // ============================================================
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      // Display styles - for hero numbers and large headings
      displayLarge: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -1.5,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -1.2,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.8,
        color: colorScheme.onSurface,
      ),
      
      // Headline styles - for section headers
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.4,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
        color: colorScheme.onSurface,
      ),
      
      // Title styles - for card titles
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.2,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.15,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.1,
        color: colorScheme.onSurface,
      ),
      
      // Body styles - for content
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: -0.1,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        letterSpacing: 0.1,
        color: colorScheme.onSurfaceVariant,
      ),
      
      // Label styles - for buttons and chips
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: 0,
        color: colorScheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.35,
        letterSpacing: 0.1,
        color: colorScheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.35,
        letterSpacing: 0.2,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ============================================================
// EXTENSION HELPERS
// ============================================================

extension ModernThemeContext on BuildContext {
  /// Quick access to theme colors
  ColorScheme get colors => Theme.of(this).colorScheme;
  
  /// Quick access to text styles
  TextTheme get textStyles => Theme.of(this).textTheme;
  
  /// Check if dark mode
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
