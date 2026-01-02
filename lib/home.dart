import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // REQUIRED: Add intl to pubspec.yaml
import 'package:selldroid/quick_actions/expenses.dart';
import 'package:selldroid/quick_actions/payments_page.dart';
import 'package:selldroid/quick_actions/purchase_entry_page.dart';
import 'package:selldroid/quick_actions/report_page.dart';
import 'package:selldroid/settings/edit_shop_details.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/quick_actions/make_bill.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/settings.dart';
import 'package:selldroid/settings/expense_categories.dart';
// import 'purchase_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- Shop Info ---
  String _shopName = "Sell Droid";
  String? _logoPath;
  NumberFormat num_format = NumberFormat.decimalPattern("en_IN");
  // --- Dashboard Data ---
  bool _isLoading = true;
  double _todaySalesTotal = 0.0;
  int _todayOrdersCount = 0;
  String _currentDate = "";

  // --- Colors ---
  static const Color bgColor = Color(0xFFE8ECEF);
  static const Color primaryText = Color(0xFF46494C);
  static const Color secondaryText = Color(0xFF757575);
  static const Color accentColor = Color(0xFF2585A1);
  static const Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _setCurrentDate();
    _loadDashboardData();
  }

  void _setCurrentDate() {
    // Format: Weekday, Day Month (e.g., "Monday, 24 Oct")
    final now = DateTime.now();
    _currentDate = DateFormat('EEEE, d MMM').format(now);
  }

  // --- Load Data (Shop + Sales Stats) ---
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Get Shop Details
      ShopDetails shop = await DatabaseHelper.instance.getShopDetails();

      // 2. Get Today's Sales Data
      // We assume billed_date is stored as ISO8601 string (YYYY-MM-DDTHH:MM:SS)
      String todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // Query: Sum of final_amount where billed_date starts with today's date
      // NOTE: Using 'final_amount' and 'billed_date' to match your DB Schema
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT 
          SUM(final_amount) as total_amount, 
          COUNT(*) as order_count 
        FROM sales 
        WHERE billed_date LIKE '$todayStr%'
      ''');

      double total = 0.0;
      int count = 0;

      if (result.isNotEmpty) {
        // Handle potential nulls if no sales exist yet
        total = result.first['total_amount'] != null
            ? (result.first['total_amount'] as num).toDouble()
            : 0.0;
        count = result.first['order_count'] != null
            ? (result.first['order_count'] as num).toInt()
            : 0;
      }

      if (mounted) {
        setState(() {
          _shopName = shop.name.isNotEmpty ? shop.name : "Sell Droid";
          _logoPath = shop.logo.isNotEmpty ? shop.logo : null;
          _todaySalesTotal = total;
          _todayOrdersCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    _setCurrentDate();
    await _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. Header (Logo & Name) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // LOGO
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: _logoPath == null
                                ? accentColor
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            image: _logoPath != null
                                ? DecorationImage(
                                    image: FileImage(File(_logoPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _logoPath == null
                              ? const Icon(
                                  Icons.storefront,
                                  color: Colors.white,
                                  size: 24,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),

                        // SHOP NAME
                        _isLoading
                            ? const SizedBox(
                                width: 100,
                                height: 20,
                                child: LinearProgressIndicator(
                                  color: accentColor,
                                ),
                              )
                            : Text(
                                _shopName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                      ],
                    ),

                    // Settings Button
                    IconButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                        _loadDashboardData();
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: secondaryText,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- 2. Date Display (ABOVE THE BOX) ---
                Text(
                  _currentDate,
                  style: const TextStyle(
                    color: secondaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 12),

                // --- 3. Sales Dashboard Card (REAL DATA) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Today's Sales",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // AMOUNT DISPLAY
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "₹${num_format.format(_todaySalesTotal.toInt())}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildStatusChip(
                            Colors.tealAccent,
                            "$_todayOrdersCount Orders",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- 4. Quick Actions ---
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 16),

                // Make Bill Button
                _buildLargeActionCard(
                  icon: Icons.add,
                  title: "Make Bill",
                  subtitle: "Create new invoice",
                  iconBgColor: const Color(0xFFE0F2F1),
                  iconColor: accentColor,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MakeBillScreen(),
                      ),
                    );
                    _loadDashboardData();
                  },
                ),
                const SizedBox(height: 16),

                // Expense & Report
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallActionCard(
                        icon: Icons.account_balance_wallet,
                        title: "Expense",
                        subtitle: "Track costs",
                        iconBgColor: const Color(0xFFFFF3E0),
                        iconColor: Colors.orange,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return ExpenseScreen();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSmallActionCard(
                        icon: Icons.bar_chart,
                        title: "Report",
                        subtitle: "Analytics",
                        iconBgColor: const Color(0xFFF3E5F5),
                        iconColor: Colors.purple,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return ReportHubScreen();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Purchase Button
                _buildLargeActionCard(
                  icon: Icons.shopping_cart,
                  title: "Purchase",
                  subtitle: "Buy goods from supplier",
                  iconBgColor: const Color(0xFFE1F5FE),
                  iconColor: Colors.blue,
                  onTap: () {
                    // Navigate to Purchase Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PurchaseEntryScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),
                _buildLargeActionCard(
                  icon: Icons.attach_money,
                  title: "Payments",
                  subtitle: "Sales & Purchase",
                  iconBgColor: const Color.fromARGB(255, 228, 255, 243),
                  iconColor: Colors.green,
                  onTap: () {
                    // Navigate to Purchase Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaymentsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildStatusChip(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLargeActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: secondaryText),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: secondaryText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
