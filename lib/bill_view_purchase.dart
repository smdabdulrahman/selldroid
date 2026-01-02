import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/models/general_models.dart';

import 'package:selldroid/models/shop.dart';

class PurchaseBillDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> purchaseData; // Passed from history list

  const PurchaseBillDetailsScreen({super.key, required this.purchaseData});

  @override
  State<PurchaseBillDetailsScreen> createState() =>
      _PurchaseBillDetailsScreenState();
}

class _PurchaseBillDetailsScreenState extends State<PurchaseBillDetailsScreen> {
  // --- Theme Colors ---
  final Color colBackground = const Color(0xFFEFF2F5);
  final Color colPrimary = const Color(0xFF127D95);
  final Color colTextDark = const Color(0xFF2D3436);
  final Color colTextLight = const Color(0xFF636E72);

  List<PurchaseItem> _items = [];
  ShopDetails? _shop;
  SupplierInfo? _supplier;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    int purchaseId = widget.purchaseData['id'];
    int? supplierId = widget.purchaseData['supplier_info_id'];

    // 1. Load Items
    final items = await DatabaseHelper.instance.getItemsForPurchase(purchaseId);

    // 2. Load Shop Details (For State comparison)
    final shop = await DatabaseHelper.instance.getShopDetails();

    // 3. Load Supplier Details (For State comparison)
    SupplierInfo? supplier;
    if (supplierId != null) {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        'supplier_info',
        where: 'id = ?',
        whereArgs: [supplierId],
      );
      if (maps.isNotEmpty) {
        supplier = SupplierInfo.fromMap(maps.first);
      }
    }

    if (mounted) {
      setState(() {
        _items = items;
        _shop = shop;
        _supplier = supplier;
        _isLoading = false;
      });
    }
  }

  // --- Logic to check Tax Type ---
  bool _isInterState() {
    String shopState = (_shop?.state ?? "").trim().toLowerCase();
    String suppState = (_supplier?.state ?? "").trim().toLowerCase();

    // If data missing, default to local
    if (shopState.isEmpty || suppState.isEmpty) return false;

    return shopState != suppState;
  }

  Future<void> _printBill() async {
    // Placeholder for Printing Logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Printing feature coming soon!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Data Extraction
    final bill = widget.purchaseData;
    String dateStr = bill['purchased_date'] != null
        ? DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(DateTime.parse(bill['purchased_date']))
        : "Unknown Date";

    String supplierName = bill['vendor_name'] ?? "Unknown Supplier";

    int total = bill['final_amount'];
    int paid = bill['paid'] ?? 0;
    int balance = total - paid;
    bool isPaid = balance <= 0;

    // Tax Calcs
    double totalGst = (bill['gst_amount'] as int).toDouble();
    bool isInterState = _isInterState();

    return Scaffold(
      backgroundColor: colBackground,
      appBar: AppBar(
        backgroundColor: colBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Purchase #${bill['id']}",
          style: TextStyle(color: colTextDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _printBill,
            icon: CircleAvatar(
              backgroundColor: colPrimary.withOpacity(0.1),
              child: Icon(Icons.print, color: colPrimary, size: 20),
            ),
          ),
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
                      color: Colors.white,
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
                          "Total Purchase Value",
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
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPaid
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaid ? Icons.check_circle : Icons.pending,
                                size: 16,
                                color: isPaid ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPaid
                                    ? "Paid"
                                    : "Due: ₹${FunctionsHelper.format_int(balance)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 2. SUPPLIER INFO ---
                  Text(
                    "Supplier Details",
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.store, color: Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplierName,
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
                            if (_supplier != null &&
                                _supplier!.state.isNotEmpty)
                              Text(
                                "State: ${_supplier!.state}",
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
                    "Purchased Items (${_items.length})",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colTextLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        // Calculate display values
                        double lineTotal = item.qty * item.amount; // Base

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
                                  color: Colors.grey.shade100,
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colTextDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      "@ ₹${FunctionsHelper.format_double(item.amount.toStringAsFixed(1))} + ₹${FunctionsHelper.format_double(item.gstAmount.toStringAsFixed(1))} Tax",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colTextLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Display Base + Tax for this line item?
                              // For simplicity, showing Base price here, Tax is summarized below
                              Text(
                                "₹${FunctionsHelper.format_double(lineTotal.toStringAsFixed(0))}",
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
                    "Bill Summary",
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          "Taxable Amount",
                          "₹${bill['tot_amount'] != null ? FunctionsHelper.format_int(bill['tot_amount']) : 0}",
                        ), // Note: tot_amount usually holds base in your logic

                        if (bill['discount'] > 0)
                          _buildSummaryRow(
                            "Discount",
                            "- ₹${bill['discount']}",
                            color: Colors.green,
                          ),

                        // --- DYNAMIC TAX SECTION ---
                        if (totalGst > 0) ...[
                          if (isInterState)
                            _buildSummaryRow(
                              "IGST (Inter-State)",
                              "+ ₹${FunctionsHelper.format_double(totalGst.toStringAsFixed(2))}",
                            )
                          else ...[
                            _buildSummaryRow(
                              "CGST (Local)",
                              "+ ₹${FunctionsHelper.format_double((totalGst / 2).toStringAsFixed(2))}",
                            ),
                            _buildSummaryRow(
                              "SGST (Local)",
                              "+ ₹${FunctionsHelper.format_double((totalGst / 2).toStringAsFixed(2))}",
                            ),
                          ],
                        ],

                        const Divider(height: 24),
                        _buildSummaryRow(
                          "Grand Total",
                          "₹${FunctionsHelper.format_int(bill['final_amount'])}",
                          isBold: true,
                          fontSize: 16,
                        ),
                        if (paid > 0)
                          _buildSummaryRow(
                            "Paid Amount",
                            "₹${FunctionsHelper.format_int(paid)}",
                            color: colTextLight,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
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
              color: colTextLight,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              color: color ?? colTextDark,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
