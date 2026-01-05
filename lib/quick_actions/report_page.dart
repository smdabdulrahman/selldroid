import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/quick_actions/make_bill/all_bills_view.dart';
import 'package:selldroid/quick_actions/make_bill/customer_report.dart';
import 'package:selldroid/quick_actions/purchase_history.dart';
import 'package:selldroid/quick_actions/reports/expense_report.dart';
import 'package:selldroid/quick_actions/reports/overall_report.dart';
import 'package:selldroid/quick_actions/reports/quick_sale_report.dart';
import 'package:selldroid/quick_actions/reports/stock_report.dart';
import 'package:selldroid/quick_actions/reports/supplier_report.dart';
import 'package:selldroid/theme_provider.dart';

// import 'package:selldroid/customer_report.dart'; // Uncomment when ready to link real pages
// import 'package:selldroid/expense_screen.dart';

class ReportHubScreen extends StatefulWidget {
  const ReportHubScreen({super.key});

  @override
  State<ReportHubScreen> createState() => _ReportHubScreenState();
}

late Color bgColor;
late Color primaryText;
late Color secondaryText;
late Color cardColor;
late Color iconBgColor;
late Color iconColor;

class _ReportHubScreenState extends State<ReportHubScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    bgColor = theme.bgColor;
    primaryText = theme.primaryText;
    secondaryText = theme.secondaryText;
    cardColor = theme.cardColor;
    iconBgColor = const Color(0xFFE0F2F1); // Light Teal/Cyan
    iconColor = theme.accentColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Reports",
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER SECTION ---
            Text(
              "Overview",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Select a category to view details",
              style: TextStyle(fontSize: 14, color: secondaryText),
            ),
            const SizedBox(height: 20),

            // --- REPORT CARDS ---
            _buildReportItem(
              context,
              title: "Overall Sale Report",
              subtitle: "Inventory turnover and sales metrics",
              icon: Icons.inventory_2, // Box icon
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return OverallReportScreen();
                    },
                  ),
                );
              },
            ),
            _buildReportItem(
              context,
              title: "Stock Sale Report",
              subtitle: "Inventory turnover and sales metrics",
              icon: Icons.inventory_2, // Box icon
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return StockSaleReportScreen();
                    },
                  ),
                );
              },
            ),
            _buildReportItem(
              context,
              title: "Quick Sale Report",
              subtitle: "Daily fast-track transactions",
              icon: Icons.flash_on, // Lightning icon
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return QuickSaleReportScreen();
                    },
                  ),
                );
              },
            ),

            _buildReportItem(
              context,
              title: "Customer Report",
              subtitle: "Client purchase history and insights",
              icon: Icons.people_alt, // People icon
              // Change this to: Navigator.push(context, MaterialPageRoute(builder: (c) => const CustomerReportScreen()));
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return CustomerReportScreen();
                    },
                  ),
                );
              },
            ),

            _buildReportItem(
              context,
              title: "Purchase Report", // Renamed from Purchases to match image
              subtitle: "Supplier performance and orders",
              icon: Icons.local_shipping, // Truck icon
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return SupplierReportScreen();
                    },
                  ),
                );
              },
            ),

            _buildReportItem(
              context,
              title: "Expense Report",
              subtitle: "Operational costs and overhead",
              icon: Icons.receipt_long, // Bill/Receipt icon
              // Change this to: Navigator.push(context, MaterialPageRoute(builder: (c) => const ExpenseScreen()));
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return ExpenseReportScreen();
                    },
                  ),
                );
              },
            ),

            _buildReportItem(
              context,
              title: "Sale History",
              subtitle: "Stock and quick sale history",
              icon: Icons.widgets, // Bill/Receipt icon
              // Change this to: Navigator.push(context, MaterialPageRoute(builder: (c) => const ExpenseScreen()));
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return AllBillsScreen();
                    },
                  ),
                );
              },
            ),

            _buildReportItem(
              context,
              title: "Purchase History",
              subtitle: "Purchase history and details",
              icon: Icons.warehouse, // Bill/Receipt icon
              // Change this to: Navigator.push(context, MaterialPageRoute(builder: (c) => const ExpenseScreen()));
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return PurchaseHistoryScreen();
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper to redirect everything to Home for now
  void _navigateToHome(BuildContext context) {
    /* Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    ); */
  }

  Widget _buildReportItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(
          16,
        ), // Rounded corners like the image
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // --- ICON BOX ---
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: iconBgColor, // Light Blue/Teal background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor, // Darker Teal icon
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // --- TEXT CONTENT ---
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
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryText,
                          height: 1.2, // Better line spacing
                        ),
                      ),
                    ],
                  ),
                ),

                // --- ARROW ICON ---
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey, // Light grey arrow
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
