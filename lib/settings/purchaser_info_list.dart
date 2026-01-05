import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import HTTP
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/show_dialog_boxes.dart';
import 'package:selldroid/theme_provider.dart';

class PurchasersListScreen extends StatefulWidget {
  const PurchasersListScreen({super.key});

  @override
  State<PurchasersListScreen> createState() => _PurchasersListScreenState();
}

class _PurchasersListScreenState extends State<PurchasersListScreen> {
  // --- State ---
  List<SupplierInfo> _suppliers = [];
  List<String> _stateNames = []; // Stores API States
  bool _isLoading = true;
  bool _isLoadingStates = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _fetchStates(); // Fetch states on load
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllSuppliers();
    if (mounted) {
      setState(() {
        _suppliers = data;
        _isLoading = false;
      });
    }
  }

  // --- API: Fetch States ---
  Future<void> _fetchStates() async {
    setState(() => _isLoadingStates = true);
    try {
      var request = http.Request(
        'GET',
        Uri.parse('https://api.countrystatecity.in/v1/countries/IN/states'),
      );
      request.headers['X-CSCAPI-KEY'] =
          'eGNkOGtuYk42RmtCdVc1bDczbzI5eE9MZGdGTk5tN2NNY1Y1MktQaQ=='; // Use your key
      var response = await request.send();
      if (response.statusCode == 200) {
        String data = await response.stream.bytesToString();
        List<dynamic> jsonList = jsonDecode(data);
        if (mounted) {
          setState(() {
            _stateNames = jsonList
                .map<String>((e) => e['name'].toString())
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStates = false);
    }
  }

  // --- MODERN ADD SHEET (Replaces Alert Dialog) ---
  // --- MODERN ADD SHEET (Replaces Alert Dialog) ---
  void _showAddSupplierSheet() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: "0");
    final stateController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Required for full height control
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        // Wrap Container in Padding
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(
            context,
          ).viewInsets.bottom, // Add padding for keyboard
        ),
        child: Container(
          height:
              MediaQuery.of(context).size.height *
              0.55, // Increased height slightly
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24, // Fixed bottom padding inside the card
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              // Add ScrollView to prevent overflow on small screens
              child: Column(
                mainAxisSize: MainAxisSize.min, // Wrap content tightly
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Add Supplier",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel("NAME (COMPANY / PERSON)"),
                  _buildTextField(
                    nameController,
                    "e.g. ABC Traders",
                    Icons.business,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("STATE"),
                            _buildSearchableStateField(stateController),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("OPENING BAL"),
                            _buildTextField(
                              balanceController,
                              "0",
                              Icons.account_balance_wallet,
                              isNumber: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Positive Balance = You owe them money",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ), // Added spacing instead of Spacer()

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          int openingBal =
                              int.tryParse(balanceController.text) ?? 0;

                          // 1. Create Supplier Object
                          SupplierInfo newSupplier = SupplierInfo(
                            name: nameController.text.trim(),
                            balance: openingBal,
                            state: stateController.text.trim().isEmpty
                                ? "Tamil Nadu"
                                : stateController.text.trim(),
                          );

                          // 2. Add Supplier AND capture the new ID
                          // (Ensure your DatabaseHelper.addSupplier returns the 'int' ID)
                          int newSupplierId = await DatabaseHelper.instance
                              .addSupplier(newSupplier);

                          // 3. LOGIC: If Opening Balance > 0, create a "Purchase"
                          if (openingBal > 0) {
                            // A. Create the "Opening Balance" Item
                            List<PurchaseItem> items = [
                              PurchaseItem(
                                itemName: "Opening Balance",
                                qty: 1,
                                amount: openingBal.toDouble(),
                                gstRate: 0,
                                gstAmount: 0,
                              ),
                            ];

                            // B. Create the Purchase Header linked to newSupplierId

                            // C. Save to Database
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            _loadSuppliers();
                            ShowDialogBoxes.showAutoCloseSuccessDialog(
                              context: context,
                              message: "Supplier Added",
                            );
                          }
                        }
                      },
                      child: const Text(
                        "Save Supplier",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  late Color bgColor;
  late Color primaryText;
  late Color secondaryText;
  late Color accentColor;
  late Color cardColor;
  late Color inputFill;
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    bgColor = theme.bgColor;
    primaryText = theme.primaryText;
    secondaryText = theme.secondaryText;
    accentColor = theme.accentColor;
    cardColor = theme.cardColor;
    inputFill = const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Suppliers List",
          style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryText),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSupplierSheet,
        backgroundColor: accentColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add New",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No Suppliers Added",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _suppliers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final supplier = _suppliers[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 45,
                        width: 45,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            supplier.name.isNotEmpty
                                ? supplier.name[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: secondaryText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  supplier.state,
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Balance",
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₹${supplier.balance}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: supplier.balance > 0
                                  ? Colors.redAccent
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // --- WIDGETS ---

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: secondaryText,
      ),
    ),
  );

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (val) => val!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: inputFill,
        prefixIcon: Icon(icon, color: secondaryText, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: TextStyle(
        fontSize: 14,
        color: primaryText,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSearchableStateField(TextEditingController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: FocusNode(),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (_stateNames.isEmpty) return const Iterable<String>.empty();
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
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onFieldSubmitted: (String value) => onFieldSubmitted(),
                  decoration: InputDecoration(
                    hintText: _isLoadingStates ? "Loading..." : "State",
                    filled: true,
                    fillColor: inputFill,
                    prefixIcon: Icon(Icons.map, color: secondaryText, size: 20),
                    suffixIcon: Icon(
                      Icons.arrow_drop_down,
                      color: secondaryText,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryText,
                    fontWeight: FontWeight.w600,
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(
                          option,
                          style: const TextStyle(fontSize: 14),
                        ),
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
}
