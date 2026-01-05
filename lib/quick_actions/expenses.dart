import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/show_dialog_boxes.dart';
import 'package:selldroid/theme_provider.dart'; // Ensure this path is correct for your Expense model

// --- YOUR EXPENSE MODEL (Pasted here for reference, or import it) ---

// ------------------------------------------------------------------

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // --- Controllers ---
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  // --- State ---
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _selectedCategory = "Other";
  DateTime _selectedDate = DateTime.now();

  List<ExpenseType> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  // --- Load Data ---
  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // Ensure 'expenses' table exists in DatabaseHelper
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      orderBy: 'date DESC',
    );
    _categories = await DatabaseHelper.instance.getAllExpenseTypes();
    if (mounted) {
      setState(() {
        _expenses = List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
        _isLoading = false;
      });
    }
  }

  // --- Add Expense ---
  Future<void> _addExpense() async {
    if (_amountCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter Amount")));
      return;
    }

    // UPDATED: Parsing INT for amount
    int amount = int.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) return;

    Expense newExpense = Expense(
      category: _selectedCategory,
      date: _selectedDate.toIso8601String(),
      description: _descCtrl.text.trim().isEmpty
          ? _selectedCategory
          : _descCtrl.text.trim(),
      amount: amount,
    );

    final db = await DatabaseHelper.instance.database;
    await db.insert('expenses', newExpense.toMap());

    _amountCtrl.clear();
    _descCtrl.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedCategory = "Other";
    });

    FocusScope.of(context).unfocus();
    _loadExpenses();

    ShowDialogBoxes.showAutoCloseSuccessDialog(
      context: context,
      message: "Expense Added",
    );
  }

  // --- Delete Expense ---
  Future<void> _deleteExpense(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    _loadExpenses();
  }

  // --- Date Picker ---
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  late Color bgColor;
  late Color primaryText;
  late Color secondaryText;
  late Color accentColor;
  late Color cardColor;
  late Color inputFill;
  @override
  Widget build(BuildContext context) {
    // UPDATED: Calculations using int
    int totalExpense = _expenses.fold(0, (sum, item) => sum + item.amount);
    final theme = context.watch<ThemeProvider>();
    bgColor = theme.bgColor;
    primaryText = theme.primaryText;
    secondaryText = theme.secondaryText;
    accentColor = theme.accentColor;
    cardColor = theme.cardColor;
    inputFill = const Color(0xFFF3F4F6);
    DateTime now = DateTime.now();
    int monthlyExpense = _expenses
        .where((e) {
          try {
            DateTime dt = DateTime.parse(e.date);
            return dt.month == now.month && dt.year == now.year;
          } catch (e) {
            return false;
          }
        })
        .fold(0, (sum, item) => sum + item.amount);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Expenses",
          style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryText),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. DASHBOARD ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      "Total Expenses",
                      totalExpense,
                      accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      "This Month",
                      monthlyExpense,
                      Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. ADD FORM ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add New Expense",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Row 1: Category & Date
                  Row(
                    children: [
                      // Category Dropdown
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              value: _selectedCategory,
                              isExpanded: true,
                              items: _categories
                                  .map((e) {
                                    return e.type;
                                  })
                                  .toList()
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCategory = val!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Date Picker Button
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: _pickDate,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: inputFill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              DateFormat('dd MMM').format(_selectedDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Description & Amount
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _descCtrl,
                          decoration: InputDecoration(
                            hintText: "Description (Optional)",
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "₹ 0",
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _addExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Save Expense",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. RECENT LIST HEADER ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recent History",
                  style: TextStyle(
                    color: secondaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // --- 4. EXPENSE LIST ---
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )
                : _expenses.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      "No expenses yet",
                      style: TextStyle(color: secondaryText),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    itemCount: _expenses.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _expenses[index];
                      String dateStr = "";
                      try {
                        dateStr = DateFormat(
                          "dd MMM, yyyy",
                        ).format(DateTime.parse(item.date));
                      } catch (e) {
                        dateStr = item.date;
                      }

                      return Dismissible(
                        key: Key(item.id.toString()),
                        direction: DismissDirection.endToStart,
                        onDismissed: (dir) => _deleteExpense(item.id!),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: inputFill,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _getCategoryIcon(item.category),
                              ),
                              const SizedBox(width: 16),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.category,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "- ₹${FunctionsHelper.num_format.format(item.amount)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _buildSummaryCard(String title, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "₹${FunctionsHelper.num_format.format(amount)}",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCategoryIcon(String category) {
    IconData icon;
    switch (category) {
      case "Rent":
        icon = Icons.home;
        break;
      case "Salary":
        icon = Icons.people;
        break;
      case "Electricity":
        icon = Icons.electrical_services;
        break;
      case "Tea/Snacks":
        icon = Icons.coffee;
        break;
      case "Transport":
        icon = Icons.directions_bus;
        break;
      case "Maintenance":
        icon = Icons.build;
        break;
      default:
        icon = Icons.receipt_long;
    }
    return Icon(icon, color: secondaryText, size: 20);
  }
}
