import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/quick_actions/make_bill/all_bills_view.dart';
import 'package:selldroid/quick_actions/make_bill/customer_report.dart';
import 'package:selldroid/quick_actions/make_bill/quick_sale.dart';
import 'package:selldroid/quick_actions/make_bill/stock_sale.dart';
import 'package:selldroid/theme_provider.dart';

class MakeBillScreen extends StatelessWidget {
  const MakeBillScreen({super.key});

  final Color iconBgColor = const Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    final bgColor = theme.bgColor;
    final primaryText = theme.primaryText;
    final secondaryText = theme.secondaryText;
    final accentColor = theme.accentColor;
    final cardColor = theme.cardColor;
    return Scaffold(
      backgroundColor: theme.bgColor,
      appBar: AppBar(
        backgroundColor: theme.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Make Bill",
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
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
                cardColor: cardColor,
                primaryText: primaryText,
                secondaryText: secondaryText,
                accentColor: accentColor,
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
                cardColor: cardColor,
                primaryText: primaryText,
                secondaryText: secondaryText,
                accentColor: accentColor,
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
                cardColor: cardColor,
                primaryText: primaryText,
                secondaryText: secondaryText,
                accentColor: accentColor,
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
                cardColor: cardColor,
                primaryText: primaryText,
                secondaryText: secondaryText,
                accentColor: accentColor,
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
    required Color cardColor,
    required Color primaryText,
    required Color secondaryText,
    required Color accentColor,
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
                decoration: BoxDecoration(
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: secondaryText),
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
