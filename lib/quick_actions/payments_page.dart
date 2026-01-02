import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/show_dialog_boxes.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  // --- Theme Colors (From your code) ---
  static const Color bgColor = Color.fromARGB(255, 250, 250, 255);
  static const Color primaryText = Color.fromARGB(255, 70, 73, 76);
  static const Color secondaryText = Color.fromARGB(255, 76, 92, 104);
  static const Color accentColor = Color.fromARGB(255, 25, 133, 161);
  static const Color cardColor = Colors.white;

  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = "";

  // Data Lists
  List<Map<String, dynamic>> _saleDues = [];
  List<Map<String, dynamic>> _purchaseDues = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // 1. Fetch Sales Dues (Only Pending)
    final salesRes = await db.rawQuery('''
      SELECT s.id, s.final_amount, s.paid, s.billed_date, c.name as party_name
      FROM sales s
      LEFT JOIN customer c ON s.customer_id = c.id
      WHERE s.paid < s.final_amount
      ORDER BY c.name ASC, s.billed_date DESC
    ''');

    // 2. Fetch Purchase Dues (Only Pending)
    final purchaseRes = await db.rawQuery('''
      SELECT p.id, p.final_amount, p.paid, p.purchased_date as billed_date, s.name as party_name
      FROM purchases p
      LEFT JOIN supplier_info s ON p.supplier_info_id = s.id
      WHERE p.paid < p.final_amount
      ORDER BY s.name ASC, p.purchased_date DESC
    ''');

    if (mounted) {
      setState(() {
        _saleDues = salesRes;
        _purchaseDues = purchaseRes;
        _isLoading = false;
      });
    }
  }

  // --- RECORD PAYMENT DIALOG ---
  void _showSettleDialog({
    required Map<String, dynamic> item,
    required bool isSale,
  }) {
    final int id = item['id'];
    final int total = item['final_amount'];
    final int paid = item['paid'];
    final int due = total - paid;
    final String partyName =
        item['party_name'] ??
        (isSale ? "Walk-in Customer" : "Unknown Supplier");

    final TextEditingController amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isSale ? "Collect Payment" : "Make Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Party: $partyName",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Bill ID: #${isSale ? 'S' : 'P'}$id"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSale ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Current Due:"),
                  Text(
                    "₹$due",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            onPressed: () async {
              int amount = int.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0 || amount > due) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Invalid Amount")));
                return;
              }

              final db = await DatabaseHelper.instance.database;
              int newPaid = paid + amount;
              String date = DateTime.now().toIso8601String();

              if (isSale) {
                await db.rawUpdate(
                  'UPDATE sales SET paid = ?, last_payment_date = ? WHERE id = ?',
                  [newPaid, date, id],
                );
              } else {
                await db.rawUpdate(
                  'UPDATE purchases SET paid = ?, last_payment_date = ? WHERE id = ?',
                  [newPaid, date, id],
                );
              }

              if (mounted) {
                Navigator.pop(context);
                _loadData();
                ShowDialogBoxes.showAutoCloseSuccessDialog(
                  context: context,
                  message: "Payment Saved",
                );
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
    for (var item in list) {
      String party =
          item['party_name'] ??
          (isSale ? "Walk-in Customer" : "Unknown Supplier");
      if (!grouped.containsKey(party)) grouped[party] = [];
      grouped[party]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Payments",
          style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: primaryText,
            size: 20,
          ),
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
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Party or Bill ID...",
                prefixIcon: const Icon(Icons.search, color: secondaryText),
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

          // --- Tabs ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDuesList(
                        _saleDues,
                        true,
                        "No pending customer payments",
                      ),
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
    final filtered = _filterList(rawList, isSale);
    final grouped = _groupList(filtered, isSale);

    // Calculate Grand Total for the Summary Card
    double grandTotal = 0;
    for (var item in filtered) {
      grandTotal += ((item['final_amount'] as int) - (item['paid'] as int));
    }

    return Column(
      children: [
        // --- Summary Card (Your Style) ---
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
                  child: Text(
                    emptyMsg,
                    style: const TextStyle(color: secondaryText),
                  ),
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

                    // Party Total
                    double partyTotal = 0;
                    for (var i in items)
                      partyTotal +=
                          ((i['final_amount'] as int) - (i['paid'] as int));

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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          subtitle: Text(
                            "${items.length} Bills • Due: ₹${FunctionsHelper.num_format.format(partyTotal.toInt())}",
                            style: const TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          children: items.map((item) {
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
                                  top: BorderSide(color: Colors.grey.shade100),
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
                                          style: const TextStyle(
                                            color: secondaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "₹${FunctionsHelper.num_format.format(due)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    height: 30,
                                    child: ElevatedButton(
                                      onPressed: () => _showSettleDialog(
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
                                        style: const TextStyle(
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
