import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selldroid/helpers/database_helper.dart';

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  // --- CUSTOM COLOR THEME ---
  static const Color bgColor = Color.fromARGB(255, 244, 242, 242);
  static const Color primaryText = Color.fromARGB(255, 70, 73, 76);
  static const Color secondaryText = Color.fromARGB(255, 76, 92, 104);
  static const Color accentColor = Color.fromARGB(255, 25, 133, 161);
  static const Color cardColor = Colors.white;

  // --- State Variables ---
  int _selectedTab = 0; // 0: Daily, 1: Weekly, 2: Monthly
  bool _isLoading = true;
  DateTimeRange? _customDateRange;

  // Analytics Data
  double _totalExpenses = 0;
  int _totalTransactions = 0;

  // Chart Data
  List<FlSpot> _chartSpots = [];
  double _maxY = 0;
  List<String> _chartBottomTitles = [];
  double _chartMaxX = 0;

  // Lists
  List<Map<String, dynamic>> _topCategories = [];
  List<Map<String, dynamic>> _recentExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- Data Loading Logic ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // 1. Determine Date Range
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    if (_customDateRange != null) {
      startDate = _customDateRange!.start;
      endDate = _customDateRange!.end
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
    } else {
      switch (_selectedTab) {
        case 0: // Daily
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 1: // Weekly
          startDate = now.subtract(const Duration(days: 6));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 2: // Monthly
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = now;
      }
    }

    String startStr = startDate.toIso8601String();
    String endStr = endDate.toIso8601String();

    // 2. Fetch Totals
    final totalRes = await db.rawQuery(
      '''
      SELECT SUM(amount) as total, COUNT(id) as count 
      FROM expenses 
      WHERE date >= ? AND date <= ?
    ''',
      [startStr, endStr],
    );

    _totalExpenses = (totalRes.first['total'] as num?)?.toDouble() ?? 0.0;
    _totalTransactions = (totalRes.first['count'] as num?)?.toInt() ?? 0;

    // 3. Fetch Chart Data (Expenses Trend)
    final chartRes = await db.rawQuery(
      '''
      SELECT date, amount 
      FROM expenses 
      WHERE date >= ? AND date <= ?
      ORDER BY date ASC
    ''',
      [startStr, endStr],
    );

    _processChartData(
      chartRes,
      startDate,
      _customDateRange != null ? endDate : now,
    );

    // 4. Fetch Top Categories
    _topCategories = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total_spent, COUNT(id) as tx_count
      FROM expenses
      WHERE date >= ? AND date <= ?
      GROUP BY category
      ORDER BY total_spent DESC
      LIMIT 5
    ''',
      [startStr, endStr],
    );

    // 5. Fetch Recent Expenses
    _recentExpenses = await db.rawQuery(
      '''
      SELECT id, category, description, amount, date
      FROM expenses
      WHERE date >= ? AND date <= ?
      ORDER BY date DESC
      LIMIT 10
    ''',
      [startStr, endStr],
    );

    if (mounted) setState(() => _isLoading = false);
  }

  // --- Chart Logic ---
  void _processChartData(
    List<Map<String, dynamic>> data,
    DateTime start,
    DateTime end,
  ) {
    Map<int, double> groupedData = {};
    _chartBottomTitles = [];
    _chartSpots = [];
    _maxY = 0;

    if (_selectedTab == 0) {
      _chartMaxX = 23;
      for (int i = 0; i <= 23; i += 1) _chartBottomTitles.add(i.toString());
      for (int i = 0; i < 24; i++) groupedData[i] = 0;
      for (var row in data) {
        DateTime dt = DateTime.parse(row['date']);
        groupedData[dt.hour] =
            (groupedData[dt.hour] ?? 0) + (row['amount'] as num).toDouble();
      }
    } else if (_selectedTab == 1) {
      _chartMaxX = 6;
      for (int i = 0; i < 7; i++) {
        DateTime d = start.add(Duration(days: i));
        _chartBottomTitles.add(DateFormat('E').format(d));
        groupedData[i] = 0;
      }
      for (var row in data) {
        DateTime dt = DateTime.parse(row['date']);
        int dayIndex = DateTime(
          dt.year,
          dt.month,
          dt.day,
        ).difference(DateTime(start.year, start.month, start.day)).inDays;
        if (dayIndex >= 0 && dayIndex < 7)
          groupedData[dayIndex] =
              (groupedData[dayIndex] ?? 0) + (row['amount'] as num).toDouble();
      }
    } else {
      int totalDays = end.difference(start).inDays + 1;
      _chartMaxX = (totalDays - 1).toDouble();
      int interval = (totalDays / 5).ceil();
      for (int i = 0; i < totalDays; i++) {
        _chartBottomTitles.add(
          i % interval == 0
              ? DateFormat('dd').format(start.add(Duration(days: i)))
              : "",
        );
        groupedData[i] = 0;
      }
      for (var row in data) {
        DateTime dt = DateTime.parse(row['date']);
        int dayIndex = DateTime(
          dt.year,
          dt.month,
          dt.day,
        ).difference(DateTime(start.year, start.month, start.day)).inDays;
        if (dayIndex >= 0 && dayIndex < totalDays)
          groupedData[dayIndex] =
              (groupedData[dayIndex] ?? 0) + (row['amount'] as num).toDouble();
      }
    }

    groupedData.forEach((key, value) {
      if (value > _maxY) _maxY = value;
      _chartSpots.add(FlSpot(key.toDouble(), value));
    });
    if (_maxY == 0) _maxY = 100;
    _maxY = _maxY * 1.2;
  }

  // --- Date Picker ---
  Future<void> _showDateFilter() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: accentColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedTab = -1;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: primaryText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Expense Reports",
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _customDateRange != null ? accentColor : secondaryText,
            ),
            onPressed: _showDateFilter,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_customDateRange != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Chip(
                        label: Text(
                          "${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}",
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: accentColor,
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                        onDeleted: () {
                          setState(() {
                            _customDateRange = null;
                            _selectedTab = 0;
                          });
                          _loadData();
                        },
                      ),
                    ),

                  // 1. TABS
                  _buildTabs(),
                  const SizedBox(height: 20),

                  // 2. METRICS
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: "TOTAL SPENT",
                          value: "₹${_totalExpenses.toStringAsFixed(0)}",
                          icon: Icons.money_off,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          title: "TRANSACTIONS",
                          value: "$_totalTransactions",
                          icon: Icons.receipt_long,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. CHART
                  _buildChartCard(),
                  const SizedBox(height: 20),

                  // 4. TOP CATEGORIES
                  _buildTopCategoriesList(),
                  const SizedBox(height: 20),

                  // 5. RECENT LIST
                  _buildRecentExpenses(),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS ---

  Widget _buildTabs() {
    final List<String> tabs = ["Today", "Weekly", "Monthly"];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          bool isActive = _selectedTab == index;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTab = index;
                  _customDateRange = null;
                });
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : secondaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: secondaryText),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Spending Trend",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.70,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx >= 0 &&
                            idx < _chartBottomTitles.length &&
                            _chartBottomTitles[idx].isNotEmpty)
                          return Text(
                            _chartBottomTitles[idx],
                            style: const TextStyle(
                              color: secondaryText,
                              fontSize: 10,
                            ),
                          );
                        return const Text("");
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: _chartMaxX,
                minY: 0,
                maxY: _maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartSpots,
                    isCurved: true,
                    color: Colors.redAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.redAccent.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoriesList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Top Categories",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 16),
          _topCategories.isEmpty
              ? const Text(
                  "No expenses recorded",
                  style: TextStyle(color: secondaryText),
                )
              : Column(
                  children: _topCategories.map((item) {
                    double total = (item['total_spent'] as num).toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['category'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${item['tx_count']} transactions",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "₹${total.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildRecentExpenses() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Expenses",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 16),
          _recentExpenses.isEmpty
              ? const Text(
                  "No expenses yet",
                  style: TextStyle(color: secondaryText),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentExpenses.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final expense = _recentExpenses[index];
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: bgColor,
                          radius: 20,
                          child: const Icon(
                            Icons.category,
                            size: 18,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense['description'] ?? expense['category'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'dd MMM',
                                ).format(DateTime.parse(expense['date'])),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "- ₹${expense['amount']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }
}
