import 'package:flutter/material.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/shop_setup.dart';

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

  // Colors
  static const Color bgColor = Color(0xFFE8ECEF);
  static const Color primaryText = Color(0xFF46494C);
  static const Color secondaryText = Color(0xFF757575);
  static const Color accentColor = Color(0xFF2585A1); // Cerulean
  static const Color cardColor = Colors.white;

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: primaryText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "GST & Stock Settings",
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
              const Text(
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
                      title: const Text(
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
                        style: const TextStyle(
                          color: secondaryText,
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

              const SizedBox(height: 32),

              // --- SECTION 2: INVENTORY ---
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
                  title: const Text(
                    "Maintain Stock",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  subtitle: const Text(
                    "Track product quantities",
                    style: TextStyle(color: secondaryText, fontSize: 13),
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
                    const Icon(
                      Icons.info_outline,
                      color: primaryText,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isGstEnabled
                            ? "GST bills will be generated."
                            : "Simple estimates (Non-GST) will be generated.",
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
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 0,
      ), // Compact
      activeColor: accentColor,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: primaryText,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: secondaryText, fontSize: 12),
      ),
      value: value,
      groupValue: _selectedTaxType,
      onChanged: (TaxType? newValue) {
        setState(() => _selectedTaxType = newValue!);
      },
    );
  }
}
