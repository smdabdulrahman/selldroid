import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/home.dart';
import 'package:selldroid/theme_provider.dart';
// import 'package:selldroid/home_page.dart'; // UNCOMMENT THIS

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    final List<Widget> pages = [
      _buildWelcomePage(theme),
      _buildPrinterSetupPage(theme),
      _buildInventoryCyclePage(theme), // FIXED: Compact Boxes
      _buildQuickSalePage(theme),
      _buildReadyPage(theme),
    ];

    return Scaffold(
      backgroundColor: theme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. TOP NAV (SKIP) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < pages.length - 1)
                    TextButton(
                      onPressed: _finishOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.secondaryText,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text(
                        "SKIP",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // --- 2. MAIN CONTENT ---
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                physics: const BouncingScrollPhysics(),
                children: pages,
              ),
            ),

            // --- 3. BOTTOM CONTROLS ---
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  // Smooth Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pages.length, (index) {
                      bool isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 32 : 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.accentColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Modern Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == pages.length - 1) {
                          _finishOnboarding();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutQuint,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == pages.length - 1
                            ? "GET STARTED"
                            : "CONTINUE",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PAGE 1: WELCOME
  // ===========================================================================
  Widget _buildWelcomePage(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            "Selldroid",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "The complete mobile billing solution.\nGST, Stock, and Expenses in your pocket.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAGE 2: PRINTER SETUP
  // ===========================================================================
  Widget _buildPrinterSetupPage(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBigTitle(theme, "Connect\nYour Printer"),
          const SizedBox(height: 30),

          _buildActionTile(
            theme,
            step: "1",
            title: "Go to Settings",
            subtitle: "Navigate to the Configure page",
            icon: Icons.settings_rounded,
          ),
          _buildConnector(theme),
          _buildActionTile(
            theme,
            step: "2",
            title: "Scan & Pair",
            subtitle: "Select your Bluetooth thermal printer",
            icon: Icons.bluetooth_searching_rounded,
          ),
          _buildConnector(theme),
          _buildActionTile(
            theme,
            step: "3",
            title: "Select Size",
            subtitle: "Choose 2-inch or 3-inch paper",
            icon: Icons.receipt_long_rounded,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAGE 3: THE INVENTORY CYCLE (FIXED: Compact Boxes)
  // ===========================================================================
  Widget _buildInventoryCyclePage(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _buildBigTitle(theme, "Master Your\nInventory"),
          const SizedBox(height: 8),
          Text(
            "The 3-step cycle to manage stock:",
            style: TextStyle(color: theme.secondaryText, fontSize: 16),
          ),

          // Using Expanded + Column with Center alignment to avoid stretching
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Centers the group vertically
              children: [
                // STEP 1
                _buildCycleCard(
                  theme,
                  color: Colors.blue.shade50,
                  iconColor: Colors.blue,
                  icon: Icons.edit_note_rounded,
                  title: "1. Add Item",
                  subtitle: "Settings > Stock Items",
                  desc: "Create the product first (Name & Price).",
                ),

                _buildCompactArrow(theme),

                // STEP 2
                _buildCycleCard(
                  theme,
                  color: Colors.orange.shade50,
                  iconColor: Colors.orange,
                  icon: Icons.local_shipping_rounded,
                  title: "2. Purchase Stock",
                  subtitle: "Home > Purchase",
                  desc: "Select Supplier & Add Quantity.",
                ),

                _buildCompactArrow(theme),

                // STEP 3
                _buildCycleCard(
                  theme,
                  color: Colors.green.shade50,
                  iconColor: Colors.green,
                  icon: Icons.point_of_sale_rounded,
                  title: "3. Make Sale",
                  subtitle: "Home > Make Bill > Stock Sale",
                  desc: "Sell items. Stock decreases auto.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAGE 4: QUICK SALE
  // ===========================================================================
  // ===========================================================================
  // PAGE 4: QUICK SALE (Updated Text)
  // ===========================================================================
  // PAGE 4: QUICK SALE (Refactored to Card Style)
  // ===========================================================================
  Widget _buildQuickSalePage(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _buildBigTitle(theme, "Instant\nBilling"),
          const SizedBox(height: 8),
          Text(
            "Bill fast without adding products first.",
            style: TextStyle(color: theme.secondaryText, fontSize: 16),
          ),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // STEP 1
                _buildCycleCard(
                  theme,
                  color: Colors.purple.shade50,
                  iconColor: Colors.purple,
                  icon: Icons.flash_on_rounded,
                  title: "1. Tap Quick Sale",
                  subtitle: "Skip Inventory",
                  desc: "Don't have time to add items? Just tap Quick Sale.",
                ),

                _buildCompactArrow(theme),

                // STEP 2
                _buildCycleCard(
                  theme,
                  color: Colors.blue.shade50,
                  iconColor: Colors.blue,
                  icon: Icons.keyboard_alt_rounded,
                  title: "2. Enter Amount",
                  subtitle: "Manual Entry",
                  desc: "Type the price and description directly.",
                ),

                _buildCompactArrow(theme),

                // STEP 3
                _buildCycleCard(
                  theme,
                  color: Colors.green.shade50,
                  iconColor: Colors.green,
                  icon: Icons.print_rounded,
                  title: "3. Print Instantly",
                  subtitle: "Done in seconds",
                  desc: "Hand over the receipt immediately.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAGE 5: READY
  // ===========================================================================
  Widget _buildReadyPage(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 100, color: theme.accentColor),
          const SizedBox(height: 40),
          Text(
            "You're Ready!",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Your data is stored locally and securely.\nLet's grow your business.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================

  void _finishOnboarding() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Widget _buildBigTitle(ThemeProvider theme, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: theme.primaryText,
        height: 1.1,
      ),
    );
  }

  Widget _buildActionTile(
    ThemeProvider theme, {
    required String step,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(left: 32),
      height: 20,
      width: 2,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildCompactArrow(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8.0,
        ), // Added breathing room
        child: Icon(
          Icons.arrow_downward_rounded,
          color: Colors.grey.shade300,
          size: 18,
        ),
      ),
    );
  }

  // --- Compact Card for Inventory Cycle ---
  Widget _buildCycleCard(
    ThemeProvider theme, {
    required Color color,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 16,
      ), // REDUCED PADDING for smaller size
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        // Removed heavy shadow to make it feel lighter/smaller
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.secondaryText.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.secondaryText,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStep(ThemeProvider theme, String text) {
    return Row(
      children: [
        Icon(Icons.check_circle_outline_rounded, color: theme.accentColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}
