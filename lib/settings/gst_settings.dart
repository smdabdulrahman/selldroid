import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/shop_setup.dart'; // Assuming this import exists based on your code
import 'package:selldroid/theme_provider.dart';
import '../models/preference_model.dart';

class GstSettingsScreen extends StatefulWidget {
  const GstSettingsScreen({super.key});

  @override
  State<GstSettingsScreen> createState() => _GstSettingsScreenState();
}

enum TaxType { inclusive, exclusive }

class _GstSettingsScreenState extends State<GstSettingsScreen> {
  // State variables
  bool _isGstEnabled = true;
  TaxType _selectedTaxType = TaxType.inclusive;
  bool _maintainStock = false;

  // --- NEW: Original State Variables for comparison ---
  bool? _originalGstEnabled;
  TaxType? _originalTaxType;
  bool? _originalMaintainStock;
  bool _allowPop = false; // Controls the back button gate

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 1. Load Data
  Future<void> _loadSettings() async {
    try {
      PreferenceModel prefs = await DatabaseHelper.instance.getPreferences();
      setState(() {
        // Set Current Values
        _isGstEnabled = prefs.includeGst;
        _selectedTaxType = prefs.isGstInclusive
            ? TaxType.inclusive
            : TaxType.exclusive;
        _maintainStock = prefs.manageStock;

        // --- NEW: Set Original Values ---
        _originalGstEnabled = _isGstEnabled;
        _originalTaxType = _selectedTaxType;
        _originalMaintainStock = _maintainStock;
      });
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
  }

  // --- NEW: Check for Unsaved Changes ---
  bool _hasUnsavedChanges() {
    // If data hasn't loaded yet, assume no changes
    if (_originalGstEnabled == null) return false;

    if (_isGstEnabled != _originalGstEnabled) return true;
    if (_selectedTaxType != _originalTaxType) return true;
    if (_maintainStock != _originalMaintainStock) return true;

    return false;
  }

  // --- NEW: Handle Back Button Logic ---
  Future<void> _handlePopRequest() async {
    // If NO changes, allow exit immediately
    if (!_hasUnsavedChanges()) {
      setState(() => _allowPop = true);
      if (mounted) Navigator.pop(context);
      return;
    }

    // If changes exist, show Dialog
    final bool shouldDiscard =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text("Unsaved Changes"),
              ],
            ),
            content: Text(
              "You have unsaved settings. Do you want to discard them?",
              style: TextStyle(fontSize: 15, color: primaryText),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  "Keep Editing",
                  style: TextStyle(color: secondaryText),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Discard",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldDiscard) {
      setState(() => _allowPop = true);
      if (mounted) Navigator.pop(context);
    }
  }

  // 2. Save Data
  Future<void> _saveAndContinue() async {
    PreferenceModel prefs = PreferenceModel(
      id: 1,
      includeGst: _isGstEnabled,
      isGstInclusive: (_selectedTaxType == TaxType.inclusive),
      manageStock: _maintainStock,
    );

    await DatabaseHelper.instance.updatePreferences(prefs);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences Saved Successfully!')),
      );

      // --- NEW: Allow pop because we saved successfully ---
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  late Color bgColor;
  late Color primaryText;
  late Color secondaryText;
  late Color accentColor;
  late Color cardColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    bgColor = theme.bgColor;
    primaryText = theme.primaryText;
    secondaryText = theme.secondaryText;
    accentColor = theme.accentColor;
    cardColor = theme.cardColor;

    // --- NEW: Wrap Scaffold in PopScope ---
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePopRequest();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: primaryText, size: 20),
            // --- NEW: Trigger custom back logic ---
            onPressed: _handlePopRequest,
          ),
          title: Text(
            "GST Settings",
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Configure your tax mode (GST/Non-GST) and inventory preferences.",
                  style: TextStyle(
                    color: secondaryText,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // --- SECTION 1: GST MODE ---
                _buildSectionHeader("TAX SETTINGS"),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // A. Main Toggle (GST vs Non-GST)
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        activeColor: accentColor,
                        title: Text(
                          "Enable GST",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        subtitle: Text(
                          _isGstEnabled
                              ? "GST Mode Active"
                              : "Non-GST Mode (No Tax)",
                          style: TextStyle(color: secondaryText, fontSize: 13),
                        ),
                        value: _isGstEnabled,
                        onChanged: (val) {
                          setState(() => _isGstEnabled = val);
                        },
                      ),

                      // B. Tax Type (Only show if GST is Enabled)
                      if (_isGstEnabled) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildRadioTile(
                          title: "Inclusive",
                          subtitle: "Tax included in price",
                          value: TaxType.inclusive,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildRadioTile(
                          title: "Exclusive",
                          subtitle: "Tax added on top of price",
                          value: TaxType.exclusive,
                        ),
                      ],
                    ],
                  ),
                ),

                // --- SECTION 2: INVENTORY ---
                const SizedBox(height: 12),
                _buildSectionHeader("INVENTORY MANAGEMENT"),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    activeColor: accentColor,
                    title: Text(
                      "Maintain Stock",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                      ),
                    ),
                    subtitle: Text(
                      "Track product quantities",
                      style: TextStyle(color: secondaryText, fontSize: 13),
                    ),
                    value: _maintainStock,
                    // Disabled because of your requirement about app reinstall
                    onChanged: null,
                  ),
                ),

                const SizedBox(height: 24),

                // --- Warning ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "The 'Maintain Stock' preference can only be configured during the initial setup. To change it, you must reinstall the application.",
                          style: TextStyle(
                            color: primaryText.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // --- Continue Button ---
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    // --- NEW: Enable only if changes exist (Optional, but consistent) ---
                    onPressed: _hasUnsavedChanges() ? _saveAndContinue : null,
                    style: ElevatedButton.styleFrom(
                      // --- NEW: Visual feedback for enabled/disabled state ---
                      backgroundColor: _hasUnsavedChanges()
                          ? accentColor
                          : Colors.grey[300],
                      foregroundColor: _hasUnsavedChanges()
                          ? Colors.white
                          : Colors.grey[500],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Save Changes",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: secondaryText,
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required TaxType value,
  }) {
    return RadioListTile<TaxType>(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      activeColor: accentColor,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: primaryText,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: secondaryText, fontSize: 12),
      ),
      value: value,
      groupValue: _selectedTaxType,
      onChanged: (TaxType? newValue) {
        setState(() => _selectedTaxType = newValue!);
      },
    );
  }
}
