import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';

import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/theme_provider.dart';

class ExpenseCategoriesScreen extends StatefulWidget {
  const ExpenseCategoriesScreen({super.key});

  @override
  State<ExpenseCategoriesScreen> createState() =>
      _ExpenseCategoriesScreenState();
}

class _ExpenseCategoriesScreenState extends State<ExpenseCategoriesScreen> {
  // Using your specific Model
  List<ExpenseType> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllExpenseTypes();
    setState(() {
      _categories = data;
      _isLoading = false;
    });
  }

  // --- Logic to Add ---
  Future<void> _addCategory(String typeName) async {
    if (typeName.trim().isEmpty) return;

    // Create your model object
    ExpenseType newType = ExpenseType(type: typeName.trim());

    // Save to DB
    await DatabaseHelper.instance.addExpenseType(newType);

    // Refresh UI
    _loadData();
  }

  // --- Logic to Delete ---
  Future<void> _deleteCategory(int id) async {
    await DatabaseHelper.instance.deleteExpenseType(id);
    _loadData();
  }

  // --- UI: Show Dialog ---
  void _showAddDialog(ThemeProvider theme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("New Expense Type"),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "e.g., Shop Rent, Tea, Salary",
              border: OutlineInputBorder(),
              filled: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
              ),
              onPressed: () {
                _addCategory(controller.text);
                Navigator.pop(context);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      appBar: AppBar(
        title: const Text(
          "Expense Categories",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(theme),
        backgroundColor: theme.accentColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add New", style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    "No Expense Types Added",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _categories[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange[50],
                      child: Text(
                        item.type.isNotEmpty ? item.type[0].toUpperCase() : "?",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      item.type,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
