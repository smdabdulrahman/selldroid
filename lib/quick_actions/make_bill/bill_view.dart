import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/PdfHelper.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/helpers/print_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/models/sale.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/models/sold_item.dart';
import 'package:selldroid/settings/configure.dart';
import 'package:selldroid/theme_provider.dart'; // Ensure this is imported
import 'package:share_plus/share_plus.dart';

class BillDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> saleData;

  const BillDetailsScreen({super.key, required this.saleData});

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  String bill_path = "";
  List<SoldItem> _items = [];
  ShopDetails? _shop;
  Customer? _customer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    int saleId = widget.saleData['id'];
    int? custId = widget.saleData['customer_id'];

    // 1. Load Items
    final items = await DatabaseHelper.instance.getItemsForSale(saleId);

    // 2. Load Shop Details
    final shop = await DatabaseHelper.instance.getShopDetails();
    final prefs = await DatabaseHelper.instance.getPreferences();

    // 3. Load Customer Details
    Customer? cust;
    if (custId != null) {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        'customer',
        where: 'id = ?',
        whereArgs: [custId],
      );
      if (maps.isNotEmpty) {
        cust = Customer.fromMap(maps.first);
      }
    }

    if (mounted) {
      setState(() {
        _items = items;
        _shop = shop;
        _customer = cust;
        _isLoading = false;
      });

      Sale saleObj = Sale(
        id: widget.saleData['id'],
        customerId: widget.saleData['customer_id'],
        totalAmount: widget.saleData['total_amount'],
        gstAmount: (widget.saleData['gst_amount'] as int),
        discountAmount: widget.saleData['discount_amount'],
        finalAmount: widget.saleData['final_amount'],
        paid: widget.saleData['paid'],
        isStockSales: widget.saleData['is_stock_sales'] == 1,
        paymentMode: widget.saleData['payment_mode'] ?? "Cash",
        billedDate: widget.saleData['billed_date'],
        lastPaymentDate: widget.saleData["last_payment_date"],
      );

      bill_path = await PdfBillHelper.createBill(
        shop: _shop!,
        sale: saleObj,
        items: _items,
        customerName: _customer?.name ?? "Walk-in Customer",
        customerPhone: _customer?.phoneNumber ?? "",
        customerPlace: _customer?.state ?? "",
        customerState: _customer?.state ?? "",
        prefs: prefs,
      );

      setState(() {
        bill_path = bill_path;
      });
    }
  }

  bool _isInterState() {
    String shopState = (_shop?.state ?? "").trim().toLowerCase();
    String custState = (_customer?.state ?? shopState).trim().toLowerCase();
    if (custState.isEmpty) custState = shopState;
    if (shopState.isEmpty) return false;
    return shopState != custState;
  }

  void showErrorSnackBar(String txt, BuildContext context) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(txt, style: const TextStyle(color: Colors.white)),
        action: SnackBarAction(label: "OK", onPressed: () {}),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  Future<void> _printBill(BuildContext context) async {
    if ((await DatabaseHelper.instance.getPrinter()) == null) {
      showErrorSnackBar("Select Your Printer in Settings", context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ConfigurePage()),
      );
      return;
    }
    PrintHelper.print80mmBill(
      File(bill_path),
      (await DatabaseHelper.instance.getPrinter())!.name,
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. WATCH THEME PROVIDER
    final theme = context.watch<ThemeProvider>();

    // 2. MAP LOCAL VARIABLES TO THEME FOR CLEANER CODE
    final Color colTextDark = theme.primaryText;
    final Color colTextLight = theme.secondaryText;
    final Color colPrimary = theme.accentColor;
    final Color colCard = theme.cardColor;
    // We use theme.bgColor for scaffold, but need a slight contrast for inputs/boxes inside cards
    final Color colBoxFill = theme.bgColor;

    // Data Extraction
    final sale = widget.saleData;

    String dateStr = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.parse(sale['billed_date']));
    String custName = sale['cust_name'] ?? "Walk-in Customer";

    int total = sale['final_amount'];
    int paid = sale['paid'] ?? total;
    int balance = total - paid;
    bool isPaid = balance <= 0;

    // Tax Calcs
    double totalGst = (sale['gst_amount'] as int).toDouble();
    bool isInterState = _isInterState();

    return Scaffold(
      backgroundColor: theme.bgColor, // Dynamic Background
      appBar: AppBar(
        backgroundColor: theme.bgColor, // Dynamic Background
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
          "Bill ${sale['isStockSales'] == 1 ? "S" : "Q"}${sale['id']}",
          style: TextStyle(
            color: theme.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (bill_path.isNotEmpty) {
                SharePlus.instance.share(
                  ShareParams(files: [XFile(bill_path)]),
                );
              }
            },
            icon: CircleAvatar(
              backgroundColor: theme.accentColor.withOpacity(0.1),
              radius: 18,
              child: Icon(Icons.share, color: theme.accentColor, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. HEADER CARD (Status & Total) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colCard, // Dynamic Card Color
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Net Amount",
                          style: TextStyle(color: colTextLight, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${FunctionsHelper.format_int(total)}",
                          style: TextStyle(
                            color: colTextDark,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPaid
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaid ? Icons.check_circle : Icons.warning,
                                size: 16,
                                color: isPaid ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPaid
                                    ? "Fully Paid"
                                    : "Unpaid (Bal: ₹${FunctionsHelper.format_int(balance)})",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 2. CUSTOMER INFO ---
                  Text(
                    "Customer Details",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colTextLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colCard, // Dynamic Card Color
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: theme.accentColor.withOpacity(
                              0.1,
                            ), // Match Accent
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person,
                            color: theme.accentColor, // Match Accent
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              custName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colTextDark,
                              ),
                            ),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: colTextLight,
                              ),
                            ),
                            if (_customer != null &&
                                _customer!.state.isNotEmpty)
                              Text(
                                "State: ${_customer!.state}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colTextLight,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 3. ITEMS LIST ---
                  Text(
                    "Ordered Items (${_items.length})",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colTextLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colCard, // Dynamic Card Color
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (ctx, i) =>
                          Divider(height: 1, color: colBoxFill),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colBoxFill, // Dynamic inner box color
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "${item.qty}x",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colTextDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colTextDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                "₹${FunctionsHelper.format_double((item.amount).toStringAsFixed(0))}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colTextDark,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- 4. BILL BREAKDOWN ---
                  Text(
                    "Payment Summary",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colTextLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colCard, // Dynamic Card Color
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          "Sub Total",
                          "₹${FunctionsHelper.format_int(sale['total_amount'] + sale['discount_amount'])}",
                          colTextLight,
                          colTextDark,
                        ),

                        if (sale['discount_amount'] > 0)
                          _buildSummaryRow(
                            "Discount",
                            "- ₹${FunctionsHelper.format_int(sale['discount_amount'])}",
                            colTextLight,
                            Colors.green,
                          ),

                        if (totalGst > 0) ...[
                          if (isInterState)
                            _buildSummaryRow(
                              "IGST (Inter-State)",
                              "+ ₹${FunctionsHelper.format_double(totalGst.toStringAsFixed(2))}",
                              colTextLight,
                              colTextDark,
                            )
                          else ...[
                            _buildSummaryRow(
                              "CGST (Local)",
                              "+ ₹${FunctionsHelper.format_double((totalGst / 2).toStringAsFixed(2))}",
                              colTextLight,
                              colTextDark,
                            ),
                            _buildSummaryRow(
                              "SGST (Local)",
                              "+ ₹${FunctionsHelper.format_double((totalGst / 2).toStringAsFixed(2))}",
                              colTextLight,
                              colTextDark,
                            ),
                          ],
                        ],

                        Divider(height: 24, color: colBoxFill),
                        _buildSummaryRow(
                          "Net Payable",
                          "₹${FunctionsHelper.format_int(sale['final_amount'])}",
                          colTextLight,
                          colTextDark,
                          isBold: true,
                          fontSize: 16,
                        ),
                        if (!isPaid)
                          _buildSummaryRow(
                            "Paid Amount",
                            "₹${FunctionsHelper.format_int(paid)}",
                            colTextLight,
                            colTextLight,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      // Floating Print Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _printBill(context),
        backgroundColor: colPrimary, // Dynamic Accent Color
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text(
          "PRINT BILL",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Helper Widget
  Widget _buildSummaryRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: labelColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              color: valueColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
