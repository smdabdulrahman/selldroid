import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';

import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/theme_provider.dart';

class CashModesScreen extends StatefulWidget {
  const CashModesScreen({super.key});

  @override
  State<CashModesScreen> createState() => _CashModesScreenState();
}

class _CashModesScreenState extends State<CashModesScreen> {
  List<CashMode> _modes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllCashModes();
    setState(() {
      _modes = data;
      _isLoading = false;
    });
  }

  // --- Logic to Add ---
  Future<void> _addMode(String name) async {
    if (name.trim().isEmpty) return;

    CashMode newMode = CashMode(modeName: name.trim());
    await DatabaseHelper.instance.addCashMode(newMode);
    _loadData(); // Refresh List
  }

  // --- Logic to Delete ---
  Future<void> _deleteMode(int id) async {
    await DatabaseHelper.instance.deleteCashMode(id);
    _loadData();
  }

  // --- Show Add Dialog ---
  void _showAddDialog(ThemeProvider theme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("New Payment Mode"),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "e.g., GPay, PhonePe, Card",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payment),
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
                _addMode(controller.text);
                Navigator.pop(context);
              },
              child: const Text("Add", style: TextStyle(color: Colors.white)),
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
          "Payment Modes",
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
        label: const Text("Add Mode", style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _modes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "No Payment Modes Found",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _modes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _modes[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[50],
                      child: const Icon(Icons.credit_card, color: Colors.green),
                    ),
                    title: Text(
                      item.modeName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
