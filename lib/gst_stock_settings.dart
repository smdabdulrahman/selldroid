import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/shop_setup.dart';
import 'package:selldroid/theme_provider.dart';

import '../models/preference_model.dart';

class GstStockSettingsScreen extends StatefulWidget {
  const GstStockSettingsScreen({super.key});

  @override
  State<GstStockSettingsScreen> createState() => _GstStockSettingsScreenState();
}

enum TaxType { inclusive, exclusive }

class _GstStockSettingsScreenState extends State<GstStockSettingsScreen> {
  // State variables
  bool _isGstEnabled = true; // Main Toggle: GST vs Non-GST
  TaxType _selectedTaxType = TaxType.inclusive; // Inclusive vs Exclusive
  bool _maintainStock = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 1. Load Data from the new 'preferences' table
  Future<void> _loadSettings() async {
    try {
      PreferenceModel prefs = await DatabaseHelper.instance.getPreferences();
      setState(() {
        _isGstEnabled = prefs.includeGst;
        _selectedTaxType = prefs.isGstInclusive
            ? TaxType.inclusive
            : TaxType.exclusive;
        _maintainStock = prefs.manageStock;
      });
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
  }

  // 2. Save Data to the new 'preferences' table
  Future<void> _saveAndContinue() async {
    PreferenceModel prefs = PreferenceModel(
      // We always use ID 1 for the main settings
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

      // Navigate to Home Dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ShopSetupScreen()),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.bgColor,
      appBar: AppBar(
        backgroundColor: theme.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.primaryText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "GST & Stock Settings",
          style: TextStyle(
            color: theme.primaryText,
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
                  color: theme.secondaryText,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // --- SECTION 1: GST MODE ---
              _buildSectionHeader("TAX SETTINGS", theme),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
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
                      activeColor: theme.accentColor,
                      title: Text(
                        "Enable GST",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText,
                        ),
                      ),
                      subtitle: Text(
                        _isGstEnabled
                            ? "GST Mode Active"
                            : "Non-GST Mode (No Tax)",
                        style: TextStyle(
                          color: theme.secondaryText,
                          fontSize: 13,
                        ),
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
                        theme: theme,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildRadioTile(
                        theme: theme,
                        title: "Exclusive",
                        subtitle: "Tax added on top of price",
                        value: TaxType.exclusive,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- SECTION 2: INVENTORY ---
              _buildSectionHeader("INVENTORY MANAGEMENT", theme),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  activeColor: theme.accentColor,
                  title: Text(
                    "Maintain Stock",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                  subtitle: Text(
                    "Track product quantities",
                    style: TextStyle(color: theme.secondaryText, fontSize: 13),
                  ),
                  value: _maintainStock,
                  onChanged: (val) {
                    setState(() => _maintainStock = val);
                  },
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
                    Icon(
                      Icons.info_outline,
                      color: theme.primaryText,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isGstEnabled
                            ? "GST bills will be generated."
                            : "Simple estimates (Non-GST) will be generated.",
                        style: TextStyle(
                          color: theme.primaryText.withOpacity(0.8),
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
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Save & Continue",
                    style: TextStyle(
                      color: Colors.white,
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
    );
  }

  Widget _buildSectionHeader(String title, ThemeProvider theme) {
    return Text(
      title,
      style: TextStyle(
        color: theme.secondaryText,
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
    required ThemeProvider theme,
  }) {
    return RadioListTile<TaxType>(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 0,
      ), // Compact
      activeColor: theme.accentColor,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.primaryText,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: theme.secondaryText, fontSize: 12),
      ),
      value: value,
      groupValue: _selectedTaxType,
      onChanged: (TaxType? newValue) {
        setState(() => _selectedTaxType = newValue!);
      },
    );
  }
}
