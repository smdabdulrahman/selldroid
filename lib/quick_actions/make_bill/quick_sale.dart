import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/models/preference_model.dart';
import 'package:selldroid/models/sale.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/models/sold_item.dart';
import 'package:selldroid/quick_actions/make_bill/all_bills_view.dart';
import 'package:selldroid/quick_actions/make_bill/bill_view.dart';
import 'package:selldroid/show_dialog_boxes.dart';

class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> {
  // --- Colors ---
  static const Color bgColor = Color(0xFFE8ECEF);
  static const Color primaryText = Color(0xFF46494C);
  static const Color secondaryText = Color(0xFF757575);
  static const Color accentColor = Color(0xFF2585A1);
  static const Color cardColor = Colors.white;
  static const Color inputFill = Color(0xFFF3F4F6);

  // --- Data ---
  List<Customer> _customers = [];
  List<String> _stateNames = [];
  PreferenceModel? _prefs;
  ShopDetails? _shopDetails;

  bool _isLoading = true;
  bool _isLoadingStates = false;

  // --- Cart & State ---
  final List<SoldItem> _cartItems = [];
  Customer? _selectedCustomer;
  bool _isNewCustomerMode = false;

  // --- Controllers (MANUAL ENTRY) ---
  final TextEditingController _itemNameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: "1");
  // Removed _gstRateCtrl

  // --- NEW: Tax Variables & Lists ---
  double _selectedIgst = 0;
  double _selectedCgst = 0;
  double _selectedSgst = 0;
  final List<double> _igstRates = [0, 5, 12, 18, 28];
  final List<double> _stateGstRates = [0, 2.5, 6, 9, 14];

  // Customer Controllers
  final TextEditingController _newCustNameCtrl = TextEditingController();
  final TextEditingController _newCustPhoneCtrl = TextEditingController();
  final TextEditingController _newCustStateCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: "0");

  // --- Focus Nodes ---
  final FocusNode _nameNode = FocusNode();
  final FocusNode _priceNode = FocusNode();
  final FocusNode _qtyNode = FocusNode();

  // --- Payment State ---
  String _selectedPaymentMode = "Cash";
  List<String> _paymentModes = ["Cash", "UPI"];

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchStates();

    _qtyNode.addListener(() {
      if (_qtyNode.hasFocus) {
        _qtyCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _qtyCtrl.text.length,
        );
      }
    });

    // Update UI for Tax Info & Dropdowns when state changes
    _newCustStateCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameNode.dispose();
    _priceNode.dispose();
    _qtyNode.dispose();
    _newCustStateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await DatabaseHelper.instance.getPreferences();
    final customers = await DatabaseHelper.instance.getCustomers();
    final shop = await DatabaseHelper.instance.getShopDetails();
    final dbModes = await DatabaseHelper.instance.getAllCashModes();
    final default_cust = Customer(
      id: 0,
      name: "Walk in",
      phoneNumber: "",
      state: shop.state,
    );
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _customers = customers;
        _shopDetails = shop;
        _selectedCustomer = default_cust;

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
      if (custState.isEmpty) custState = shopState;
    } else {
      if (_selectedCustomer != null) {
        custState = (_selectedCustomer!.state).trim().toLowerCase();
      } else {
        custState = shopState; // Walk-in = Local
      }
    }
    if (shopState.isEmpty) return false;
    return shopState != custState;
  }

  // --- CALCULATIONS (Identical to Stock Sale) ---
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

    // If manual entry has 0 tax, effective rate is 0
    if (effectiveRate == 0 && (igstRate + sgstRate + cgstRate) > 0) {
      // Fallback: If item was added as local (SG+CG) but now is inter-state,
      // logic implies we should convert. But for now we use stored values.
      effectiveRate = igstRate + sgstRate + cgstRate;
    }

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
      // Proportional split
      if (effectiveRate > 0) {
        if (sgstRate + cgstRate > 0) {
          valCgst = totalTax * (cgstRate / effectiveRate);
          valSgst = totalTax * (sgstRate / effectiveRate);
        } else {
          valCgst = totalTax / 2;
          valSgst = totalTax / 2;
        }
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

  // --- ACTIONS (ADD MANUAL ITEM) ---
  void _addItem() {
    if (_itemNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("⚠️ Enter Item Name")));
      return;
    }
    double price = double.tryParse(_priceCtrl.text) ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("⚠️ Enter Valid Price")));
      return;
    }

    int qty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (qty <= 0) qty = 1;

    setState(() {
      _cartItems.add(
        SoldItem(
          salesId: 0,
          itemName: _itemNameCtrl.text,
          qty: qty,
          amount: (qty * price).toDouble(),
          // Use the variables selected from dropdowns
          igst: _selectedIgst,
          sgst: _selectedSgst,
          cgst: _selectedCgst,
        ),
      );

      _itemNameCtrl.clear();
      _priceCtrl.clear();
      _qtyCtrl.text = "1";

      // Reset dropdowns to 0
      _selectedIgst = 0;
      _selectedSgst = 0;
      _selectedCgst = 0;

      _nameNode.requestFocus();
    });
  }

  // --- PAYMENT DIALOG (Identical to Stock Sale) ---
  void _showPaymentDialog() {
    final summary = _calculateSummary();
    final grandTotal = summary['final_amount']!;

    _selectedPaymentMode = "Cash";

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

            String upiData = "";
            if (_shopDetails != null &&
                _shopDetails!.upiId.isNotEmpty &&
                currentEnteredAmount > 0) {
              upiData =
                  "upi://pay?pa=${_shopDetails!.upiId}&pn=${_shopDetails!.name}&am=$currentEnteredAmount&tn=Quick Bill&cu=INR";
            }

            bool isUpiMode =
                _selectedPaymentMode.toLowerCase().contains("upi") ||
                _selectedPaymentMode.toLowerCase().contains("qr");

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
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
                      if (!_isNewCustomerMode && _selectedCustomer == null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
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

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Bill:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: secondaryText,
                              ),
                            ),
                            Text(
                              "₹${grandTotal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        "Payment Mode",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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

                      TextField(
                        controller: payCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                        decoration: InputDecoration(
                          labelText: "Received / Paying Amount",
                          labelStyle: const TextStyle(color: secondaryText),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(
                            Icons.currency_rupee,
                            color: accentColor,
                          ),
                        ),
                        onChanged: (val) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 20),

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
                              const Text(
                                "Balance to Return:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: secondaryText,
                                ),
                              ),
                              Text(
                                "₹${balance.abs().toStringAsFixed(2)} ${balance < 0 ? '(Due)' : ''}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
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
                                      style: const TextStyle(
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
    int? customerId;

    if (_isNewCustomerMode) {
      String newName = _newCustNameCtrl.text.trim();
      if (newName.isNotEmpty) {
        String newPhone = _newCustPhoneCtrl.text.trim();
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
        customerId = 0; // Walk-in
      }
    } else {
      customerId = _selectedCustomer?.id ?? 0;
    }

    List<SoldItem> finalItemsToSave = _cartItems.map((item) {
      // Recalculate based on saved item rates
      var bd = _calculateItemBreakdown(
        item.amount,
        item.igst,
        item.sgst,
        item.cgst,
      );
      return item;
    }).toList();

    int totalTaxInt =
        (summary['total_cgst']! +
                summary['total_sgst']! +
                summary['total_igst']!)
            .toInt();

    Sale newSale = Sale(
      customerId: customerId!,
      totalAmount: summary['total_taxable']!.toInt(),
      gstAmount: totalTaxInt,
      discountAmount: summary['total_discount']!.toInt(),
      finalAmount: summary['final_amount']!.toInt(),
      paid: paidAmount,
      isStockSales: false, // QUICK SALE
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
        isStockSales: false, // QUICK SALE
        paymentMode: _selectedPaymentMode,
        billedDate: DateTime.now().toIso8601String(),
        lastPaymentDate: DateTime.now().toIso8601String(),
      );
      Navigator.push(
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
        _itemNameCtrl.clear();
        _priceCtrl.clear();
        _qtyCtrl.text = "1";
        // Reset dropdowns
        _selectedIgst = 0;
        _selectedSgst = 0;
        _selectedCgst = 0;

        _newCustNameCtrl.clear();
        _newCustPhoneCtrl.clear();
        _newCustStateCtrl.clear();
        _selectedCustomer = null;
        _selectedPaymentMode = "Cash";
      });
    }
  }

  // --- WIDGETS ---

  // NEW: Dropdown builder
  Widget _buildCompactDropdown({
    required double value,
    required List<double> items,
    required ValueChanged<double?> onChanged,
  }) {
    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<double>(
        value: value,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: secondaryText),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildSearchableStateField(TextEditingController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: FocusNode(),
          optionsBuilder: (textValue) => _stateNames.where(
            (s) => s.toLowerCase().contains(textValue.text.toLowerCase()),
          ),
          onSelected: (s) => controller.text = s,
          fieldViewBuilder: (ctx, ctrl, focus, onEdit) => SizedBox(
            height: 45,
            child: TextFormField(
              controller: ctrl,
              focusNode: focus,
              onFieldSubmitted: (v) => onEdit(),
              decoration: const InputDecoration(
                hintText: "State",
                filled: true,
                fillColor: inputFill,
                prefixIcon: Icon(Icons.map, size: 18, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          optionsViewBuilder: (ctx, onSel, opts) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  itemCount: opts.length,
                  itemBuilder: (c, i) => ListTile(
                    title: Text(opts.elementAt(i)),
                    onTap: () => onSel(opts.elementAt(i)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaxInfoBox() {
    String shopState = (_shopDetails?.state ?? "").trim();
    String custState = "";
    if (_isNewCustomerMode) {
      custState = _newCustStateCtrl.text.trim();
      if (custState.isEmpty) custState = shopState;
    } else {
      custState = _selectedCustomer?.state.trim() ?? shopState;
    }
    if (shopState.isEmpty) shopState = "Shop";
    if (custState.isEmpty) custState = "Customer";
    bool isInter = _isInterStateSale();

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
          const SizedBox(width: 8),
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
                const SizedBox(height: 2),
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

  Widget _buildMiniStat(
    String label,
    double val, {
    bool isBold = false,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          "₹${val.toStringAsFixed(1)}",
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            "₹${val.abs().toStringAsFixed(2)}",
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

  @override
  Widget build(BuildContext context) {
    bool isInclusive = _prefs?.isGstInclusive ?? false;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Quick Sale",
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: primaryText,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSectionHeader("CUSTOMER DETAILS", Icons.person_outline),
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            const SizedBox(width: 10),
                            _buildTabBtn(
                              "New Customer",
                              _isNewCustomerMode,
                              () => setState(() => _isNewCustomerMode = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!_isNewCustomerMode)
                          LayoutBuilder(
                            builder: (ctx, c) => Autocomplete<Customer>(
                              optionsBuilder: (t) => _customers.where(
                                (c) => c.name.toLowerCase().contains(
                                  t.text.toLowerCase(),
                                ),
                              ),
                              displayStringForOption: (c) =>
                                  "${c.name} (${c.phoneNumber})",
                              onSelected: (c) =>
                                  setState(() => _selectedCustomer = c),
                              fieldViewBuilder: (ctx, ctrl, f, onE) =>
                                  _buildTextField(
                                    ctrl,
                                    "Search Customer",
                                    Icons.search,
                                    focus: f,
                                    onEdit: onE,
                                  ),
                              optionsViewBuilder:
                                  (context, onSelected, options) {
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
                                                Divider(height: 1),
                                            itemBuilder: (context, index) {
                                              final c = options.elementAt(
                                                index,
                                              );
                                              return InkWell(
                                                onTap: () => onSelected(c),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
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
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      Text(
                                                        c.phoneNumber,
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
                            ),
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
                                  const SizedBox(width: 10),
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
                              const SizedBox(height: 10),
                              _buildSearchableStateField(_newCustStateCtrl),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader("ADD ITEM (MANUAL)", Icons.edit_note),
                      Container(
                        padding: const EdgeInsets.symmetric(
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          _itemNameCtrl,
                          "Item Description / Name",
                          Icons.description,
                          focus: _nameNode,
                          onEdit: () => _priceNode.requestFocus(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextField(
                                _priceCtrl,
                                "Price",
                                Icons.currency_rupee,
                                type: TextInputType.number,
                                focus: _priceNode,
                                onEdit: () => _qtyNode.requestFocus(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 1,
                              child: _buildTextField(
                                _qtyCtrl,
                                "Qty",
                                null,
                                type: TextInputType.number,
                                focus: _qtyNode,
                                onEdit: _addItem,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // --- NEW: CONDITIONAL TAX DROPDOWNS ---
                        if (_isInterStateSale())
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("IGST %"),
                              _buildCompactDropdown(
                                value: _selectedIgst,
                                items: _igstRates,
                                onChanged: (val) => setState(() {
                                  _selectedIgst = val!;
                                  _selectedSgst = val / 2;
                                  _selectedCgst = val / 2;
                                }),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("CGST %"),
                                    _buildCompactDropdown(
                                      value: _selectedCgst,
                                      items: _stateGstRates,
                                      onChanged: (val) => setState(() {
                                        _selectedCgst = val!;
                                        _selectedSgst = val!;
                                        _selectedIgst = val * 2;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("SGST %"),
                                    _buildCompactDropdown(
                                      value: _selectedSgst,
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

                        // ----------------------------------------
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: _addItem,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
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
                  const SizedBox(height: 20),
                  if (_cartItems.isNotEmpty) ...[
                    _buildSectionHeader(
                      "ITEMS (${_cartItems.length})",
                      Icons.receipt_long,
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cartItems.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final item = _cartItems[i];
                        var bd = _calculateItemBreakdown(
                          item.amount,
                          item.igst,
                          item.sgst,
                          item.cgst,
                        );
                        bool interState = _isInterStateSale();
                        String rateStr = interState
                            ? "IGST: ${item.igst.toStringAsFixed(0)}%"
                            : "GST: ${(item.cgst + item.sgst).toStringAsFixed(0)}%";
                        return Container(
                          padding: const EdgeInsets.all(12),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: primaryText,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _cartItems.removeAt(i)),
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    "${item.qty} x ${item.amount / item.qty}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: secondaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
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
                              const Divider(height: 16),
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
                    const SizedBox(height: 30),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "PAYMENT SUMMARY",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildTaxInfoBox(),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                "Discount %",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: primaryText,
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 80,
                                height: 35,
                                child: TextField(
                                  controller: _discountCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  onChanged: (v) => setState(() {}),
                                  decoration: const InputDecoration(
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
                          const Divider(height: 24),
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
                          const SizedBox(height: 8),
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
                          const Divider(height: 30, thickness: 1.2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Grand Total",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              Text(
                                "₹${_calculateSummary()['final_amount']!.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
                              child: const Text(
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
                    const Padding(
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

  // --- Helpers for Dropdown UI ---
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
}
