import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selldroid/bill_view_purchase.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  // --- Colors ---
  final Color colBackground = const Color(0xFFEFF2F5);
  final Color colPrimary = const Color(0xFF127D95);
  final Color colTextDark = const Color(0xFF2D3436);
  final Color colTextLight = const Color(0xFF636E72);

  List<Map<String, dynamic>> _allPurchases = []; // Master list
  List<Map<String, dynamic>> _filteredList = []; // Display list
  bool _isLoading = true;

  // --- Filters ---
  String _searchQuery = "";
  int _selectedFilter = 0; // 0: All, 1: Today, 2: Weekly, 3: Monthly, 4: Custom
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    // FIX: Updated method name to match new DB Helper
    final data = await DatabaseHelper.instance.getAllPurchasesWithSupplier();
    setState(() {
      _allPurchases = data;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = _allPurchases;
    DateTime now = DateTime.now();

    // 1. Apply Date Filter
    if (_selectedFilter == 1) {
      // Today
      temp = temp.where((item) {
        // FIX: Use 'purchased_date' instead of 'created_at'
        DateTime dt = DateTime.parse(item['purchased_date']);
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      }).toList();
    } else if (_selectedFilter == 2) {
      // Weekly (Last 7 Days)
      DateTime weekAgo = now.subtract(const Duration(days: 7));
      temp = temp.where((item) {
        DateTime dt = DateTime.parse(item['purchased_date']);
        return dt.isAfter(weekAgo);
      }).toList();
    } else if (_selectedFilter == 3) {
      // Monthly (This Month)
      temp = temp.where((item) {
        DateTime dt = DateTime.parse(item['purchased_date']);
        return dt.year == now.year && dt.month == now.month;
      }).toList();
    } else if (_selectedFilter == 4 && _customDateRange != null) {
      // Custom Range
      temp = temp.where((item) {
        DateTime dt = DateTime.parse(item['purchased_date']);
        return dt.isAfter(
              _customDateRange!.start.subtract(const Duration(seconds: 1)),
            ) &&
            dt.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // 2. Apply Search
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((item) {
        String vendor = (item['vendor_name'] ?? "").toLowerCase();
        // FIX: Replaced 'item' search with ID search since 'item' column is gone
        String billId = item['id'].toString();
        String q = _searchQuery.toLowerCase();
        return vendor.contains(q) || billId.contains(q);
      }).toList();
    }

    setState(() {
      _filteredList = temp;
    });
  }

  // --- Date Picker Logic ---
  Future<void> _pickCustomDate() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: colPrimary,
            colorScheme: ColorScheme.light(primary: colPrimary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = 4; // Set to Custom
        _applyFilters();
      });
    }
  }

  // --- Payment Dialog Logic ---
  Future<void> _showPaymentDialog(Map<String, dynamic> purchase) async {
    // FIX: Use 'final_amount' (Net Total) instead of 'tot_amount'
    int total = purchase['final_amount'] ?? 0;
    int paid = purchase['paid'] ?? 0;
    int balance = total - paid;
    TextEditingController payCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pay Balance"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Vendor: ${purchase['vendor_name'] ?? 'Unknown'}",
              style: TextStyle(fontSize: 14, color: colTextLight),
            ),
            const SizedBox(height: 5),
            Text(
              "Pending: ₹${FunctionsHelper.format_int(balance)}",
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: payCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Enter Amount",
                border: OutlineInputBorder(),
                prefixText: "₹ ",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colPrimary),
            onPressed: () async {
              if (payCtrl.text.isNotEmpty) {
                int amount = int.parse(payCtrl.text);
                if (amount > balance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Amount exceeds balance")),
                  );
                  return;
                }

                await DatabaseHelper.instance.updatePurchasePayment(
                  purchase['id'],
                  paid + amount,
                );
                Navigator.pop(ctx);
                _loadAllData(); // Refresh list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Payment Updated!")),
                );
              }
            },
            child: const Text("PAY", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          "All Purchases",
          style: TextStyle(color: colTextDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _selectedFilter == 4 ? colPrimary : colTextDark,
            ),
            onPressed: _pickCustomDate,
            tooltip: "Custom Date Filter",
          ),
        ],
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: "Search Vendor or Bill ID...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
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

          // --- FILTER CHIPS ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip("All", 0),
                const SizedBox(width: 8),
                _buildFilterChip("Today", 1),
                const SizedBox(width: 8),
                _buildFilterChip("Weekly", 2),
                const SizedBox(width: 8),
                _buildFilterChip("Monthly", 3),
                if (_selectedFilter == 4 && _customDateRange != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      "${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}",
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: colPrimary,
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedFilter = 0;
                        _customDateRange = null;
                        _applyFilters();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          // --- LIST ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredList.isEmpty
                ? Center(
                    child: Text(
                      "No records found",
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return PurchaseBillDetailsScreen(
                                  purchaseData: item,
                                );
                              },
                            ),
                          );
                        },
                        child: _buildListItem(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    bool isSelected = _selectedFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = index;
          _applyFilters();
        });
      },
      selectedColor: colPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colTextDark,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    // FIX: Using final_amount for Net Total
    int total = item['final_amount'] ?? 0;
    int paid = item['paid'] ?? 0;
    int balance = total - paid;
    bool isDue = balance > 0;

    // Visuals
    Color iconBg = isDue ? const Color(0xFFFFECD1) : const Color(0xFFD8F3DC);
    Color iconColor = isDue ? Colors.orange : Colors.green;
    IconData iconData = isDue ? Icons.access_time_filled : Icons.check_circle;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
          // Icon
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),

          // Info
          Container(
            width: MediaQuery.of(context).size.width * 0.5,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIX: Changed "Item Name" to "Bill #ID"
                  Text(
                    "Bill #${item['id']}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // FIX: Use purchased_date
                  Text(
                    "${item['vendor_name']} • ${DateFormat('dd MMM yyyy').format(DateTime.parse(item['purchased_date']))}",
                    style: TextStyle(fontSize: 12, color: colTextLight),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        "Total: ₹${FunctionsHelper.format_int(total)}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colTextLight,
                        ),
                      ),
                      if (isDue) ...[
                        const SizedBox(width: 8),
                        Text(
                          "Bal: ₹${FunctionsHelper.format_int(balance)}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Pay Button (Only if Due)
          if (isDue)
            SizedBox(
              height: 32,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => _showPaymentDialog(item),
                child: Text(
                  "PAY",
                  style: TextStyle(
                    color: colTextDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          if (!isDue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "PAID",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
