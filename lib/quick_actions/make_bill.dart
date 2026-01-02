import 'package:flutter/material.dart';
import 'package:selldroid/quick_actions/make_bill/all_bills_view.dart';
import 'package:selldroid/quick_actions/make_bill/customer_report.dart';
import 'package:selldroid/quick_actions/make_bill/quick_sale.dart';
import 'package:selldroid/quick_actions/make_bill/stock_sale.dart';

class MakeBillScreen extends StatelessWidget {
  const MakeBillScreen({super.key});

  // Color Palette (Consistent with your App)
  static const Color bgColor = Color(0xFFE8ECEF);
  static const Color primaryText = Color(0xFF46494C);
  static const Color secondaryText = Color(0xFF757575);
  static const Color cardColor = Colors.white;
  static const Color accentColor = Color(0xFF2585A1); // Teal
  static const Color iconBgColor = Color(
    0xFFE0F7FA,
  ); // Light Cyan for icon background

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Make Bill",
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select a billing method to proceed:",
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // --- Option 1: Stock Sale ---
              _buildOptionCard(
                icon: Icons.inventory_2, // Box icon
                title: "Stock Sale",
                subtitle: "Sell items directly from inventory",
                onTap: () {
                  // Navigate to Stock Sale Screen
                  debugPrint("Stock Sale Tapped");
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (builder) {
                        return StockSaleScreen();
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // --- Option 2: Quick Sale ---
              _buildOptionCard(
                icon: Icons.flash_on, // Lightning icon
                title: "Quick Sale",
                subtitle: "Rapid billing for custom items",
                onTap: () {
                  // Navigate to Quick Sale Screen
                  debugPrint("Quick Sale Tapped");
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (builder) {
                        return QuickSaleScreen();
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // --- Option 3: Customer Report ---
              _buildOptionCard(
                icon: Icons.person_search, // User search icon
                title: "Customer Report",
                subtitle: "View billing history and details",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return CustomerReportScreen();
                      },
                    ),
                  );
                  debugPrint("Customer Report Tapped");
                },
              ),
              const SizedBox(height: 16),
              _buildOptionCard(
                icon: Icons.person_search, // User search icon
                title: "View all Bills",
                subtitle: "View billing history and details",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return AllBillsScreen();
                      },
                    ),
                  );
                  debugPrint("Customer Report Tapped");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
              // Circular Icon Background
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 24),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              const Icon(
                Icons.chevron_right,
                color: Colors.grey, // Standard grey for navigation arrow
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
