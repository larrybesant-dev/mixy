import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'text_styles.dart';

/// Mix & Mingle App Theme
/// Complete nightclub/social theme with vibrant energy
final ThemeData mixMingleTheme = ThemeData.dark().copyWith(
  // Color scheme
  colorScheme: const ColorScheme.dark(
    primary: ClubColors.primary,
    primaryContainer: ClubColors.primaryDark,
    secondary: ClubColors.secondary,
    secondaryContainer: ClubColors.secondaryDark,
    tertiary: ClubColors.accent,
    surface: ClubColors.surface,
    surfaceContainerHighest: ClubColors.cardBackground,
    onPrimary: ClubColors.onPrimary,
    onSecondary: ClubColors.onPrimary,
    onSurface: ClubColors.onSurface,
    error: ClubColors.error,
    onError: Colors.white,
  ),

  // Scaffold background
  scaffoldBackgroundColor: ClubColors.deepNavy,

  // Text theme
  textTheme: ClubTextStyles.textTheme,

  // App bar theme
  appBarTheme: const AppBarTheme(
    backgroundColor: ClubColors.deepNavy,
    foregroundColor: ClubColors.textPrimary,
    elevation: 0,
    shadowColor: Colors.transparent,
    centerTitle: true,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: ClubColors.textPrimary,
    ),
  ),

  // Card theme
  cardTheme: CardThemeData(
    color: ClubColors.cardBackground,
    shadowColor: ClubColors.primary.withValues(alpha: 0.2),
    elevation: 4,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: ClubColors.primary.withValues(alpha: 0.1),
        width: 1,
      ),
    ),
  ),

  // Button themes
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: ClubColors.primary,
      foregroundColor: ClubColors.onPrimary,
      disabledBackgroundColor: ClubColors.disabled,
      disabledForegroundColor: ClubColors.textHint,
      shadowColor: ClubColors.primary.withValues(alpha: 0.5),
      elevation: 8,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      minimumSize: const Size(120, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: ClubTextStyles.buttonText,
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ClubColors.primary,
      side: const BorderSide(color: ClubColors.primary, width: 2),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      minimumSize: const Size(120, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: ClubTextStyles.buttonText,
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ClubColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: ClubTextStyles.buttonText,
    ),
  ),

  // Input decoration theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: ClubColors.cardBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: ClubColors.primary.withValues(alpha: 0.3),
        width: 1,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: ClubColors.primary.withValues(alpha: 0.3),
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: ClubColors.primary,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: ClubColors.error,
        width: 1,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: ClubColors.error,
        width: 2,
      ),
    ),
    labelStyle: const TextStyle(
      color: ClubColors.textSecondary,
      fontSize: 14,
    ),
    hintStyle: const TextStyle(
      color: ClubColors.textHint,
      fontSize: 14,
    ),
    errorStyle: const TextStyle(
      color: ClubColors.error,
      fontSize: 12,
    ),
  ),

  // Dialog theme
  dialogTheme: DialogThemeData(
    backgroundColor: ClubColors.cardBackground,
    elevation: 24,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    titleTextStyle: ClubTextStyles.textTheme.titleLarge,
    contentTextStyle: ClubTextStyles.textTheme.bodyMedium,
  ),

  // Bottom sheet theme
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: ClubColors.cardBackground,
    modalBackgroundColor: ClubColors.cardBackground,
    elevation: 16,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  ),

  // Navigation bar theme
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: ClubColors.cardBackground,
    indicatorColor: ClubColors.primary,
    labelTextStyle: WidgetStateProperty.all(
      ClubTextStyles.textTheme.labelSmall,
    ),
  ),

  // Bottom navigation bar theme
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: ClubColors.cardBackground,
    selectedItemColor: ClubColors.primary,
    unselectedItemColor: ClubColors.textSecondary,
    selectedLabelStyle: ClubTextStyles.textTheme.labelSmall,
    unselectedLabelStyle: ClubTextStyles.textTheme.labelSmall,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),

  // Floating action button theme
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: ClubColors.primary,
    foregroundColor: ClubColors.onPrimary,
    elevation: 12,
    highlightElevation: 16,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),

  // Chip theme
  chipTheme: ChipThemeData(
    backgroundColor: ClubColors.cardBackground,
    selectedColor: ClubColors.primary,
    disabledColor: ClubColors.disabled,
    labelStyle: ClubTextStyles.textTheme.labelMedium!,
    secondaryLabelStyle: ClubTextStyles.textTheme.labelSmall!,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: ClubColors.primary.withValues(alpha: 0.3),
      ),
    ),
  ),

  // Progress indicator theme
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: ClubColors.primary,
    linearTrackColor: ClubColors.cardBackground,
    circularTrackColor: ClubColors.cardBackground,
  ),

  // Checkbox theme
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return ClubColors.primary;
      }
      return Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(ClubColors.onPrimary),
    side: const BorderSide(color: ClubColors.primary, width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
  ),

  // Radio theme
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return ClubColors.primary;
      }
      return ClubColors.textSecondary;
    }),
  ),

  // Switch theme
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return ClubColors.primary;
      }
      return ClubColors.textSecondary;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return ClubColors.primary.withValues(alpha: 0.5);
      }
      return ClubColors.cardBackground;
    }),
  ),

  // Slider theme
  sliderTheme: SliderThemeData(
    activeTrackColor: ClubColors.primary,
    inactiveTrackColor: ClubColors.cardBackground,
    thumbColor: ClubColors.primary,
    overlayColor: ClubColors.primary.withValues(alpha: 0.2),
    valueIndicatorColor: ClubColors.primary,
  ),

  // Divider theme
  dividerTheme: DividerThemeData(
    color: ClubColors.textHint.withValues(alpha: 0.2),
    thickness: 1,
    space: 16,
  ),

  // List tile theme
  listTileTheme: ListTileThemeData(
    textColor: ClubColors.textPrimary,
    iconColor: ClubColors.textPrimary,
    tileColor: Colors.transparent,
    selectedTileColor: ClubColors.primary.withValues(alpha: 0.1),
    selectedColor: ClubColors.primary,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),

  // Icon theme
  iconTheme: const IconThemeData(
    color: ClubColors.textPrimary,
    size: 24,
  ),

  // Snackbar theme
  snackBarTheme: SnackBarThemeData(
    backgroundColor: ClubColors.cardBackground,
    contentTextStyle: ClubTextStyles.textTheme.bodyMedium,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),

  // Tooltip theme
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: ClubColors.cardBackground,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: ClubColors.primary.withValues(alpha: 0.3),
      ),
    ),
    textStyle: ClubTextStyles.textTheme.bodySmall,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),

  // Banner theme
  bannerTheme: MaterialBannerThemeData(
    backgroundColor: ClubColors.cardBackground,
    contentTextStyle: ClubTextStyles.textTheme.bodyMedium,
  ),
);
