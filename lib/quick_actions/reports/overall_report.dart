import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/theme_provider.dart';

class OverallReportScreen extends StatefulWidget {
  const OverallReportScreen({super.key});

  @override
  State<OverallReportScreen> createState() => _OverallReportScreenState();
}

class _OverallReportScreenState extends State<OverallReportScreen> {
  // --- State Variables ---
  int _selectedTab = 0; // 0: Daily, 1: Weekly, 2: Monthly
  bool _isLoading = true;
  DateTimeRange? _customDateRange;

  // Analytics Data
  double _totalRevenue = 0;
  int _totalItemsSold = 0;

  // Chart Data
  List<FlSpot> _chartSpots = [];
  double _maxY = 0;
  List<String> _chartBottomTitles = [];
  double _chartMaxX = 0; // Dynamic X-axis length

  // Lists
  List<Map<String, dynamic>> _topItems = [];
  List<Map<String, dynamic>> _allTopItems = [];
  List<Map<String, dynamic>> _recentTransactions = [];

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
      // Custom Filter
      startDate = _customDateRange!.start;
      endDate = _customDateRange!.end
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
    } else {
      // Tab Selection
      switch (_selectedTab) {
        case 0: // Daily (Today)
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 1: // Weekly (Last 7 Days)
          startDate = now.subtract(const Duration(days: 6));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 2: // Monthly (This Month)
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = now;
      }
    }

    String startStr = startDate.toIso8601String();
    String endStr = endDate.toIso8601String();

    // 2. Fetch Totals
    final revenueRes = await db.rawQuery(
      '''
      SELECT SUM(final_amount) as total 
      FROM sales 
      WHERE billed_date >= ? AND billed_date <= ?
    ''',
      [startStr, endStr],
    );

    final itemsRes = await db.rawQuery(
      '''
      SELECT SUM(i.qty) as total_qty 
      FROM stock_sales_items i
      JOIN sales s ON i.sales_id = s.id
      WHERE s.billed_date >= ? AND s.billed_date <= ?
    ''',
      [startStr, endStr],
    );

    _totalRevenue = (revenueRes.first['total'] as num?)?.toDouble() ?? 0.0;
    _totalItemsSold = (itemsRes.first['total_qty'] as num?)?.toInt() ?? 0;

    // 3. Fetch Chart Data
    final chartRes = await db.rawQuery(
      '''
      SELECT billed_date, final_amount 
      FROM sales 
      WHERE billed_date >= ? AND billed_date <= ?
      ORDER BY billed_date ASC
    ''',
      [startStr, endStr],
    );

    // Pass 'endDate' as 'now' parameter for custom range calculation
    _processChartData(
      chartRes,
      startDate,
      _customDateRange != null ? endDate : now,
    );

    // 4. Fetch Top Selling Items
    _allTopItems = await db.rawQuery(
      '''
      SELECT i.item_name, SUM(i.qty) as sold, SUM(i.amount) as revenue
      FROM stock_sales_items i
      JOIN sales s ON i.sales_id = s.id
      WHERE s.billed_date >= ? AND s.billed_date <= ?
      GROUP BY i.item_name
      ORDER BY sold DESC
    ''',
      [startStr, endStr],
    );

    _topItems = _allTopItems.take(5).toList();

    // 5. Fetch Recent Transactions (FIX: LIMIT 5)
    _recentTransactions = await db.rawQuery(
      '''
      SELECT s.id, s.is_stock_sales, s.final_amount, s.billed_date, c.name as cust_name
      FROM sales s
      LEFT JOIN customer c ON s.customer_id = c.id
      WHERE s.billed_date >= ? AND s.billed_date <= ?
      ORDER BY s.billed_date DESC
      LIMIT 5
    ''',
      [startStr, endStr],
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- FIX: Updated Chart Logic ---
  void _processChartData(
    List<Map<String, dynamic>> data,
    DateTime start,
    DateTime end, // Changed 'now' to 'end' to better reflect range end
  ) {
    Map<int, double> groupedData = {};
    _chartBottomTitles = [];
    _chartSpots = [];
    _maxY = 0;

    // --- CASE 0: DAILY (TODAY) ---
    if (_selectedTab == 0) {
      _chartMaxX = 23;
      for (int i = 0; i <= 23; i += 1) _chartBottomTitles.add(i.toString());
      for (int i = 0; i < 24; i++) groupedData[i] = 0;

      for (var row in data) {
        DateTime dt = DateTime.parse(row['billed_date']);
        groupedData[dt.hour] =
            (groupedData[dt.hour] ?? 0) +
            (row['final_amount'] as num).toDouble();
      }
    }
    // --- CASE 1: WEEKLY ---
    else if (_selectedTab == 1) {
      _chartMaxX = 6;
      for (int i = 0; i < 7; i++) {
        DateTime d = start.add(Duration(days: i));
        _chartBottomTitles.add(DateFormat('E').format(d));
        groupedData[i] = 0;
      }

      for (var row in data) {
        DateTime dt = DateTime.parse(row['billed_date']);
        DateTime dtDate = DateTime(dt.year, dt.month, dt.day);
        DateTime startDate = DateTime(start.year, start.month, start.day);

        int dayIndex = dtDate.difference(startDate).inDays;
        if (dayIndex >= 0 && dayIndex < 7) {
          groupedData[dayIndex] =
              (groupedData[dayIndex] ?? 0) +
              (row['final_amount'] as num).toDouble();
        }
      }
    }
    // --- CASE 2: MONTHLY ---
    else if (_selectedTab == 2) {
      int daysInMonth = DateTime(start.year, start.month + 1, 0).day;
      _chartMaxX = (daysInMonth - 1).toDouble();

      for (int i = 1; i <= daysInMonth; i++) {
        if (i == 1 || i % 5 == 0) {
          _chartBottomTitles.add(i.toString());
        } else {
          _chartBottomTitles.add("");
        }
        groupedData[i - 1] = 0;
      }

      for (var row in data) {
        DateTime dt = DateTime.parse(row['billed_date']);
        int dayOfMonth = dt.day;
        int index = dayOfMonth - 1;
        groupedData[index] =
            (groupedData[index] ?? 0) + (row['final_amount'] as num).toDouble();
      }
    }
    // --- CASE: CUSTOM DATE RANGE (OVERALL REPORT) ---
    else {
      // Calculate total days in custom range
      int totalDays = end.difference(start).inDays + 1;
      if (totalDays < 1) totalDays = 1; // Safety check

      _chartMaxX = (totalDays - 1).toDouble();

      // Dynamic Labels: if range is large, show fewer labels
      int labelInterval = (totalDays > 10) ? (totalDays / 5).ceil() : 1;

      for (int i = 0; i < totalDays; i++) {
        DateTime d = start.add(Duration(days: i));
        groupedData[i] = 0;

        // Show labels sparingly for clarity
        if (i == 0 || i == totalDays - 1 || i % labelInterval == 0) {
          _chartBottomTitles.add(DateFormat('dd/MM').format(d));
        } else {
          _chartBottomTitles.add("");
        }
      }

      // Fill Data
      for (var row in data) {
        DateTime dt = DateTime.parse(row['billed_date']);
        DateTime dtDate = DateTime(dt.year, dt.month, dt.day);
        DateTime startDate = DateTime(start.year, start.month, start.day);

        int dayIndex = dtDate.difference(startDate).inDays;

        if (dayIndex >= 0 && dayIndex < totalDays) {
          groupedData[dayIndex] =
              (groupedData[dayIndex] ?? 0) +
              (row['final_amount'] as num).toDouble();
        }
      }
    }

    // Convert to Spots
    groupedData.forEach((key, value) {
      if (value > _maxY) _maxY = value;
      _chartSpots.add(FlSpot(key.toDouble(), value));
    });

    if (_maxY == 0) _maxY = 100;
    _maxY = _maxY * 1.2;
  }

  // --- Date Picker Dialog ---
  Future<void> _showDateFilter() async {
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
        _customDateRange = picked;
        _selectedTab = -1; // Unselect tabs to trigger Custom Logic
      });
      _loadData();
    }
  }

  // --- View All Items Bottom Sheet ---
  void _showAllTopItems() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "All Selling Items",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _allTopItems.length,
                  itemBuilder: (context, index) {
                    final item = _allTopItems[index];
                    return ListTile(
                      title: Text(
                        item['item_name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Sold: ${FunctionsHelper.format_int(item['sold'])}",
                      ),
                      trailing: Text(
                        "₹${FunctionsHelper.format_double(item['revenue'].toStringAsFixed(2))}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  late Color bgColor;
  late Color primaryText;
  late Color secondaryText;
  late Color accentColor;
  late Color cardColor;

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
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Overall Sale Report",
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
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

                  // --- 1. TABS ---
                  _buildTabs(),
                  const SizedBox(height: 20),

                  // --- 2. METRIC CARDS ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: "REVENUE",
                          value:
                              "₹${FunctionsHelper.format_double(_totalRevenue.toStringAsFixed(0))}",
                          icon: Icons.attach_money,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          title: "ITEMS SOLD",
                          value:
                              "${FunctionsHelper.format_int(_totalItemsSold)}",
                          icon: Icons.inventory_2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 3. CHART ---
                  _buildChartCard(),
                  const SizedBox(height: 20),

                  // --- 4. TOP SELLING ITEMS ---
                  _buildTopItemsList(),
                  const SizedBox(height: 20),

                  // --- 5. RECENT TRANSACTIONS ---
                  _buildRecentTransactions(),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS ---

  Widget _buildTabs() {
    final List<String> tabs = ["Daily", "Weekly", "Monthly"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(tabs.length, (index) {
        bool isActive = _selectedTab == index;
        return InkWell(
          onTap: () {
            setState(() {
              _selectedTab = index;
              _customDateRange = null;
            });
            _loadData();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? accentColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: isActive ? null : Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              tabs[index],
              style: TextStyle(
                color: isActive ? Colors.white : secondaryText,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      }),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    // Dynamic Label Logic
    String periodText = "Today";
    if (_selectedTab == 1) periodText = "Last 7 Days";
    if (_selectedTab == 2) periodText = "This Month";
    if (_customDateRange != null) periodText = "Custom Range";

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sales Trend",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              Text(
                periodText,
                style: TextStyle(fontSize: 12, color: secondaryText),
              ),
            ],
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
                        // Only show valid indices from our generated titles list
                        if (idx >= 0 && idx < _chartBottomTitles.length) {
                          return Text(
                            _chartBottomTitles[idx],
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 10,
                            ),
                          );
                        }
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
                    color: accentColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: accentColor.withOpacity(0.1),
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

  Widget _buildTopItemsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Top Selling Items",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              TextButton(
                onPressed: _showAllTopItems,
                child: Text(
                  "View All",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _topItems.isEmpty
              ? Text(
                  "No items sold yet",
                  style: TextStyle(color: secondaryText),
                )
              : Column(
                  children: _topItems.map((item) {
                    double revenue = (item['revenue'] as num).toDouble();
                    double maxRev = (_topItems[0]['revenue'] as num).toDouble();
                    double progress = maxRev > 0 ? revenue / maxRev : 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['item_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "₹${FunctionsHelper.format_double(revenue.toStringAsFixed(0))}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${item['sold']} units sold",
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // --- FIX: Progress Bar Overflow ---
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 6,
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  Container(color: bgColor),
                                  FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // --- END FIX ---
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Transactions",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 16),
          _recentTransactions.isEmpty
              ? Text(
                  "No transactions yet",
                  style: TextStyle(color: secondaryText),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentTransactions.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final sale = _recentTransactions[index];
                    String dateStr = DateFormat(
                      "dd MMM",
                    ).format(DateTime.parse(sale['billed_date']));
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: bgColor,
                          radius: 20,
                          child: Icon(
                            Icons.receipt,
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
                                sale['cust_name'] ?? "Unknown",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "Bill ${sale["is_stock_sales"] == 1 ? "S" : "Q"}${sale['id']} • $dateStr",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "+ ₹${FunctionsHelper.format_int(sale['final_amount'])}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
