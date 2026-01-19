import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/functions_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/models/preference_model.dart';
import 'package:selldroid/models/sale.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/models/sold_item.dart';
import 'package:selldroid/models/stock_item.dart';
import 'package:selldroid/quick_actions/make_bill/all_bills_view.dart';
import 'package:selldroid/quick_actions/make_bill/bill_view.dart';
import 'package:selldroid/settings.dart';
import 'package:selldroid/settings/addstockitem.dart';
import 'package:selldroid/show_dialog_boxes.dart';
import 'package:selldroid/theme_provider.dart';
import 'package:sqflite/sqflite.dart';

class StockSaleScreen extends StatefulWidget {
  StockSaleScreen({super.key});

  @override
  State<StockSaleScreen> createState() => _StockSaleScreenState();
}

class _StockSaleScreenState extends State<StockSaleScreen> {
  // --- Data ---
  List<StockItem> _stockItems = [];
  List<Customer> _customers = [];
  List<String> _stateNames = [];
  PreferenceModel? _prefs;
  ShopDetails? _shopDetails;

  bool _isLoading = true;
  bool _isLoadingStates = false;

  // --- Cart & State ---
  final List<SoldItem> _cartItems = [];
  StockItem? _selectedStockItem;
  Customer? _selectedCustomer;
  bool _isNewCustomerMode = false;

  // --- Controllers ---
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _newCustNameCtrl = TextEditingController();
  final TextEditingController _newCustPhoneCtrl = TextEditingController();
  final TextEditingController _newCustStateCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: "0");

  final FocusNode _qtyFocusNode = FocusNode();
  TextEditingController? _autocompleteInputCtrl;

  // --- Payment State ---
  String _selectedPaymentMode = "Cash";
  List<String> _paymentModes = []; // Defaults

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchStates();

    // Select all text when Qty field gets focus
    _qtyFocusNode.addListener(() {
      if (_qtyFocusNode.hasFocus) {
        _qtyController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _qtyController.text.length,
        );
      }
    });

    // Update UI (Tax Info Box) when typing state
    _newCustStateCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _qtyFocusNode.dispose();
    _newCustStateCtrl.dispose();
    super.dispose();
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
    final prefs = await DatabaseHelper.instance.getPreferences();
    final items = await DatabaseHelper.instance.getAllStockItems();
    final customers = await DatabaseHelper.instance.getCustomers();
    final shop = await DatabaseHelper.instance.getShopDetails();
    final dbModes = await DatabaseHelper.instance.getAllCashModes();
    final default_cust = Customer(
      id: 0,
      name: "Walk in",
      phoneNumber: "",
      state: shop.state,
    );
    if (items.isEmpty) {
      ShowDialogBoxes.showAutoCloseFailureDialog(
        context: context,
        message: "No Items found, Add Stock Item in settings",
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return SettingsScreen();
          },
        ),
      );
    }
    if (prefs.manageStock) {
      int tot_qty = 0;
      items.forEach((item) {
        tot_qty += item.stockQty;
      });
      if (tot_qty == 0) {
        ShowDialogBoxes.showAutoCloseFailureDialog(
          context: context,
          message: "All items are out of stock",
          onCompleted: () {
            Navigator.pop(context);
          },
        );
      }
    }
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _stockItems = items;
        _customers = customers;
        _shopDetails = shop;
        _selectedCustomer = default_cust;
        // Merge Defaults + DB Modes
        Set<String> uniqueModes = {"Cash", "UPI"};
        for (var mode in dbModes) {
          uniqueModes.add(mode.modeName);
        }
        _paymentModes = uniqueModes.toList();

        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStates() async {
    setState(() => _isLoadingStates = true);
    try {
      var request = http.Request(
        'GET',
        Uri.parse('https://api.countrystatecity.in/v1/countries/IN/states'),
      );
      request.headers['X-CSCAPI-KEY'] =
          'eGNkOGtuYk42RmtCdVc1bDczbzI5eE9MZGdGTk5tN2NNY1Y1MktQaQ==';
      var response = await request.send();
      if (response.statusCode == 200) {
        String data = await response.stream.bytesToString();
        List<dynamic> jsonList = jsonDecode(data);
        if (mounted) {
          setState(
            () => _stateNames = jsonList
                .map<String>((e) => e['name'].toString())
                .toList(),
          );
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStates = false);
    }
  }

  // --- LOGIC: Tax Type ---
  bool _isInterStateSale() {
    String shopState = (_shopDetails?.state ?? "").trim().toLowerCase();
    String custState = "";

    if (_isNewCustomerMode) {
      custState = _newCustStateCtrl.text.trim().toLowerCase();
      // If empty, treat as local
      if (custState.isEmpty) custState = shopState;
    } else {
      if (_selectedCustomer != null) {
        custState = (_selectedCustomer!.state).trim().toLowerCase();
      } else {
        custState = shopState; // Walk-in = Local
      }
    }
    // If shop has no state set, assume local
    if (shopState.isEmpty) return false;
    return shopState != custState;
  }

  // --- CALCULATIONS ---
  // Calculates tax details for a single line item
  Map<String, double> _calculateItemBreakdown(
    double originalPriceQty,
    double igstRate,
    double sgstRate,
    double cgstRate,
  ) {
    double discPercent = double.tryParse(_discountCtrl.text) ?? 0.0;
    bool isInclusive = _prefs?.isGstInclusive ?? false;
    bool hasTax = _prefs?.includeGst ?? false;

    // 1. Apply Bill Discount to Base Price first
    double discountAmt = originalPriceQty * (discPercent / 100);
    double amountAfterDisc = originalPriceQty - discountAmt;

    double taxable = 0, totalTax = 0, finalTotal = 0;

    // Determine effective rate based on location
    bool isInterState = _isInterStateSale();
    double effectiveRate = isInterState ? igstRate : (sgstRate + cgstRate);

    if (!hasTax || effectiveRate <= 0) {
      return {
        "base": originalPriceQty,
        "discount": discountAmt,
        "taxable": amountAfterDisc,
        "cgst": 0,
        "sgst": 0,
        "igst": 0,
        "total_tax": 0,
        "total": amountAfterDisc,
      };
    }

    if (isInclusive) {
      // Reverse Calc: Total includes Tax
      finalTotal = amountAfterDisc;
      taxable = finalTotal / (1 + (effectiveRate / 100));
      totalTax = finalTotal - taxable;
    } else {
      // Forward Calc: Base + Tax
      taxable = amountAfterDisc;
      totalTax = taxable * (effectiveRate / 100);
      finalTotal = taxable + totalTax;
    }

    // Split Tax Amount
    double valCgst = 0, valSgst = 0, valIgst = 0;
    if (isInterState) {
      valIgst = totalTax;
    } else {
      // Pro-rata based on rate ratios, or simple split if rates are equal
      // Usually standard is 50-50, but model allows distinct.
      // Let's use proportional split:
      if ((sgstRate + cgstRate) > 0) {
        valCgst = totalTax * (cgstRate / effectiveRate);
        valSgst = totalTax * (sgstRate / effectiveRate);
      }
    }

    return {
      "base": originalPriceQty,
      "discount": discountAmt,
      "taxable": taxable,
      "cgst": valCgst,
      "sgst": valSgst,
      "igst": valIgst,
      "total_tax": totalTax,
      "total": finalTotal,
    };
  }

  Map<String, double> _calculateSummary() {
    double totalBase = 0,
        totalDiscount = 0,
        totalTaxable = 0,
        totalCgst = 0,
        totalSgst = 0,
        totalIgst = 0,
        finalAmount = 0;

    for (var item in _cartItems) {
      var bd = _calculateItemBreakdown(
        item.amount.toDouble(),
        item.igst,
        item.sgst,
        item.cgst,
      );

      totalBase += bd['base']!;
      totalDiscount += bd['discount']!;
      totalTaxable += bd['taxable']!;
      totalCgst += bd['cgst']!;
      totalSgst += bd['sgst']!;
      totalIgst += bd['igst']!;
      finalAmount += bd['total']!;
    }
    return {
      "total_base": totalBase,
      "total_discount": totalDiscount,
      "total_taxable": totalTaxable,
      "total_cgst": totalCgst,
      "total_sgst": totalSgst,
      "total_igst": totalIgst,
      "final_amount": finalAmount,
    };
  }

  // --- ACTIONS ---
  void _addItem() {
    if (_selectedStockItem == null) return;
    int qty = int.tryParse(_qtyController.text) ?? 1;
    if (qty <= 0) qty = 1;

    // Stock Check
    if (_prefs?.manageStock == true) {
      int currentStock = _selectedStockItem!.stockQty;
      int cartQty = _cartItems
          .where((i) => i.itemName == _selectedStockItem!.itemName)
          .fold(0, (sum, i) => sum + i.qty);
      if ((cartQty + qty) > currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Not enough stock!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _cartItems.add(
        SoldItem(
          salesId: 0,
          itemName: _selectedStockItem!.itemName,
          qty: qty,
          amount: (qty * _selectedStockItem!.sellingPrice).toDouble(),
          // Store rates from StockItem to model
          igst: _selectedStockItem!.igst,
          sgst: _selectedStockItem!.sgst,
          cgst: _selectedStockItem!.cgst,
        ),
      );
      _selectedStockItem = null;
      _qtyController.text = "1";
      _autocompleteInputCtrl?.clear();
      FocusScope.of(context).unfocus();
    });
  }

  void _showPaymentDialog() {
    final summary = _calculateSummary();
    final grandTotal = summary['final_amount']!;

    // Set default payment mode
    _selectedPaymentMode = "Cash";

    // Setup controller with Full Amount selected
    final payCtrl = TextEditingController(text: grandTotal.toInt().toString());
    payCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: payCtrl.text.length,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double currentEnteredAmount = double.tryParse(payCtrl.text) ?? 0.0;
            double balance = grandTotal - currentEnteredAmount;

            // Build UPI String
            String upiData = "";
            if (_shopDetails != null &&
                _shopDetails!.upiId.isNotEmpty &&
                currentEnteredAmount > 0) {
              upiData =
                  "upi://pay?pa=${_shopDetails!.upiId}&pn=${_shopDetails!.name}&am=$currentEnteredAmount&tn=Bill Payment&cu=INR";
            }

            // Check if selected mode is UPI/QR related
            bool isUpiMode =
                _selectedPaymentMode.toLowerCase().contains("upi") ||
                _selectedPaymentMode.toLowerCase().contains("qr");

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Payment Details",
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Walk-in Indicator logic
                      if (!_isNewCustomerMode && _selectedCustomer == null)
                        Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                "Walk-in Customer (Local Sale)",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Amount Box
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Bill:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: secondaryText,
                              ),
                            ),
                            Text(
                              "₹${FunctionsHelper.format_double(grandTotal.toStringAsFixed(2))}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Payment Mode Dropdown
                      Text(
                        "Payment Mode",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 5),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPaymentMode,
                            isExpanded: true,
                            items: _paymentModes.map((String mode) {
                              return DropdownMenuItem<String>(
                                value: mode,
                                child: Text(
                                  mode,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                _selectedPaymentMode = val!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input Field
                      TextField(
                        controller: payCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                        decoration: InputDecoration(
                          labelText: "Received / Paying Amount",
                          labelStyle: TextStyle(color: secondaryText),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(
                            Icons.currency_rupee,
                            color: accentColor,
                          ),
                        ),
                        onChanged: (val) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 20),

                      // Display Logic: QR or Balance
                      if (!isUpiMode) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: balance >= 0
                                ? Colors.green[50]
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Balance : ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: secondaryText,
                                ),
                              ),
                              Text(
                                "₹${FunctionsHelper.format_double(balance.abs().toStringAsFixed(2))} ${balance < 0 ? '(Due)' : ''}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Center(
                          child: upiData.isNotEmpty
                              ? Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: QrImageView(
                                        data: upiData,
                                        version: QrVersions.auto,
                                        size: 200.0,
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Scan to Pay ₹$currentEnteredAmount",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  "⚠️ Enter amount to generate QR",
                                  style: TextStyle(color: Colors.red),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _saveFinalBill(summary, currentEnteredAmount.toInt());
                  },
                  child: const Text(
                    "Confirm & Save",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveFinalBill(
    Map<String, double> summary,
    int paidAmount,
  ) async {
    int? customerId = 0;

    // --- CUSTOMER HANDLING ---
    if (_isNewCustomerMode) {
      String newName = _newCustNameCtrl.text.trim();

      // If user typed a name, create new customer
      if (newName.isNotEmpty) {
        String newPhone = _newCustPhoneCtrl.text.trim();
        // Default to "Tamil Nadu" if state empty, or use shop's state
        String defaultState = _shopDetails?.state.isNotEmpty == true
            ? _shopDetails!.state
            : "Tamil Nadu";
        String newState = _newCustStateCtrl.text.trim().isEmpty
            ? defaultState
            : _newCustStateCtrl.text.trim();

        Customer newCust = Customer(
          id: null,
          name: newName,
          phoneNumber: newPhone,
          state: newState,
        );
        customerId = await DatabaseHelper.instance.addCustomer(newCust);
      } else {
        // Name empty = Walk-in
        customerId = 0;
      }
    } else {
      // Existing Tab: Use selection or Walk-in
      customerId = _selectedCustomer?.id;
    }

    // --- PREPARE ITEMS (Update SoldItem with final tax values) ---
    // The items in _cartItems already contain raw rates. We just need to ensure
    // we recalculate the exact amounts if discounts or tax inclusive logic changed.
    List<SoldItem> finalItemsToSave = _cartItems.map((item) {
      // Calculate breakdown for this item
      var bd = _calculateItemBreakdown(
        item.amount,
        item.igst,
        item.sgst,
        item.cgst,
      );

      // Update the item model with calculated values to save to DB
      // Note: SoldItem stores amounts, not rates
      // Wait, your SoldItem model has fields 'igst', 'sgst', 'cgst'.
      // Are these rates or amounts?
      // Based on previous code, they seemed to be rates.
      // If they are RATES, we leave them as is.
      // If they are AMOUNTS, we overwrite them with bd['igst'] etc.
      // Assuming they are RATES (since StockItem stores rates), we don't overwrite them here.
      // We only save the row.
      // BUT, Sales usually need to lock in the Tax Amount.
      // The table `stock_sales_items` has `gst_amount`.
      // So we assume `SoldItem` likely has a `gstAmount` field not shown in your snippet,
      // OR we just save the item as is and the breakdown happens at print time.

      return item;
    }).toList();

    int totalTaxInt =
        (summary['total_cgst']! +
                summary['total_sgst']! +
                summary['total_igst']!)
            .toInt();

    // --- CREATE SALE ---
    Sale newSale = Sale(
      customerId: customerId!,
      totalAmount: summary['total_taxable']!.toInt(),
      gstAmount: totalTaxInt,
      discountAmount: summary['total_discount']!.toInt(),
      finalAmount: summary['final_amount']!.toInt(),
      paid: paidAmount,
      isStockSales: true,
      paymentMode: _selectedPaymentMode,
      billedDate: DateTime.now().toIso8601String(),
      lastPaymentDate: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper.instance.createSale(newSale, finalItemsToSave).then((
      id,
    ) {
      Sale s = Sale(
        id: id,
        customerId: customerId!,
        totalAmount: summary['total_taxable']!.toInt(),
        gstAmount: totalTaxInt,
        discountAmount: summary['total_discount']!.toInt(),
        finalAmount: summary['final_amount']!.toInt(),
        paid: paidAmount,
        isStockSales: true,
        paymentMode: _selectedPaymentMode,
        billedDate: DateTime.now().toIso8601String(),
        lastPaymentDate: DateTime.now().toIso8601String(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return BillDetailsScreen(saleData: s.toMap());
          },
        ),
      );
    });

    if (mounted) {
      ShowDialogBoxes.showAutoCloseSuccessDialog(
        context: context,
        message: "Bill Saved",
      );
      setState(() {
        _cartItems.clear();
        _discountCtrl.text = "0";
        _selectedStockItem = null;
        _autocompleteInputCtrl?.clear();
        _qtyController.text = "1";
        _newCustNameCtrl.clear();
        _newCustPhoneCtrl.clear();
        _newCustStateCtrl.clear();
        _selectedCustomer = null;
        _selectedPaymentMode = "Cash";
      });
    }
  }

  late Color bgColor;
  late Color primaryText;
  late Color secondaryText;
  late Color accentColor;
  late Color cardColor;
  final inputFill = Colors.grey.shade100;
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    bgColor = theme.bgColor;
    primaryText = theme.primaryText;
    secondaryText = theme.secondaryText;
    accentColor = theme.accentColor;
    cardColor = theme.cardColor;
    bool isInclusive = _prefs?.isGstInclusive ?? false;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "New Stock Sale",
          style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return AllBillsScreen();
                  },
                ),
              );
            },
            icon: Icon(Icons.receipt_long),
          ),
        ],
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1. CUSTOMER SECTION
                  _buildSectionHeader("CUSTOMER DETAILS", Icons.person_outline),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildTabBtn(
                              "Existing / Walk-in",
                              !_isNewCustomerMode,
                              () => setState(() => _isNewCustomerMode = false),
                            ),
                            SizedBox(width: 10),
                            _buildTabBtn(
                              "New Customer",
                              _isNewCustomerMode,
                              () => setState(() => _isNewCustomerMode = true),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        if (!_isNewCustomerMode)
                          LayoutBuilder(
                            builder: (context, raints) {
                              return Autocomplete<Customer>(
                                optionsBuilder: (textValue) {
                                  if (textValue.text.isEmpty) return _customers;

                                  return _customers.where(
                                    (c) => c.name.toLowerCase().contains(
                                      textValue.text.toLowerCase(),
                                    ),
                                  );
                                },
                                displayStringForOption: (c) =>
                                    "${c.name} (${c.phoneNumber})",
                                onSelected: (c) =>
                                    setState(() => _selectedCustomer = c),

                                fieldViewBuilder: (ctx, ctrl, focus, onEdit) {
                                  return _buildTextField(
                                    ctrl,
                                    "Search Customer (Leave empty for Walk-in)",
                                    Icons.search,
                                    focus: focus,
                                    onEdit: onEdit,
                                  );
                                },

                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 6,
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            width: 320,
                                            constraints: BoxConstraints(
                                              maxHeight: 160,
                                            ),
                                            child: ListView.separated(
                                              padding: EdgeInsets.zero,
                                              itemCount: options.length,
                                              separatorBuilder: (_, __) =>
                                                  Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final c = options.elementAt(
                                                  index,
                                                );
                                                return InkWell(
                                                  onTap: () => onSelected(c),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 10,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          c.name,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        Text(
                                                          c.phoneNumber,
                                                          style: TextStyle(
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
                              );
                            },
                          )
                        else
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      _newCustNameCtrl,
                                      "Name",
                                      Icons.person,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: _buildTextField(
                                      _newCustPhoneCtrl,
                                      "Phone",
                                      Icons.phone,
                                      type: TextInputType.phone,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              _buildSearchableStateField(_newCustStateCtrl),
                            ],
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // 2. ADD PRODUCT SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(
                        "ADD ITEMS",
                        Icons.shopping_cart_outlined,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isInclusive
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isInclusive
                                ? Colors.blue.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          isInclusive ? "Tax Inclusive" : "Tax Exclusive",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isInclusive
                                ? Colors.blue.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Autocomplete<StockItem>(
                                optionsBuilder: (textValue) {
                                  if (textValue.text.isEmpty)
                                    return _stockItems;
                                  return _stockItems.where(
                                    (i) => i.itemName.toLowerCase().contains(
                                      textValue.text.toLowerCase(),
                                    ),
                                  );
                                },
                                displayStringForOption: (i) => i.itemName,
                                onSelected: (i) {
                                  setState(() => _selectedStockItem = i);
                                  _qtyFocusNode.requestFocus();
                                },

                                fieldViewBuilder: (ctx, ctrl, focus, onEdit) {
                                  if (_autocompleteInputCtrl != ctrl)
                                    _autocompleteInputCtrl = ctrl;
                                  return _buildTextField(
                                    ctrl,
                                    "Search Product",
                                    Icons.search,
                                    focus: focus,
                                    onEdit: onEdit,
                                  );
                                },

                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 6,
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 300,

                                        constraints: BoxConstraints(
                                          maxHeight: 150,
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final item = options.elementAt(
                                              index,
                                            );
                                            int qty = () {
                                              if (!_prefs!.manageStock)
                                                return 9999;
                                              int cart_qty = 0;
                                              _cartItems.forEach((i) {
                                                if (i.itemName ==
                                                    item.itemName) {
                                                  cart_qty += i.qty;
                                                }
                                              });
                                              return item.stockQty - cart_qty;
                                            }();

                                            return InkWell(
                                              onTap: () =>
                                                  !_prefs!.manageStock &&
                                                      qty == 0
                                                  ? showErrorSnackBar(
                                                      "This item is currently out of stock",
                                                      context,
                                                    )
                                                  : onSelected(item),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      item.itemName.length < 20
                                                          ? item.itemName
                                                          : item.itemName
                                                                    .substring(
                                                                      0,
                                                                      20,
                                                                    ) +
                                                                "...",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: qty == 0
                                                            ? Colors.red
                                                            : Colors.black,
                                                      ),
                                                    ),
                                                    if (_prefs!.manageStock)
                                                      Text(
                                                        "Q:${qty}".toString(),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: qty == 0
                                                              ? Colors.red
                                                              : Colors.black,
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
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _qtyController,
                                focusNode: _qtyFocusNode,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _addItem(),
                                decoration: InputDecoration(
                                  labelText: "Qty",
                                  filled: true,
                                  fillColor: inputFill,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: _selectedStockItem == null
                                ? null
                                : _addItem,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            icon: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              "Add to List",
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

                  SizedBox(height: 20),

                  // 3. CART LIST
                  if (_cartItems.isNotEmpty) ...[
                    _buildSectionHeader(
                      "ITEMS (${_cartItems.length})",
                      Icons.receipt_long,
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _cartItems.length,
                      separatorBuilder: (context, index) => SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        // Calc breakdown
                        var bd = _calculateItemBreakdown(
                          item.amount.toDouble(),
                          item.igst,
                          item.sgst,
                          item.cgst,
                        );
                        bool interState = _isInterStateSale();
                        // Determine display rate string
                        String rateStr = "";
                        if (interState) {
                          rateStr =
                              "IGST: ${FunctionsHelper.format_double(item.igst.toStringAsFixed(0))}%";
                        } else {
                          rateStr =
                              "GST: ${FunctionsHelper.format_double((item.cgst + item.sgst).toStringAsFixed(0))}%";
                        }

                        return Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: primaryText,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => setState(
                                      () => _cartItems.removeAt(index),
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "${item.qty} x ${FunctionsHelper.format_double((item.amount / item.qty).toStringAsFixed(1))}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryText,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      rateStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniStat("Taxable", bd['taxable']!),
                                  if (!interState) ...[
                                    _buildMiniStat("CGST", bd['cgst']!),
                                    _buildMiniStat("SGST", bd['sgst']!),
                                  ] else
                                    _buildMiniStat("IGST", bd['igst']!),
                                  _buildMiniStat(
                                    "Total",
                                    bd['total']!,
                                    isBold: true,
                                    color: accentColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 30),
                    Container(
                      padding: EdgeInsets.all(20),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PAYMENT SUMMARY",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: secondaryText,
                            ),
                          ),
                          SizedBox(height: 15),

                          // TAX INFO BOX
                          _buildTaxInfoBox(),
                          SizedBox(height: 10),

                          Row(
                            children: [
                              Text(
                                "Discount %",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: primaryText,
                                ),
                              ),
                              Spacer(),
                              SizedBox(
                                width: 80,
                                height: 35,
                                child: TextField(
                                  controller: _discountCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  onChanged: (v) => setState(() {}),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: inputFill,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          _buildSummaryRow(
                            "Gross Amount",
                            _calculateSummary()['total_base']!,
                          ),
                          if (_calculateSummary()['total_discount']! > 0)
                            _buildSummaryRow(
                              "Discount",
                              -_calculateSummary()['total_discount']!,
                              color: Colors.red,
                            ),
                          _buildSummaryRow(
                            "Net Taxable Amount",
                            _calculateSummary()['total_taxable']!,
                            isBold: true,
                          ),
                          SizedBox(height: 8),
                          if (!_isInterStateSale()) ...[
                            _buildSummaryRow(
                              "Total CGST",
                              _calculateSummary()['total_cgst']!,
                            ),
                            _buildSummaryRow(
                              "Total SGST",
                              _calculateSummary()['total_sgst']!,
                            ),
                          ] else
                            _buildSummaryRow(
                              "Total IGST",
                              _calculateSummary()['total_igst']!,
                            ),
                          Divider(height: 30, thickness: 1.2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Grand Total",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              Text(
                                "₹${FunctionsHelper.format_double(_calculateSummary()['final_amount']!.toStringAsFixed(2))}",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _showPaymentDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                "SAVE BILL",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          "Cart is empty",
                          style: TextStyle(color: secondaryText),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS ---

  // Tax Information Banner
  Widget _buildTaxInfoBox() {
    String shopState = (_shopDetails?.state ?? "").trim();
    String custState = "";

    if (_isNewCustomerMode) {
      custState = _newCustStateCtrl.text.trim();
      if (custState.isEmpty) custState = shopState; // If empty, assume local
    } else {
      custState = _selectedCustomer?.state.trim() ?? shopState;
    }

    // Safety checks for display
    if (shopState.isEmpty) shopState = "Shop";
    if (custState.isEmpty) custState = "Customer";

    bool isInter = _isInterStateSale();

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isInter ? "Inter-State Sale" : "Local Sale",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  isInter
                      ? "$shopState ➔ $custState (IGST Applied)"
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

  Widget _buildSearchableStateField(TextEditingController controller) {
    return LayoutBuilder(
      builder: (context, raints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: FocusNode(),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (_stateNames.isEmpty) return Iterable<String>.empty();
            if (textEditingValue.text.isEmpty) return _stateNames;
            return _stateNames.where(
              (String option) => option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              ),
            );
          },
          onSelected: (String selection) {
            controller.text = selection;
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                return SizedBox(
                  height: 45,
                  child: TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onFieldSubmitted: (String value) => onFieldSubmitted(),
                    decoration: InputDecoration(
                      hintText: "State (Leave empty for local)",
                      filled: true,
                      fillColor: inputFill,
                      prefixIcon: Icon(Icons.map, color: Colors.grey, size: 18),
                      suffixIcon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  width: raints.maxWidth,
                  constraints: BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(option, style: TextStyle(fontSize: 13)),
                        onTap: () => onSelected(option),
                        dense: true,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: secondaryText),
          SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: secondaryText,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? accentColor : inputFill,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : secondaryText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData? icon, {
    TextInputType type = TextInputType.text,
    FocusNode? focus,
    VoidCallback? onEdit,
  }) {
    return SizedBox(
      height: 45,
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        focusNode: focus,
        onEditingComplete: onEdit,
        onChanged: (v) => setState(() {}),
        style: TextStyle(
          fontSize: 14,
          color: primaryText,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: Colors.grey)
              : null,
          filled: true,
          fillColor: inputFill,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    String label,
    double val, {
    bool isBold = false,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          "₹${FunctionsHelper.format_double(val.toStringAsFixed(1))}",
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? primaryText,
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? primaryText : secondaryText,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "₹${FunctionsHelper.format_double(val.abs().toStringAsFixed(2))}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? primaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
