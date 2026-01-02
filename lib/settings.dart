import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/settings/cash_modes.dart';
import 'package:selldroid/settings/configure.dart';
import 'package:selldroid/settings/expense_categories.dart';
import 'package:selldroid/settings/addcustomer.dart';
import 'package:selldroid/settings/addstockitem.dart';
import 'package:selldroid/settings/edit_shop_details.dart';
import 'package:selldroid/gst_stock_settings.dart';
import 'package:selldroid/settings/gst_settings.dart';
import 'package:selldroid/settings/purchaser_info_list.dart';
import 'package:selldroid/shop_setup.dart';
import 'package:sqflite/sqflite.dart';

// import 'add_stock_screen.dart';       // Create this later
// import 'manage_cash_modes.dart';      // Create this later
// import 'manage_customers.dart';       // Create this later
// import 'manage_purchasers.dart';      // Create this later
// import 'manage_expense_types.dart';   // Create this later

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Color Palette
  static const Color bgColor = Color(0xFFE8ECEF);
  static const Color primaryText = Color(0xFF46494C);
  static const Color secondaryText = Color(0xFF757575);
  static const Color cardColor = Colors.white;
  static const Color accentColor = Color(0xFF2585A1);
  static const Color destructiveColor = Color(0xFFEF5350);

  // --- Logic: Reset Bill Number ---
  Future<void> _resetBillNumber(BuildContext context) async {
    // Show Warning Dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Bill Counter?"),
        content: const Text(
          "This will reset your invoice numbering back to #1 and it will delete all sales.\n\n"
          "Are you sure you want to do this?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Reset",
              style: TextStyle(color: destructiveColor),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Logic to delete from sqlite_sequence or reset your counter variable
      await DatabaseHelper.instance
          .resetBillNumber(); // You'll need to add this method to DB Helper
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Bill Number Reset to 1")));
      }
    }
  }

  void showBackupSuccessDialog(BuildContext context, String path) {
    // Define your theme colors based on the file provided
    final Color colPrimary = const Color.fromARGB(255, 25, 133, 161); // #1985A1
    final Color colTextDark = const Color.fromARGB(255, 70, 73, 76); // #46494C
    final Color colTextLight = const Color.fromARGB(255, 120, 120, 120);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Modern rounded corners
          ),
          elevation: 0,
          backgroundColor:
              Colors.transparent, // Transparent to handle custom container
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Wrap content
              children: [
                // --- 1. Success Icon ---
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: colPrimary.withOpacity(
                      0.1,
                    ), // Soft background circle
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 50,
                      color: colPrimary, // Your primary teal color
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- 2. Title ---
                Text(
                  "Backup Successful!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colTextDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // --- 3. Description Message ---
                Text(
                  "Your data has been securely saved to your\n" + path,
                  style: TextStyle(
                    fontSize: 15,
                    color: colTextLight,
                    height: 1.5, // Better line spacing for readability
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // --- 4. OK Button ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colPrimary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: colPrimary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                    },
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          "Settings",
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: SHOP & CONFIGURATION ---
            _buildSectionHeader("GENERAL"),
            _buildSettingsGroup([
              _buildTile(
                icon: Icons.storefront,
                title: "Edit Shop Details",
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const EditShopDetailsScreen(),
                    ),
                  );
                },
              ),
              _buildTile(
                icon: Icons.tune,
                title: "Configure (Printer & Currency)",
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const ConfigurePage()),
                  );
                },
              ),
              _buildTile(
                icon: Icons.monetization_on,
                title: "GST Settings",
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const GstSettingsScreen(),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 24),

            // --- SECTION 2: MASTER DATA ---
            _buildSectionHeader("MASTER DATA"),
            _buildSettingsGroup([
              _buildTile(
                icon: Icons.inventory_2,
                title: "Add Stock Item",
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const AddStockScreen()),
                  );
                },
              ),
              _buildTile(
                icon: Icons.people,
                title: "Customer Names",
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const ManageCustomersScreen(),
                    ),
                  );
                },
              ),
              _buildTile(
                icon: Icons.local_shipping,
                title: "Suppliers List",
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const PurchasersListScreen(),
                    ),
                  );
                },
              ),
              _buildTile(
                icon: Icons.category,
                title: "Expense Categories",
                color: Colors.pink,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const ExpenseCategoriesScreen(),
                    ),
                  );
                },
              ),
              _buildTile(
                icon: Icons.payments,
                title: "Cash Modes",
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const CashModesScreen()),
                  );
                },
              ),
            ]),

            const SizedBox(height: 24),

            // --- SECTION 3: SYSTEM ACTIONS ---
            _buildSectionHeader("SYSTEM"),
            _buildSettingsGroup([
              _buildTile(
                icon: Icons.cloud_upload,
                title: "Export Data",
                color: Colors.blue,

                onTap: () async {
                  String filename =
                      "SellDroid${DateTime.now().toIso8601String().substring(0, 10)}.db";
                  File f = File(
                    join((await getDatabasesPath()), "SellDroid.db"),
                  );
                  FilePicker.platform
                      .saveFile(bytes: f.readAsBytesSync(), fileName: filename)
                      .then((val) {
                        if (val != null) showBackupSuccessDialog(context, val);
                      });
                  /*     copyFileIntoDownloadFolder(
                    join((await getDatabasesPath()), "SellDroid.db"),
                    filename,
                    desiredExtension: "db",
                  ).then((val) {
                    showBackupSuccessDialog(context);
                  }); */
                },
              ),

              _buildTile(
                icon: Icons.restart_alt,
                title: "Reset Bill Number",
                color: destructiveColor,
                isDestructive: true,
                onTap: () => _resetBillNumber(context),
              ),
            ]),

            const SizedBox(height: 40),

            // App Version Footer
            const Center(
              child: Text(
                "Version 1.0.0",
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: secondaryText,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget child = entry.value;
          // Add separator line between items, but not after the last one
          if (idx < children.length - 1) {
            return Column(
              children: [
                child,
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 56,
                  color: Colors.grey[100],
                ),
              ],
            );
          }
          return child;
        }).toList(),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDestructive ? destructiveColor : primaryText,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Color(0xFFBDBDBD),
      ),
    );
  }
}
