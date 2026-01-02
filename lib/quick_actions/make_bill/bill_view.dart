import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:selldroid/PdfHelper.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/file_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/helpers/print_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/models/sale.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/models/sold_item.dart';
import 'package:selldroid/settings/configure.dart';
import 'package:share_plus/share_plus.dart';

class BillDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> saleData; // Passed from the list screen

  const BillDetailsScreen({super.key, required this.saleData});

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  // --- Theme Colors ---
  final Color colBackground = const Color(0xFFEFF2F5);
  final Color colPrimary = const Color(0xFF127D95);
  final Color colTextDark = const Color(0xFF2D3436);
  final Color colTextLight = const Color(0xFF636E72);
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

    // 2. Load Shop Details (For State)
    final shop = await DatabaseHelper.instance.getShopDetails();
    final prefs = await DatabaseHelper.instance.getPreferences();
    // 3. Load Customer Details (For State)
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
        customerName: _customer!.name,
        customerPhone: _customer!.phoneNumber,
        customerPlace: _customer!.state,
        customerState: _customer!.state,
        prefs: prefs,
      );

      setState(() {
        bill_path = bill_path;
      });
    }
  }

  // --- Logic to check Tax Type ---
  bool _isInterState() {
    String shopState = (_shop?.state ?? "").trim().toLowerCase();

    // If no customer (Walk-in) or customer has no state, assume Local (Shop State)
    String custState = (_customer?.state ?? shopState).trim().toLowerCase();
    if (custState.isEmpty) custState = shopState;

    // Safety check
    if (shopState.isEmpty) return false;

    return shopState != custState;
  }

  void showErrorSnackBar(String txt, BuildContext context) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(txt, style: TextStyle(color: Colors.white)),
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
        MaterialPageRoute(
          builder: (context) {
            return ConfigurePage();
          },
        ),
      );
    }
    PrintHelper.print80mmBill(
      File(bill_path),
      (await DatabaseHelper.instance.getPrinter())!.name,
      context,
    );
    // 1. Reconstruct Sale Object

    // 2. Generate PDF (Uncomment when you integrate PDF logic)
    /* await PdfGenerator.printBill(
      shop: _shop!,
      sale: saleObj,
      items: _items,
      customerName: _customer?.name ?? "Walk-in Customer",
      customerState: _customer?.state ?? _shop!.state, 
    ); */
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: colBackground,
      appBar: AppBar(
        backgroundColor: colBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Bill ${sale['isStockSales'] == 1 ? "S" : "Q" + "" + sale['id'].toString()}",
          style: TextStyle(color: colTextDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              SharePlus.instance.share(ShareParams(files: [XFile(bill_path)]));
            },
            icon: CircleAvatar(
              backgroundColor: colPrimary.withOpacity(0.1),
              child: Icon(Icons.share, color: colPrimary, size: 20),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF1E88E5),
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
                            // Show State info if available
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
                                "₹${(item.amount).toStringAsFixed(0)}", // Note: SoldItem.amount is typically total for that line (qty*price)
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          "Sub Total",
                          "₹${sale['total_amount'] + sale['discount_amount']}",
                        ),

                        if (sale['discount_amount'] > 0)
                          _buildSummaryRow(
                            "Discount",
                            "- ₹${sale['discount_amount']}",
                            color: Colors.green,
                          ),

                        // --- DYNAMIC TAX SECTION ---
                        if (totalGst > 0) ...[
                          if (isInterState)
                            _buildSummaryRow(
                              "IGST (Inter-State)",
                              "+ ₹${totalGst.toStringAsFixed(2)}",
                            )
                          else ...[
                            _buildSummaryRow(
                              "CGST (Local)",
                              "+ ₹${(totalGst / 2).toStringAsFixed(2)}",
                            ),
                            _buildSummaryRow(
                              "SGST (Local)",
                              "+ ₹${(totalGst / 2).toStringAsFixed(2)}",
                            ),
                          ],
                        ],

                        const Divider(height: 24),
                        _buildSummaryRow(
                          "Net Payable",
                          "₹${sale['final_amount']}",
                          isBold: true,
                          fontSize: 16,
                        ),
                        if (!isPaid)
                          _buildSummaryRow(
                            "Paid Amount",
                            "₹$paid",
                            color: colTextLight,
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
        onPressed: () {
          _printBill(context);
        },
        backgroundColor: colPrimary,
        icon: const Icon(Icons.print, color: Colors.white),
        label: const Text(
          "PRINT BILL",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
