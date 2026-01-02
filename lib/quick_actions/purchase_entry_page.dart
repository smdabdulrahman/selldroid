import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/home.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/models/stock_item.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/quick_actions/purchase_history.dart';
import 'package:selldroid/settings/purchaser_info_list.dart';
import 'package:selldroid/show_dialog_boxes.dart';

class PurchaseEntryScreen extends StatefulWidget {
  const PurchaseEntryScreen({super.key});

  @override
  State<PurchaseEntryScreen> createState() => _PurchaseEntryScreenState();
}

class _PurchaseEntryScreenState extends State<PurchaseEntryScreen> {
  // --- Colors ---
  static const Color bgColor = Color(0xFFF1F5F9);
  static const Color primaryText = Color(0xFF334155);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color accentColor = Color(0xFF2585A1);
  static const Color cardColor = Colors.white;
  static const Color inputFill = Color(0xFFF8F9FA);

  // --- Data & State ---
  DateTime _selectedDate = DateTime.now();
  List<SupplierInfo> _suppliers = [];
  List<StockItem> _stockItems = [];
  ShopDetails? _shopDetails;

  // Cart Logic
  SupplierInfo? _selectedSupplier;
  StockItem? _selectedItem;
  final List<PurchaseItem> _cartItems = [];

  // **Global Tax Toggle**
  bool _isTaxInclusive = false;

  // Controllers
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _totalAmtController = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: "0");
  final TextEditingController _paidCtrl = TextEditingController(text: "0");

  final FocusNode _qtyFocusNode = FocusNode();
  TextEditingController? _itemSearchCtrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _qtyController.addListener(_calculatePreviewTotal);
    _rateController.addListener(_calculatePreviewTotal);

    _qtyFocusNode.addListener(() {
      if (_qtyFocusNode.hasFocus) {
        _qtyController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _qtyController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _rateController.dispose();
    _qtyFocusNode.dispose();
    super.dispose();
  }

  // --- LOGIC: Tax Calculation (Generic) ---
  // Returns {base, tax, total} using a single effective rate
  Map<String, double> _calculateTaxDetails(
    double qty,
    double rate,
    double effectiveTaxRate,
  ) {
    double rawTotal = qty * rate;
    double taxAmount = 0.0;
    double baseAmount = 0.0;

    if (_isTaxInclusive) {
      // Base = Total / (1 + Tax%)
      baseAmount = rawTotal / (1 + (effectiveTaxRate / 100));
      taxAmount = rawTotal - baseAmount;
    } else {
      // Base = Rate
      baseAmount = rawTotal;
      taxAmount = rawTotal * (effectiveTaxRate / 100);
    }

    return {
      "base": baseAmount,
      "tax": taxAmount,
      "total": baseAmount + taxAmount,
    };
  }

  // Helper to determine which rate to use from StockItem
  double _getEffectiveRateForSelectedItem() {
    if (_selectedItem == null) return 0.0;

    // If Inter-state, use IGST. Else use SGST + CGST.
    bool isInter = _isInterStatePurchase();

    if (isInter) {
      return _selectedItem!.igst;
    } else {
      return _selectedItem!.sgst + _selectedItem!.cgst;
    }
  }

  void _calculatePreviewTotal() {
    if (_qtyController.text.isEmpty || _rateController.text.isEmpty) {
      _totalAmtController.text = "";
      return;
    }
    try {
      int qty = int.parse(_qtyController.text);
      double rate = double.parse(_rateController.text);

      // Calculate using the dynamic rate based on supplier location
      double effectiveRate = _getEffectiveRateForSelectedItem();

      var details = _calculateTaxDetails(qty.toDouble(), rate, effectiveRate);
      _totalAmtController.text = details['total']!.toStringAsFixed(2);
    } catch (_) {}
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    final items = await DatabaseHelper.instance.getAllStockItems();
    final shop = await DatabaseHelper.instance.getShopDetails();
    final prefs = await DatabaseHelper.instance.getPreferences();

    if (mounted) {
      if (suppliers.isEmpty) {
        ShowDialogBoxes.showAutoCloseFailureDialog(
          context: context,
          message: "Add Supplier First to make purchase",
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) {
              return PurchasersListScreen();
            },
          ),
        );
      }
      setState(() {
        _suppliers = suppliers;
        _stockItems = items;
        _shopDetails = shop;
        _isTaxInclusive = prefs.isGstInclusive;
        _isLoading = false;
      });
    }
  }

  bool _isInterStatePurchase() {
    if (_shopDetails == null || _selectedSupplier == null) return false;
    String shopState = _shopDetails!.state.trim().toLowerCase();
    String supplierState = _selectedSupplier!.state.trim().toLowerCase();
    if (shopState.isEmpty || supplierState.isEmpty) return false;
    return shopState != supplierState;
  }

  void _addItemToCart() {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select an Item first")));
      return;
    }
    int qty = int.tryParse(_qtyController.text) ?? 0;
    double rate = double.tryParse(_rateController.text) ?? 0.0;

    if (qty <= 0 || rate <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid Qty or Rate")));
      return;
    }

    // Determine the tax rate to lock in for this item
    double effectiveRate = _getEffectiveRateForSelectedItem();

    setState(() {
      _cartItems.add(
        PurchaseItem(
          itemName: _selectedItem!.itemName,
          qty: qty,
          amount: rate,
          // IMPORTANT: We map the specific Stock tax into the generic gstRate field
          gstRate: effectiveRate,
          gstAmount: 0, // Calculated on save/view
        ),
      );

      _selectedItem = null;
      _qtyController.text = "1";
      _rateController.clear();
      _totalAmtController.clear();
      _itemSearchCtrl?.clear();
    });
  }

  Future<void> _saveFullPurchase() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select a Supplier")));
      return;
    }
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cart is empty")));
      return;
    }

    double totalBaseValue = 0;
    double totalTaxValue = 0;

    List<PurchaseItem> finalItems = [];

    for (var item in _cartItems) {
      var taxDetails = _calculateTaxDetails(
        item.qty.toDouble(),
        item.amount,
        item.gstRate, // This now holds the correct effective rate (IGST or Combined)
      );

      // Store calculated tax amount
      item.gstAmount = taxDetails['tax']!;

      totalBaseValue += taxDetails['base']!;
      totalTaxValue += taxDetails['tax']!;

      finalItems.add(item);
    }

    double discount = double.tryParse(_discountCtrl.text) ?? 0.0;
    double grandTotal = (totalBaseValue + totalTaxValue) - discount;
    int paid = int.tryParse(_paidCtrl.text) ?? 0;

    Purchase newPurchase = Purchase(
      supplierInfoId: _selectedSupplier!.id,
      totalAmount: totalBaseValue.toInt(),
      gstAmount: totalTaxValue.toInt(),
      discount: discount.toInt(),
      finalAmount: grandTotal.toInt(),
      paid: paid,
      paymentMode: "Cash",
      purchasedDate: _selectedDate.toIso8601String(),
      lastPaymentDate: DateTime.now().toIso8601String(),
    );

    // This uses your EXISTING Database method (no model changes needed)
    await DatabaseHelper.instance.createPurchase(newPurchase, finalItems);

    if (mounted) {
      ShowDialogBoxes.showAutoCloseSuccessDialog(
        context: context,
        message: "Purchase Saved",
      );
      setState(() {
        _selectedSupplier = null;
        _cartItems.clear();
        _discountCtrl.text = "0";
        _paidCtrl.text = "0";
        _selectedDate = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double displayBase = 0;
    double displayTax = 0;
    double displayTotal = 0;

    for (var item in _cartItems) {
      var details = _calculateTaxDetails(
        item.qty.toDouble(),
        item.amount,
        item.gstRate,
      );
      displayBase += details['base']!;
      displayTax += details['tax']!;
      displayTotal += details['total']!;
    }

    double disc = double.tryParse(_discountCtrl.text) ?? 0.0;
    double netPayable = displayTotal - disc;
    bool isInterState = _isInterStatePurchase();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "New Purchase Entry",
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
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: accentColor),
            tooltip: "History",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PurchaseHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // --- HEADER ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildDropdownField<SupplierInfo>(
                                label: "Supplier",
                                value: _selectedSupplier,
                                items: _suppliers,
                                displayItem: (s) => s.name,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSupplier = val;
                                    // Clear cart if supplier changes to avoid mixed tax logic?
                                    // For now, assume user knows what they are doing.
                                    _calculatePreviewTotal();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null)
                                    setState(() => _selectedDate = picked);
                                },
                                child: _buildStaticField(
                                  label: "Date",
                                  value: DateFormat(
                                    'dd MMM',
                                  ).format(_selectedDate),
                                  icon: Icons.calendar_today_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- ADD ITEM FORM ---
                  Container(
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
                            const Text(
                              "Add Items",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: secondaryText,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _isTaxInclusive ? "Inclusive" : "Exclusive",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _isTaxInclusive
                                        ? Colors.blue
                                        : Colors.orange,
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: _isTaxInclusive,
                                    activeColor: Colors.blue,
                                    inactiveThumbColor: Colors.orange,
                                    inactiveTrackColor: Colors.orange.shade100,
                                    onChanged: (val) {
                                      setState(() {
                                        _isTaxInclusive = val;
                                        _calculatePreviewTotal();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Autocomplete<StockItem>(
                          optionsBuilder: (textValue) {
                            if (textValue.text.isEmpty) return _stockItems;
                            return _stockItems.where(
                              (i) => i.itemName.toLowerCase().contains(
                                textValue.text.toLowerCase(),
                              ),
                            );
                          },
                          displayStringForOption: (i) => i.itemName,
                          onSelected: (i) {
                            setState(() {
                              _selectedItem = i;
                              _rateController.text = i.costPrice.toString();
                            });
                            _qtyFocusNode.requestFocus();
                            _calculatePreviewTotal();
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 6,
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 320,
                                  constraints: const BoxConstraints(
                                    maxHeight: 160,
                                  ),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    separatorBuilder: (_, __) =>
                                        Divider(height: 0),
                                    itemBuilder: (context, index) {
                                      final c = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(c),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.itemName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                "Qty: " + c.stockQty.toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          fieldViewBuilder: (ctx, ctrl, focus, onEdit) {
                            if (_itemSearchCtrl != ctrl) _itemSearchCtrl = ctrl;
                            return _buildTextField(
                              ctrl,
                              "Search Product",
                              Icons.search,
                              focus: focus,
                              onEdit: onEdit,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                _qtyController,
                                "Qty",
                                null,
                                type: TextInputType.number,
                                focus: _qtyFocusNode,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                _rateController,
                                "Cost Rate",
                                null,
                                type: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                _totalAmtController,
                                "Total",
                                null,
                                type: TextInputType.number,
                                isReadOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: _addItemToCart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              "Add Item",
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
                  const SizedBox(height: 16),

                  // --- CART LIST ---
                  if (_cartItems.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cartItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        var taxDetails = _calculateTaxDetails(
                          item.qty.toDouble(),
                          item.amount,
                          item.gstRate,
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: inputFill,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${item.qty}x",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
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
                                        fontSize: 15,
                                        color: primaryText,
                                      ),
                                    ),
                                    Text(
                                      "@ ₹${FunctionsHelper.num_format.format(item.amount.toInt())} (${_isTaxInclusive ? 'Incl.' : 'Excl.'}) + ₹${FunctionsHelper.num_format.format(double.parse(taxDetails['tax']!.toStringAsFixed(1)))} Tax",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "₹${FunctionsHelper.format_double(taxDetails['total']!.toStringAsFixed(2))}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () =>
                                    setState(() => _cartItems.removeAt(index)),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- SUMMARY ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildTaxInfoBox(isInterState),
                          const SizedBox(height: 16),
                          _buildSummaryRow("Taxable Amount", displayBase),

                          // DYNAMIC DISPLAY: Split the tax visually if Local
                          if (isInterState)
                            _buildSummaryRow("IGST", displayTax)
                          else ...[
                            _buildSummaryRow("CGST", displayTax / 2),
                            _buildSummaryRow("SGST", displayTax / 2),
                          ],

                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                "Discount",
                                style: TextStyle(
                                  color: secondaryText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 100,
                                height: 35,
                                child: _buildTextField(
                                  _discountCtrl,
                                  "0",
                                  null,
                                  type: TextInputType.number,
                                  align: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildSummaryRow(
                            "Net Payable",
                            netPayable,
                            isBold: true,
                            color: accentColor,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                "Paid Amount",
                                style: TextStyle(
                                  color: primaryText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 120,
                                height: 40,
                                child: _buildTextField(
                                  _paidCtrl,
                                  "0",
                                  null,
                                  type: TextInputType.number,
                                  align: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _saveFullPurchase,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "SAVE PURCHASE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        "Cart is empty",
                        style: TextStyle(color: secondaryText),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS (Same as before) ---
  Widget _buildTaxInfoBox(bool isInter) {
    String shopState = _shopDetails?.state.trim() ?? "Shop";
    String suppState = _selectedSupplier?.state.trim() ?? "Supplier";
    if (_selectedSupplier == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isInter ? "Inter-State Purchase" : "Local Purchase",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isInter
                      ? "$suppState ➔ $shopState (IGST Applied)"
                      : "Same State ($shopState) (CGST + SGST Applied)",
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData? icon, {
    TextInputType type = TextInputType.text,
    bool isReadOnly = false,
    FocusNode? focus,
    VoidCallback? onEdit,
    TextAlign align = TextAlign.start,
  }) {
    return SizedBox(
      height: 45,
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        readOnly: isReadOnly,
        focusNode: focus,
        onEditingComplete: onEdit,
        textAlign: align,
        onChanged: (v) => setState(() {}),
        style: const TextStyle(
          fontSize: 14,
          color: primaryText,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: Colors.grey)
              : null,
          filled: true,
          fillColor: inputFill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayItem,
    required Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: secondaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(8),
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              hint: Text(
                "Select $label",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        displayItem(item),
                        style: const TextStyle(
                          color: primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: secondaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              Icon(icon, size: 18, color: accentColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    double val, {
    Color? color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? primaryText : secondaryText,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          "₹${FunctionsHelper.format_double(val.toStringAsFixed(2))}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? primaryText,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
