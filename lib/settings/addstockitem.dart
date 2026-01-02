import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/models/stock_item.dart';
import 'package:selldroid/settings/manage_stock.dart';
// import '../../models/preference_model.dart'; // Ensure this import is correct for your project structure

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _qtyController = TextEditingController();
  // Removed _gstController

  // --- NEW: Tax State Variables ---
  double _selectedIgst = 0;
  double _selectedCgst = 0;
  double _selectedSgst = 0;

  // --- NEW: Tax Rate Lists ---
  final List<double> _igstRates = [0, 5, 12, 18, 28];
  final List<double> _stateGstRates = [0, 2.5, 6, 9, 14];

  // State
  bool _manageStock = false;
  bool _isLoading = true;
  List<StockItem> _stockList = [];

  // Colors
  static const Color bgColor = Color(0xFFE8ECEF);
  static const Color cardColor = Colors.white;
  static const Color primaryText = Color(0xFF46494C);
  static const Color accentColor = Color(0xFF2585A1);
  static const Color inputFill = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await DatabaseHelper.instance.getPreferences();
    await _fetchStockList();
    if (mounted) {
      setState(() {
        _manageStock = prefs.manageStock;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStockList() async {
    final items = await DatabaseHelper.instance.getAllStockItems();
    if (mounted) {
      setState(() {
        _stockList = items.reversed.toList();
      });
    }
  }

  void showErrorSnackBar(String txt, BuildContext context) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(txt, style: TextStyle(color: Colors.white)),
        action: SnackBarAction(label: "OK", onPressed: () {}),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  // Save to Database
  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      bool isItemAlreadyExists = false;

      for (var item in _stockList) {
        if (item.itemName == _nameController.text.trim()) {
          showErrorSnackBar("This Item Already Exists", context);
          return;
        }
      }
      final newItem = StockItem(
        itemName: _nameController.text.trim(),
        sellingPrice: int.parse(_sellingPriceController.text.trim()),
        costPrice: _costPriceController.text.isNotEmpty
            ? int.parse(_costPriceController.text.trim())
            : 0,
        stockQty: _manageStock && _qtyController.text.isNotEmpty
            ? int.parse(_qtyController.text.trim())
            : 0,
        // --- UPDATED: Save new tax values ---
        igst: _selectedIgst,
        cgst: _selectedCgst,
        sgst: _selectedSgst,
      );

      await DatabaseHelper.instance.addStockItem(newItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Item Added Successfully!")),
        );
        _clearForm();
        _fetchStockList();
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _sellingPriceController.clear();
    _costPriceController.clear();
    _qtyController.clear();
    // Reset Dropdowns
    setState(() {
      _selectedIgst = 0;
      _selectedCgst = 0;
      _selectedSgst = 0;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return ManageStockScreen();
                  },
                ),
              );
            },
            icon: Icon(Icons.inventory_2),
          ),
        ],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: primaryText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Manage Stock",
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- ADD ITEM FORM ---
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name
                  _buildLabel("ITEM NAME"),
                  _buildCompactTextField(
                    _nameController,
                    "e.g. Gold Ring",
                    Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Prices
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("SELL PRICE"),
                            _buildCompactNumberField(
                              _sellingPriceController,
                              "5000",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("COST (Opt)"),
                            _buildCompactNumberField(
                              _costPriceController,
                              "4500",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- Row 3: TAX DROPDOWNS ---
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("IGST %"),
                            _buildCompactDropdown(
                              value: _selectedIgst,
                              items: _igstRates,
                              onChanged: (val) => setState(() {
                                _selectedIgst = val!;
                                _selectedCgst = val / 2;
                                _selectedSgst = val / 2;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("CGST %"),
                            _buildCompactDropdown(
                              value: _selectedCgst,
                              items: _stateGstRates,
                              onChanged: (val) => setState(() {
                                _selectedSgst = val!;
                                _selectedCgst = val!;
                                _selectedIgst = val * 2;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("SGST %"),
                            _buildCompactDropdown(
                              value: _selectedCgst,
                              items: _stateGstRates,
                              onChanged: (val) => setState(() {
                                _selectedSgst = val!;
                                _selectedCgst = val!;
                                _selectedIgst = val * 2;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // --- Row 4: Qty (Only if Managed) ---
                  if (_manageStock)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("OPENING QUANTITY"),
                        _buildCompactNumberField(
                          _qtyController,
                          "10",
                          icon: Icons.inventory_2,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "SAVE ITEM",
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
          ),

          // --- RECENT LIST HEADER ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "RECENT INVENTORY",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          // --- LIST ---
          Expanded(
            child: _stockList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text(
                          "No items added yet",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _stockList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _stockList[index];
                      // Display helper logic for tax summary in list
                      String taxText;
                      if (item.igst > 0) {
                        taxText = "IGST: ${item.igst}%";
                      } else if (item.cgst > 0 || item.sgst > 0) {
                        taxText = "GST: ${(item.cgst + item.sgst)}%";
                      } else {
                        taxText = "No Tax";
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue[50],
                              radius: 18,
                              child: Text(
                                item.itemName.isNotEmpty
                                    ? item.itemName[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "Sell: ${item.sellingPrice} | $taxText",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_manageStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: item.stockQty > 0
                                      ? Colors.green[50]
                                      : Colors.red[50],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Qty: ${item.stockQty}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.stockQty > 0
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
        ),
      ),
    );
  }

  // --- NEW: Custom Compact Dropdown ---
  Widget _buildCompactDropdown({
    required double value,
    required List<double> items,
    required ValueChanged<double?> onChanged,
  }) {
    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<double>(
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
        value: value,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 12,
          color: primaryText,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: inputFill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 16,
          color: Colors.grey,
        ),
        items: items.map((rate) {
          return DropdownMenuItem(
            value: rate,
            child: Text(
              rate == 0 ? "0%" : "$rate%",
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompactTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return SizedBox(
      height: 40,
      child: TextFormField(
        controller: controller,
        validator: (val) => val!.isEmpty ? "" : null,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: inputFill,
          prefixIcon: Icon(icon, color: Colors.grey, size: 16),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          errorStyle: const TextStyle(height: 0),
        ),
      ),
    );
  }

  Widget _buildCompactNumberField(
    TextEditingController controller,
    String hint, {
    IconData? icon,
  }) {
    return SizedBox(
      height: 40,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
        ],
        style: const TextStyle(fontSize: 13),
        validator: (val) => (icon != null && val!.isEmpty) ? "" : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: inputFill,
          prefixIcon: Icon(
            icon ?? Icons.currency_rupee,
            color: Colors.grey,
            size: 16,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          errorStyle: const TextStyle(height: 0),
        ),
      ),
    );
  }
}
