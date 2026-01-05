import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // --- A. Define Defaults (Single Source of Truth) ---
  static const Color defaultBgColor = Color(0xFFE8ECEF);
  static const Color defaultPrimaryText = Color(0xFF46494C);
  static const Color defaultSecondaryText = Color(0xFF757575);
  static const Color defaultAccentColor = Color(0xFF2585A1);
  static const Color defaultCardColor = Colors.white;

  // --- 1. Current Colors (Initialize with defaults) ---
  Color _bgColor = defaultBgColor;
  Color _primaryText = defaultPrimaryText;
  Color _secondaryText = defaultSecondaryText;
  Color _accentColor = defaultAccentColor;
  Color _cardColor = defaultCardColor;

  // --- 2. Getters ---
  Color get bgColor => _bgColor;
  Color get primaryText => _primaryText;
  Color get secondaryText => _secondaryText;
  Color get accentColor => _accentColor;
  Color get cardColor => _cardColor;

  // --- 3. SAVE Method ---
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bgColor', _bgColor.value);
    await prefs.setInt('primaryText', _primaryText.value);
    await prefs.setInt('secondaryText', _secondaryText.value);
    await prefs.setInt('accentColor', _accentColor.value);
    await prefs.setInt('cardColor', _cardColor.value);
  }

  // --- 4. LOAD Method ---
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _bgColor = Color(prefs.getInt('bgColor') ?? defaultBgColor.value);
    _primaryText = Color(
      prefs.getInt('primaryText') ?? defaultPrimaryText.value,
    );
    _secondaryText = Color(
      prefs.getInt('secondaryText') ?? defaultSecondaryText.value,
    );
    _accentColor = Color(
      prefs.getInt('accentColor') ?? defaultAccentColor.value,
    );
    _cardColor = Color(prefs.getInt('cardColor') ?? defaultCardColor.value);
    notifyListeners();
  }

  // --- 5. UPDATE Method ---
  void updateTheme({
    Color? newBgColor,
    Color? newPrimaryText,
    Color? newSecondaryText,
    Color? newAccentColor,
    Color? newCardColor,
  }) {
    if (newBgColor != null) _bgColor = newBgColor;
    if (newPrimaryText != null) _primaryText = newPrimaryText;
    if (newSecondaryText != null) _secondaryText = newSecondaryText;
    if (newAccentColor != null) _accentColor = newAccentColor;
    if (newCardColor != null) _cardColor = newCardColor;

    notifyListeners();
    _saveToPrefs();
  }

  // --- 6. RESET Method (Corrected) ---
  Future<void> resetTheme() async {
    // 1. Revert internal variables to the Defaults defined at the top
    _bgColor = defaultBgColor;
    _primaryText = defaultPrimaryText;
    _secondaryText = defaultSecondaryText;
    _accentColor = defaultAccentColor;
    _cardColor = defaultCardColor;

    notifyListeners(); // Update UI immediately

    // 2. Remove specific keys from storage (Safer than clear())
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bgColor');
    await prefs.remove('primaryText');
    await prefs.remove('secondaryText');
    await prefs.remove('accentColor');
    await prefs.remove('cardColor');
  }
}
