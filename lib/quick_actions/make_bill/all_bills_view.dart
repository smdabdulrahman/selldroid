import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/quick_actions/make_bill/bill_view.dart';
import 'package:selldroid/theme_provider.dart';
// Optional: Import PDF Generator if you want to reprint
// import 'package:selldroid/helpers/pdf_generator.dart';

class AllBillsScreen extends StatefulWidget {
  const AllBillsScreen({super.key});

  @override
  State<AllBillsScreen> createState() => _AllBillsScreenState();
}

class _AllBillsScreenState extends State<AllBillsScreen> {
  static NumberFormat num_format = NumberFormat.decimalPattern("en_IN");
  // --- State ---
  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  bool _isLoading = true;

  // --- Filters ---
  String _searchQuery = "";
  int _selectedFilter = 0; // 0: All, 1: Today, 2: Weekly, 3: Monthly, 4: Custom
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllSalesWithCustomer();
    setState(() {
      _allSales = data;
      _applyFilters();
      _isLoading = false;
    });
  }

  // --- Logic: Apply Search & Date Filters ---
  void _applyFilters() {
    List<Map<String, dynamic>> temp = _allSales;
    DateTime now = DateTime.now();

    // 1. Date Filter
    if (_selectedFilter == 1) {
      // Today
      temp = temp.where((s) {
        DateTime dt = DateTime.parse(s['billed_date']);
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      }).toList();
    } else if (_selectedFilter == 2) {
      // Weekly (Last 7 Days)
      DateTime weekAgo = now.subtract(const Duration(days: 7));
      temp = temp.where((s) {
        DateTime dt = DateTime.parse(s['billed_date']);
        return dt.isAfter(weekAgo);
      }).toList();
    } else if (_selectedFilter == 3) {
      // Monthly (This Month)
      temp = temp.where((s) {
        DateTime dt = DateTime.parse(s['billed_date']);
        return dt.year == now.year && dt.month == now.month;
      }).toList();
    } else if (_selectedFilter == 4 && _customDateRange != null) {
      // Custom Range
      temp = temp.where((s) {
        DateTime dt = DateTime.parse(s['billed_date']);
        return dt.isAfter(
              _customDateRange!.start.subtract(const Duration(seconds: 1)),
            ) &&
            dt.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // 2. Search Filter (Bill ID or Customer Name)
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((s) {
        String id = s['id'].toString();
        String name = (s['cust_name'] ?? "").toLowerCase();
        String q = _searchQuery.toLowerCase();
        return id.contains(q) || name.contains(q);
      }).toList();
    }

    setState(() {
      _filteredSales = temp;
    });
  }

  Future<void> _pickCustomDate(ThemeProvider theme) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: theme.accentColor,
            colorScheme: ColorScheme.light(primary: theme.accentColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = 4;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    // Calculate Totals for the current view
    double totalRevenue = _filteredSales.fold(
      0,
      (sum, item) => sum + (item['final_amount'] as num),
    );

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
          "Sales History",
          style: TextStyle(
            color: theme.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month_outlined,
              color: _selectedFilter == 4
                  ? theme.accentColor
                  : theme.primaryText,
            ),
            onPressed: () => _pickCustomDate(theme),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 1. SUMMARY CARD ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.accentColor, theme.accentColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withOpacity(0.3),
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
                    const Text(
                      "Total Sales",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹${num_format.format(totalRevenue)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // --- 2. SEARCH ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: "Search Bill # or Customer...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- 3. FILTER TABS ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip("All", 0, theme),
                const SizedBox(width: 8),
                _buildFilterChip("Today", 1, theme),
                const SizedBox(width: 8),
                _buildFilterChip("Weekly", 2, theme),
                const SizedBox(width: 8),
                _buildFilterChip("Monthly", 3, theme),
                if (_selectedFilter == 4 && _customDateRange != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      "${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: theme.accentColor,
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
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
          const SizedBox(height: 8),

          // --- 4. LIST VIEW ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSales.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSales.length,
                    itemBuilder: (context, index) {
                      return _buildBillCard(_filteredSales[index], theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, ThemeProvider theme) {
    bool isSelected = _selectedFilter == index;
    return ChoiceChip(
      checkmarkColor: Colors.white,
      showCheckmark: false,
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = index;
          _applyFilters();
        });
      },
      selectedColor: theme.accentColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.primaryText,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> sale, ThemeProvider theme) {
    String dateStr = DateFormat(
      'dd MMM yyyy • hh:mm a',
    ).format(DateTime.parse(sale['billed_date']));
    String customer = sale['cust_name'] ?? "Walk-in Customer";

    // Status Logic
    int total = sale['final_amount'];
    int paid = sale['paid'] ?? total; // Fallback if null
    int balance = total - paid;
    bool isUnpaid = balance > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Bill No & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "#${sale['id']}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.secondaryText,
                  ),
                ),
              ),
              Text(
                "₹${num_format.format(total)}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer & Date
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Footer: Status & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Payment Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isUnpaid
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUnpaid ? "Unpaid (Bal: ₹$balance)" : "Paid",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUnpaid ? Colors.red : Colors.green,
                  ),
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  // Print Button
                  const SizedBox(width: 8),
                  // Details Button
                  InkWell(
                    onTap: () {
                      // Navigate to Details Screen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) {
                            return BillDetailsScreen(saleData: sale);
                          },
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.accentColor.withOpacity(0.1),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: theme.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No bills found",
            style: TextStyle(color: theme.secondaryText, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
