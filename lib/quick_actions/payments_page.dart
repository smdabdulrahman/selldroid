import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/show_dialog_boxes.dart';
import 'package:selldroid/theme_provider.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = "";

  // Data Lists (Bills)
  List<Map<String, dynamic>> _saleDues = [];
  List<Map<String, dynamic>> _purchaseDues = [];

  // Data Maps (Opening Balances) -> Only for Suppliers
  Map<String, int> _supplierOpening = {};
  Map<String, int> _supplierIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  // --- MODERN PAYMENT DIALOG DESIGN ---
  Widget _buildPaymentDialogUI({
    required String title,
    required String partyName,
    required int dueAmount,
    required TextEditingController controller,
    required VoidCallback onSave,
    bool isOpeningBalance = false,
    // Add isSale to determine theme color (Green for receiving, Orange for paying)
    required bool isSale,
  }) {
    // Determine Theme Color
    Color themeColor;
    Color themeBg;
    IconData icon;

    if (isOpeningBalance) {
      themeColor = Colors.purple;
      themeBg = Colors.purple.shade50;
      icon = Icons.account_balance_wallet_rounded;
    } else if (isSale) {
      themeColor = const Color(0xFF0F9D58); // Green
      themeBg = const Color(0xFFE8F5E9);
      icon = Icons.arrow_circle_down_rounded; // Inbound
    } else {
      themeColor = const Color(0xFFE65100); // Orange
      themeBg = const Color(0xFFFFF3E0);
      icon = Icons.arrow_circle_up_rounded; // Outbound
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- 1. ICON HEADER ---
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(color: themeBg, shape: BoxShape.circle),
              child: Icon(icon, color: themeColor, size: 32),
            ),
            const SizedBox(height: 16),

            // --- 2. TITLE & PARTY NAME ---
            Text(
              isOpeningBalance
                  ? "Settle Opening Balance"
                  : (isSale ? "Collect Payment" : "Make Payment"),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              partyName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isOpeningBalance) ...[
              const SizedBox(height: 4),
              Text(
                title.replaceAll(" Payment", ""), // Shows "Bill #S101"
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
            const SizedBox(height: 24),

            // --- 3. DUE AMOUNT CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: themeBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeColor.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    "TOTAL DUE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: themeColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${FunctionsHelper.num_format.format(dueAmount)}",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: themeColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- 4. INPUT FIELD ---
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
              decoration: InputDecoration(
                labelText: "Enter Amount",
                labelStyle: TextStyle(color: Colors.grey[600]),
                prefixText: "₹ ",
                prefixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- 5. BUTTONS ---
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Confirm",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // 1. Fetch Sales Dues (Customers - No Opening Balance)
    final salesRes = await db.rawQuery('''
      SELECT s.id, s.final_amount, s.paid, s.billed_date, c.name as party_name
      FROM sales s
      LEFT JOIN customer c ON s.customer_id = c.id
      WHERE s.paid < s.final_amount
      ORDER BY c.name ASC, s.billed_date DESC
    ''');

    // 2. Fetch Purchase Dues (Suppliers)
    final purchaseRes = await db.rawQuery('''
      SELECT p.id, p.final_amount, p.paid, p.purchased_date as billed_date, s.name as party_name
      FROM purchases p
      LEFT JOIN supplier_info s ON p.supplier_info_id = s.id
      WHERE p.paid < p.final_amount
      ORDER BY s.name ASC, p.purchased_date DESC
    ''');

    // 3. Fetch Supplier Opening Balances (Only Suppliers have this)
    final suppRes = await db.rawQuery(
      'SELECT id, name, balance FROM supplier_info WHERE balance > 0',
    );

    Map<String, int> suppMap = {};
    Map<String, int> suppIdMap = {};
    for (var row in suppRes) {
      String name = row['name'] as String;
      int bal = (row['balance'] ?? 0) as int;
      int id = row['id'] as int;
      suppMap[name] = bal;
      suppIdMap[name] = id;
    }

    if (mounted) {
      setState(() {
        _saleDues = salesRes;
        _purchaseDues = purchaseRes;
        _supplierOpening = suppMap;
        _supplierIds = suppIdMap;
        _isLoading = false;
      });
    }
  }

  // --- 1. BILL PAYMENT DIALOG ---
  void _showBillSettleDialog({
    required Map<String, dynamic> item,
    required bool isSale,
  }) {
    final int id = item['id'];
    final int total = item['final_amount'];
    final int paid = item['paid'];
    final int due = total - paid;
    final String partyName = item['party_name'] ?? "Unknown";

    final TextEditingController amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => _buildPaymentDialogUI(
        title: "Bill #${isSale ? 'S' : 'P'}$id Payment",
        partyName: partyName,
        dueAmount: due,
        isSale: isSale,
        controller: amountCtrl,
        onSave: () async {
          int amount = int.tryParse(amountCtrl.text) ?? 0;
          if (amount <= 0 || amount > due) {
            _showSnack("Invalid Amount");
            return;
          }

          final db = await DatabaseHelper.instance.database;
          int newPaid = paid + amount;
          String date = DateTime.now().toIso8601String();
          String table = isSale ? 'sales' : 'purchases';

          await db.rawUpdate(
            'UPDATE $table SET paid = ?, last_payment_date = ? WHERE id = ?',
            [newPaid, date, id],
          );

          _refreshAfterPayment();
        },
      ),
    );
  }

  // --- 2. OPENING BALANCE PAYMENT DIALOG (Suppliers Only) ---
  void _showOpeningSettleDialog({
    required String partyName,
    required int currentOpeningBalance,
  }) {
    int? partyId = _supplierIds[partyName];
    if (partyId == null) return;

    final TextEditingController amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => _buildPaymentDialogUI(
        isSale: false,
        title: "Settle Opening Balance",
        partyName: partyName,
        dueAmount: currentOpeningBalance,
        controller: amountCtrl,
        isOpeningBalance: true,
        onSave: () async {
          int amount = int.tryParse(amountCtrl.text) ?? 0;
          if (amount <= 0 || amount > currentOpeningBalance) {
            _showSnack("Invalid Amount");
            return;
          }

          final db = await DatabaseHelper.instance.database;
          int newBalance = currentOpeningBalance - amount;

          // Update Supplier Table
          await db.rawUpdate(
            'UPDATE supplier_info SET balance = ? WHERE id = ?',
            [newBalance, partyId],
          );

          _refreshAfterPayment();
        },
      ),
    );
  }

  // Helper: Shared Dialog UI

  void _refreshAfterPayment() {
    if (mounted) {
      Navigator.pop(context);
      _loadData();
      ShowDialogBoxes.showAutoCloseSuccessDialog(
        context: context,
        message: "Payment Saved Successfully",
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- LOGIC: Filter & Group ---
  List<Map<String, dynamic>> _filterList(
    List<Map<String, dynamic>> list,
    bool isSale,
  ) {
    if (_searchQuery.isEmpty) return list;
    return list.where((item) {
      String party = (item['party_name'] ?? "").toString().toLowerCase();
      String id = "${isSale ? 's' : 'p'}${item['id']}";
      return party.contains(_searchQuery.toLowerCase()) ||
          id.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupList(
    List<Map<String, dynamic>> list,
    bool isSale,
  ) {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    // 1. Group Bills
    for (var item in list) {
      String party =
          item['party_name'] ??
          (isSale ? "Walk-in Customer" : "Unknown Supplier");
      if (!grouped.containsKey(party)) grouped[party] = [];
      grouped[party]!.add(item);
    }

    // 2. Add Suppliers with ONLY Opening Balance (Skip for Customers)
    if (!isSale) {
      _supplierOpening.forEach((party, balance) {
        if (balance > 0) {
          if (_searchQuery.isNotEmpty &&
              !party.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return;
          }
          grouped.putIfAbsent(party, () => []);
        }
      });
    }

    return grouped;
  }

  late Color bgColor;
  late Color primaryText;
  late Color secondaryText;
  late Color accentColor;
  late Color cardColor;
  final inputFill = const Color(0xFFF3F4F6);
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    bgColor = theme.bgColor;
    primaryText = theme.primaryText;
    secondaryText = theme.secondaryText;
    accentColor = theme.accentColor;
    cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Payments",
          style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: secondaryText,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Sales Payment"),
            Tab(text: "Purchase Payment"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Party or Bill ID...",
                prefixIcon: Icon(Icons.search, color: secondaryText),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // SALES TAB (Customers - No Opening Balance)
                      _buildDuesList(
                        _saleDues,
                        true,
                        "No pending customer payments",
                      ),

                      // PURCHASE TAB (Suppliers - With Opening Balance)
                      _buildDuesList(
                        _purchaseDues,
                        false,
                        "No pending supplier payments",
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuesList(
    List<Map<String, dynamic>> rawList,
    bool isSale,
    String emptyMsg,
  ) {
    final filteredBills = _filterList(rawList, isSale);
    final grouped = _groupList(filteredBills, isSale);

    // Only use opening map if NOT sales
    final openingMap = isSale ? <String, int>{} : _supplierOpening;

    // Calculate Grand Total
    double grandTotal = 0;

    // Add bill dues
    for (var item in filteredBills) {
      grandTotal += ((item['final_amount'] as int) - (item['paid'] as int));
    }

    // Add opening balance dues (Only for Purchase/Suppliers)
    if (!isSale) {
      openingMap.forEach((party, bal) {
        if (_searchQuery.isEmpty ||
            party.toLowerCase().contains(_searchQuery.toLowerCase())) {
          grandTotal += bal;
        }
      });
    }

    return Column(
      children: [
        // --- Summary Card ---
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSale
                  ? [const Color(0xFF11998e), const Color(0xFF38ef7d)]
                  : [const Color(0xFFeb3349), const Color(0xFFf45c43)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSale ? "TOTAL RECEIVABLE" : "TOTAL PAYABLE",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₹${FunctionsHelper.num_format.format(grandTotal)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSale ? Icons.arrow_downward : Icons.arrow_upward,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),

        // --- Grouped List ---
        Expanded(
          child: grouped.isEmpty
              ? Center(
                  child: Text(emptyMsg, style: TextStyle(color: secondaryText)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    String partyName = grouped.keys.elementAt(index);
                    List<Map<String, dynamic>> items = grouped[partyName]!;

                    // Logic: Opening balance only exists if NOT sale (Supplier)
                    int openingDue = (!isSale)
                        ? (openingMap[partyName] ?? 0)
                        : 0;

                    // Party Total
                    double partyTotal = openingDue.toDouble();
                    for (var i in items) {
                      partyTotal +=
                          ((i['final_amount'] as int) - (i['paid'] as int));
                    }

                    return Card(
                      color: cardColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: _searchQuery.isNotEmpty,
                          title: Text(
                            partyName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          subtitle: Text(
                            "Total Due: ₹${FunctionsHelper.num_format.format(partyTotal.toInt())}",
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          children: [
                            // --- 1. OPENING BALANCE ROW (SUPPLIERS ONLY) ---
                            if (openingDue > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50.withOpacity(0.3),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet,
                                        size: 16,
                                        color: Colors.purple,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Opening Balance",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.purple,
                                            ),
                                          ),
                                          Text(
                                            "Legacy Due",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      "₹${FunctionsHelper.num_format.format(openingDue)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: primaryText,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      height: 30,
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _showOpeningSettleDialog(
                                              partyName: partyName,
                                              currentOpeningBalance: openingDue,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.purple.shade50,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                        ),
                                        child: const Text(
                                          "Settle",
                                          style: TextStyle(
                                            color: Colors.purple,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // --- 2. BILL LIST ROWS ---
                            ...items.map((item) {
                              int total = item['final_amount'];
                              int paid = item['paid'];
                              int due = total - paid;
                              String date = DateFormat(
                                'dd MMM',
                              ).format(DateTime.parse(item['billed_date']));

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Bill #${isSale ? 'S' : 'P'}${item['id']}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            date,
                                            style: TextStyle(
                                              color: secondaryText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      "₹${FunctionsHelper.num_format.format(due)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: primaryText,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      height: 30,
                                      child: ElevatedButton(
                                        onPressed: () => _showBillSettleDialog(
                                          item: item,
                                          isSale: isSale,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor
                                              .withOpacity(0.1),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          isSale ? "Collect" : "Pay",
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
