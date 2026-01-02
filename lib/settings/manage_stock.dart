import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/models/stock_item.dart';

import 'package:selldroid/settings/addstockitem.dart'; // Adjust path if needed

class ManageStockScreen extends StatefulWidget {
  const ManageStockScreen({super.key});

  @override
  State<ManageStockScreen> createState() => _ManageStockScreenState();
}

class _ManageStockScreenState extends State<ManageStockScreen> {
  // Colors (Matching your AddStockScreen)
  static const Color bgColor = Color(0xFFE8ECEF);
  static const Color cardColor = Colors.white;
  static const Color primaryText = Color(0xFF46494C);
  static const Color accentColor = Color(0xFF2585A1);
  static const Color inputFill = Color(0xFFF3F4F6);

  // Data State
  List<StockItem> _allStock = [];
  List<StockItem> _filteredStock = [];
  bool _isLoading = true;

  // Pagination State
  int _currentPage = 0;
  int _itemsPerPage = 8; // Adjust based on your screen height

  // Search Controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStockList();
  }

  Future<void> _fetchStockList() async {
    setState(() => _isLoading = true);
    final items = await DatabaseHelper.instance.getAllStockItems();
    if (mounted) {
      setState(() {
        _itemsPerPage = (MediaQuery.of(context).size.height / 90).toInt();
        _allStock = items.reversed.toList(); // Newest first
        _filterStock(_searchController.text); // Apply existing filter if any
        _isLoading = false;
      });
    }
  }

  // Filter Logic
  void _filterStock(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStock = List.from(_allStock);
      } else {
        _filteredStock = _allStock
            .where(
              (item) =>
                  item.itemName.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
      _currentPage = 0; // Reset to page 1 on search
    });
  }

  // Pagination Logic
  List<StockItem> get _paginatedList {
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredStock.length) return [];
    return _filteredStock.sublist(
      startIndex,
      endIndex > _filteredStock.length ? _filteredStock.length : endIndex,
    );
  }

  int get _totalPages => (_filteredStock.length / _itemsPerPage).ceil();

  // Navigation to Add Screen
  void _navigateToAddStock() async {
    // We await the result. When user comes back, we refresh the list.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddStockScreen()),
    );
    _fetchStockList();
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
        title: const Text(
          "Inventory",
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          // Add Button in App Bar for easy access
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: _navigateToAddStock,
              icon: CircleAvatar(
                backgroundColor: accentColor,
                radius: 16,
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 1. SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterStock,
                decoration: InputDecoration(
                  hintText: "Search items...",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filterStock('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // --- 2. TABLE HEADER ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: _headerText("ITEM NAME")),
                Expanded(
                  flex: 1,
                  child: _headerText("QTY", align: TextAlign.center),
                ),
                Expanded(
                  flex: 2,
                  child: _headerText("PRICE", align: TextAlign.right),
                ),
              ],
            ),
          ),

          // --- 3. LIST AREA (Expanded takes remaining space - No Scroll) ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStock.isEmpty
                ? Center(
                    child: Text(
                      "No items found",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    // Determine item count based on pagination
                    itemCount: _paginatedList.length,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disables list scrolling
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final item = _paginatedList[index];
                      return _buildStockRow(item);
                    },
                  ),
          ),

          // --- 4. PAGINATION CONTROLS (Fixed at bottom) ---
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous Button
                IconButton(
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  icon: Icon(
                    Icons.chevron_left,
                    color: _currentPage > 0 ? primaryText : Colors.grey[300],
                  ),
                ),

                // Page Indicator
                Text(
                  "Page ${_currentPage + 1} of ${_totalPages == 0 ? 1 : _totalPages}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                    fontSize: 12,
                  ),
                ),

                // Next Button
                IconButton(
                  onPressed: _currentPage < _totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: Icon(
                    Icons.chevron_right,
                    color: _currentPage < _totalPages - 1
                        ? primaryText
                        : Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _headerText(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildStockRow(StockItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Name & Tax
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: primaryText,
                  ),
                ),
                Text(
                  _getTaxLabel(item),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Quantity
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: item.stockQty > 0 ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${item.stockQty}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: item.stockQty > 0
                      ? Colors.green[700]
                      : Colors.red[700],
                ),
              ),
            ),
          ),

          // Price
          Expanded(
            flex: 2,
            child: Text(
              item.sellingPrice.toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTaxLabel(StockItem item) {
    if (item.igst > 0) return "IGST: ${item.igst}%";
    if (item.cgst > 0 || item.sgst > 0)
      return "GST: ${(item.cgst + item.sgst)}%";
    return "No Tax";
  }
}
