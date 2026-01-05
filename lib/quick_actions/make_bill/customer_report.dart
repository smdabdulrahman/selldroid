import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/theme_provider.dart';

// Model to hold report data
class CustomerReportItem {
  final Customer customer;
  final List<Map<String, dynamic>> sales;
  final double totalBilled;
  final double totalPaid;
  final double totalUnpaid;

  CustomerReportItem({
    required this.customer,
    required this.sales,
    required this.totalBilled,
    required this.totalPaid,
    required this.totalUnpaid,
  });
}

class CustomerReportScreen extends StatefulWidget {
  const CustomerReportScreen({super.key});

  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends State<CustomerReportScreen> {
  bool _isLoading = true;
  List<CustomerReportItem> _allReports = [];
  List<CustomerReportItem> _filteredReports = [];

  // Filters
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // 1. Get all customers
    List<Customer> customers = await DatabaseHelper.instance.getCustomers();
    List<CustomerReportItem> tempReports = [];

    // 2. Loop through customers and get their sales
    for (var cust in customers) {
      String query = 'SELECT * FROM sales WHERE customer_id = ?';
      List<dynamic> args = [cust.id];

      if (_dateRange != null) {
        query += ' AND billed_date BETWEEN ? AND ?';
        args.add(_dateRange!.start.toIso8601String());
        args.add(
          _dateRange!.end.add(const Duration(days: 1)).toIso8601String(),
        );
      }

      // Order by date descending (newest first)
      query += ' ORDER BY billed_date DESC';

      List<Map<String, dynamic>> salesMaps = await db.rawQuery(query, args);

      double tBilled = 0;
      double tPaid = 0;

      for (var sale in salesMaps) {
        tBilled += (sale['final_amount'] as num).toDouble();
        tPaid += (sale['paid'] as num).toDouble();
      }

      if (salesMaps.isNotEmpty) {
        tempReports.add(
          CustomerReportItem(
            customer: cust,
            sales: salesMaps,
            totalBilled: tBilled,
            totalPaid: tPaid,
            totalUnpaid: tBilled - tPaid,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _allReports = tempReports;
        _filteredReports = tempReports;
        _isLoading = false;
      });
      // Re-apply search filter if needed
      if (_searchCtrl.text.isNotEmpty) {
        _filterData(_searchCtrl.text);
      }
    }
  }

  void _filterData(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredReports = _allReports;
      } else {
        _filteredReports = _allReports
            .where(
              (item) => item.customer.name.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: accentColor,
            colorScheme: ColorScheme.light(primary: accentColor),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _loadReportData();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _dateRange = null;
    });
    _loadReportData();
  }

  // --- UPDATE PAYMENT LOGIC ---
  Future<void> _showUpdatePaymentDialog(Map<String, dynamic> sale) async {
    double billAmt = (sale['final_amount'] as num).toDouble();
    double alreadyPaid = (sale['paid'] as num).toDouble();
    double pending = billAmt - alreadyPaid;
    int saleId = sale['id'];

    int isStockVal = sale['is_stock_sales'] ?? 0;
    String prefix = (isStockVal == 1) ? "S" : "Q";
    String billNo = "$prefix$saleId";

    final TextEditingController amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Update Bill $billNo",
            style: TextStyle(color: primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogRow(
                "Total Bill:",
                "₹${FunctionsHelper.format_double(billAmt.toStringAsFixed(0))}",
              ),
              _buildDialogRow(
                "Already Paid:",
                "₹${FunctionsHelper.format_double(alreadyPaid.toStringAsFixed(0))}",
              ),
              const Divider(),
              _buildDialogRow(
                "Pending Due:",
                "₹${FunctionsHelper.format_double(pending.toStringAsFixed(0))}",
                isBold: true,
                color: accentColor,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: primaryText),
                decoration: InputDecoration(
                  labelText: "Enter Amount Paying Now",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee, color: secondaryText),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: secondaryText)),
            ),
            ElevatedButton(
              onPressed: () async {
                double newPay = double.tryParse(amountCtrl.text) ?? 0.0;
                if (newPay <= 0) return;

                if (newPay > pending) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Amount exceeds pending due!"),
                    ),
                  );
                  return;
                }

                final db = await DatabaseHelper.instance.database;
                String now = DateTime.now().toIso8601String();

                await db.rawUpdate(
                  'UPDATE sales SET paid = paid + ?, last_payment_date = ? WHERE id = ?',
                  [newPay, now, saleId],
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Payment Updated Successfully!"),
                  ),
                );
                _loadReportData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: const Text(
                "Save Payment",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: secondaryText)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? primaryText,
            ),
          ),
        ],
      ),
    );
  }

  late Color bgColor;
  late Color primaryText;
  late Color secondaryText;
  late Color accentColor;
  late Color cardColor;
  final inputFill = Colors.grey.shade100;
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    bgColor = theme.bgColor;
    primaryText = theme.primaryText;
    secondaryText = theme.secondaryText;
    accentColor = theme.accentColor;
    cardColor = theme.cardColor;

    // Calculate Grand Totals
    double totalPaidAll = 0;
    double totalUnpaidAll = 0;
    for (var item in _filteredReports) {
      totalPaidAll += item.totalPaid;
      totalUnpaidAll += item.totalUnpaid;
    }

    return Scaffold(
      backgroundColor: theme.bgColor,
      appBar: AppBar(
        title: Text(
          "Customer Report",
          style: TextStyle(
            color: theme.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.primaryText),
        actions: [
          IconButton(
            icon: Icon(
              _dateRange == null
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt_off,
              color: accentColor,
            ),
            onPressed: _dateRange == null ? _selectDateRange : _clearDateFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 1. SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filterData,
              style: TextStyle(color: primaryText),
              decoration: InputDecoration(
                hintText: "Search Customer...",
                hintStyle: TextStyle(color: secondaryText),
                prefixIcon: Icon(Icons.search, color: secondaryText),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- 2. SUMMARY CARDS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildSummaryCard("Total Paid", totalPaidAll)),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard("Total Unpaid", totalUnpaidAll),
                ),
              ],
            ),
          ),

          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "Showing: ${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}",
                style: TextStyle(fontSize: 12, color: secondaryText),
              ),
            ),

          // --- 3. CUSTOMER LIST ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                ? Center(
                    child: Text(
                      "No records found",
                      style: TextStyle(color: secondaryText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredReports.length,
                    itemBuilder: (context, index) {
                      final item = _filteredReports[index];
                      return _buildCustomerCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300), // Neutral border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: secondaryText,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "₹${FunctionsHelper.format_double(amount.toStringAsFixed(2))}",
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(CustomerReportItem item) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: inputFill,
            child: Text(
              item.customer.name.isNotEmpty
                  ? item.customer.name[0].toUpperCase()
                  : "?",
              style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            item.customer.name,
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryText),
          ),
          subtitle: Text(
            "Phone: ${item.customer.phoneNumber}",
            style: TextStyle(fontSize: 12, color: secondaryText),
          ),

          // --- TRAILING: DUE/PAID + EXPAND ICON ---
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Due: ₹${FunctionsHelper.format_double(item.totalUnpaid.toStringAsFixed(0))}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accentColor, // Use Accent Color instead of Red
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "Paid: ₹${FunctionsHelper.format_double(item.totalPaid.toStringAsFixed(0))}",
                    style: TextStyle(fontSize: 10, color: secondaryText),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down,
                color: secondaryText,
              ), // Visual indicator for expansion
            ],
          ),
          children: [
            Container(
              color: inputFill,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Bill No",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: secondaryText,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Bill",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: secondaryText,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Paid",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: secondaryText,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Due",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: secondaryText,
                          ),
                        ),
                      ),
                      SizedBox(width: 20), // Space for icon
                    ],
                  ),
                  const Divider(),
                  ...item.sales.map((sale) {
                    double bill = (sale['final_amount'] as num).toDouble();
                    double paid = (sale['paid'] as num).toDouble();
                    double due = bill - paid;
                    int id = sale['id'];

                    // Bill No Logic
                    int isStockVal = sale['is_stock_sales'] ?? 0;
                    String prefix = (isStockVal == 1) ? "S" : "Q";
                    String billNo = "$prefix$id";

                    String dateStr = "";
                    try {
                      DateTime dt = DateTime.parse(sale['billed_date']);
                      dateStr = DateFormat("dd MMM").format(dt);
                    } catch (e) {
                      dateStr = "";
                    }

                    bool canPay = due > 0;

                    return InkWell(
                      onTap: canPay
                          ? () => _showUpdatePaymentDialog(sale)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    billNo,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: primaryText,
                                    ),
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: secondaryText,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            Expanded(
                              child: Text(
                                "₹${FunctionsHelper.format_double(bill.toStringAsFixed(0))}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                "₹${FunctionsHelper.format_double(paid.toStringAsFixed(0))}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                "₹${FunctionsHelper.format_double(due.toStringAsFixed(0))}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: accentColor,
                                ),
                              ),
                            ), // Accent color for Due

                            if (canPay)
                              Icon(
                                Icons.edit_note,
                                size: 20,
                                color: accentColor,
                              )
                            else
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: secondaryText,
                              ), // Neutral check
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
