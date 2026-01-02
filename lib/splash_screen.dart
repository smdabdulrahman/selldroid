import 'package:flutter/material.dart';
import 'package:selldroid/gst_stock_settings.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/home.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/welcome_screen.dart';

// Import your destination screens

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Setup a smooth progress animation
    _controller = AnimationController(
      duration: const Duration(seconds: 3), // Duration of the fake load
      vsync: this,
    )..forward();
    print("he");
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    // Run the Logic Check
    _checkUserStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    // 1. Wait for animation + DB query
    // We run them in parallel but ensure we wait at least 2 seconds for the visual effect
    final minWait = Future.delayed(const Duration(seconds: 3));
    final dbQuery = await DatabaseHelper.instance.getShopDetails();

    await minWait; // Ensure logo stays for at least 2 secs

    try {
      ShopDetails shop = dbQuery;

      // 2. Decide where to go
      if (!mounted) return;

      // If phone number is empty (default), treat as New User
      if (shop.phoneNumber.isEmpty) {
        _navigateTo(const SellDroidWelcomeScreen());
      } else {
        _navigateTo(const HomeScreen());
      }
    } catch (e) {
      // Fallback: Go to Setup if DB fails
      if (mounted) _navigateTo(const SellDroidWelcomeScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // A subtle fade transition
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colors from your palette
    const Color bgColor = Color(0xFFE8ECEF);
    const Color titleColor = Color(0xFF46494C);
    const Color accentColor = Color(0xFF2585A1); // Cerulean Teal
    const Color trackColor = Color(
      0xFFD1D9DE,
    ); // Slightly darker grey for track

    return Scaffold(
      backgroundColor: bgColor,
      body: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(), // Pushes content to visual center
            // 1. Title Text
            const Text(
              "SellDroid",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold, // Thick, bold font
                color: titleColor,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 40),

            // 2. Custom Progress Bar (Matches the design)
            SizedBox(
              width: 140, // Fixed width like the screenshot
              height: 6, // Thickness of the bar
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _animation.value, // Connects to controller
                      backgroundColor: trackColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        accentColor,
                      ),
                    ),
                  );
                },
              ),
            ),

            const Spacer(), // Pushes footer to bottom
            // 3. Footer Text
            Text(
              "INITIALIZING SECURE ENVIRONMENT",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.withOpacity(0.7),
                letterSpacing: 1.5, // Wide spacing for professional look
              ),
            ),
            const SizedBox(height: 50), // Bottom padding
          ],
        ),
      ),
    );
  }
}
