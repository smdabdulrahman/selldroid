import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/gst_stock_settings.dart';
import 'package:selldroid/home.dart';
import 'package:selldroid/theme_provider.dart';
import 'package:sqflite/sqflite.dart';

class SellDroidWelcomeScreen extends StatelessWidget {
  const SellDroidWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // 1. Hero Illustration (Mockup constructed with widgets)
              // Replace this specific widget with: Image.asset('assets/your_image.png')
              const _HeroIllustrationPlaceholder(),

              const Spacer(flex: 1),

              // 2. Title & Subtitle
              Text(
                "Welcome to\nSell Droid",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "The smartest way to manage your sales\nand invoices.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.secondaryText,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 2),

              // 3. Action Buttons
              _buildActionCard(
                context,
                title: "Import Backup",
                subtitle: "Restore business data",
                icon: Icons.cloud_download_outlined,
                color: theme.accentColor,
                onTap: () async {
                  debugPrint("Import Backup Tapped");
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(allowMultiple: false);
                  if (result != null) {
                    File file = File(result.files.single.path!);
                    debugPrint(file.path);
                    String path = join(
                      await getDatabasesPath(),
                      "SellDroid.db",
                    );
                    file.copy(path).then((val) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return HomeScreen();
                          },
                        ),
                      );
                    });
                  } else {
                    // User canceled the picker
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                context,
                title: "Start Fresh",
                subtitle: "Set up a new store",
                icon: Icons.storefront_outlined,
                color: const Color(0xFF4C5C68),
                onTap: () {
                  debugPrint("Start Fresh Tapped");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (builder) {
                        return GstStockSettingsScreen();
                      },
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              // 4. Footer
              Text(
                "TERMS & PRIVACY POLICY",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 16.0,
            ),
            child: Row(
              children: [
                // Icon Circle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// This is a mockup widget to mimic the 3D illustration in your image.
// In a real app, you would delete this class and just use Image.asset().
class _HeroIllustrationPlaceholder extends StatelessWidget {
  const _HeroIllustrationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main "Paper"
          Transform.rotate(
            angle: -0.1,
            child: Container(
              width: 160,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 60,
                    color: Colors.blueGrey[100],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 8,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Floating Icon Top Right
          Positioned(
            top: 0,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.calculate, color: Color(0xFF2585A1)),
            ),
          ),
          // Floating Icon Bottom Left
          Positioned(
            bottom: 20,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.receipt, color: Color(0xFF4C5C68)),
            ),
          ),
        ],
      ),
    );
  }
}
