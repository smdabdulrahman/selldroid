import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/show_dialog_boxes.dart';
import 'package:selldroid/theme_provider.dart';

class ManageCustomersScreen extends StatefulWidget {
  const ManageCustomersScreen({super.key});

  @override
  State<ManageCustomersScreen> createState() => _ManageCustomersScreenState();
}

class _ManageCustomersScreenState extends State<ManageCustomersScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _stateController = TextEditingController();
  final _searchController = TextEditingController();

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  List<String> _stateNames = [];

  bool _isLoading = true;
  bool _isLoadingStates = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _fetchStates();
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final list = await DatabaseHelper.instance.getCustomers();
    if (mounted) {
      setState(() {
        _allCustomers = list;
        _filteredCustomers = list;
        _isLoading = false;
      });
    }
  }

  void _filterCustomers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        return c.name.toLowerCase().contains(query) ||
            c.phoneNumber.contains(query);
      }).toList();
    });
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
        if (mounted)
          setState(
            () => _stateNames = jsonList
                .map<String>((e) => e['name'].toString())
                .toList(),
          );
      }
    } catch (e) {
      debugPrint("API Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStates = false);
    }
  }

  Future<void> _addCustomer() async {
    if (_formKey.currentState!.validate()) {
      final newCustomer = Customer(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? "Tamil Nadu"
            : _stateController.text.trim(),
      );
      await DatabaseHelper.instance.addCustomer(newCustomer);
      if (mounted) {
        ShowDialogBoxes.showAutoCloseSuccessDialog(
          context: context,
          message: "Customer Added",
        );
        _nameController.clear();
        _phoneController.clear();
        _stateController.clear();
        FocusScope.of(context).unfocus();
        _loadCustomers();
      }
    }
  }

  Future<void> _deleteCustomer(int id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Customer?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: TextStyle(color: deleteColor)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteCustomer(id);
      _loadCustomers();
    }
  }

  void _showEditSheet(Customer customer) {
    final nameEditCtrl = TextEditingController(text: customer.name);
    final phoneEditCtrl = TextEditingController(text: customer.phoneNumber);
    final stateEditCtrl = TextEditingController(text: customer.state);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
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
              "Edit Customer",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel("FULL NAME"),
            _buildTextField(nameEditCtrl, "Name", Icons.person),
            const SizedBox(height: 16),
            _buildLabel("PHONE NUMBER"),
            _buildTextField(
              phoneEditCtrl,
              "Phone",
              Icons.phone,
              isNumber: true,
            ),
            const SizedBox(height: 16),
            _buildLabel("STATE"),
            _buildSearchableStateField(stateEditCtrl),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: secondaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameEditCtrl.text.isNotEmpty) {
                        customer.name = nameEditCtrl.text.trim();
                        customer.phoneNumber = phoneEditCtrl.text.trim();
                        customer.state = stateEditCtrl.text.trim();
                        await DatabaseHelper.instance.updateCustomer(customer);
                        if (mounted) {
                          Navigator.pop(context);
                          _loadCustomers();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Save Changes",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  late Color bgColor;
  late Color primaryText;
  late Color secondaryText;
  late Color accentColor;
  late Color cardColor;
  final deleteColor = const Color(0xFFEF5350);
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
          icon: Icon(Icons.arrow_back_ios_new, color: primaryText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Manage Customers",
          style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- COMPACT ADD FORM ---
            Container(
              padding: const EdgeInsets.all(12), // Compact padding
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add New Customer",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ROW 1: NAME (Full Width)
                    _buildLabel("CUSTOMER NAME"),
                    _buildTextField(_nameController, "John Doe", Icons.person),

                    const SizedBox(height: 10),

                    // ROW 2: STATE + PHONE (Side by Side)
                    Row(
                      children: [
                        Expanded(
                          flex: 1, // State gets equal width
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("STATE"),
                              _buildSearchableStateField(_stateController),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1, // Phone gets equal width
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("PHONE"),
                              _buildTextField(
                                _phoneController,
                                "9876543210",
                                Icons.phone,
                                isNumber: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ROW 3: ADD BUTTON (Full Width, 32px height)
                    SizedBox(
                      width: double.infinity,
                      height: 32, // Forced Height
                      child: ElevatedButton(
                        onPressed: _addCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          "ADD CUSTOMER",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- SEARCH BAR ---
            SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search customer...",
                  prefixIcon: Icon(
                    Icons.search,
                    color: secondaryText,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),

            const SizedBox(height: 12),

            // --- CUSTOMER LIST ---
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_filteredCustomers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    _allCustomers.isEmpty
                        ? "No customers added yet."
                        : "No matching customers found.",
                    style: TextStyle(color: secondaryText),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredCustomers.length,
                separatorBuilder: (c, i) =>
                    const SizedBox(height: 8), // Tighter list spacing
                itemBuilder: (context, index) {
                  return _buildCustomerCard(_filteredCustomers[index]);
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- COMPACT WIDGETS ---

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
                // Using Sized Box to enforce 32px height
                return SizedBox(
                  height: 42,
                  child: TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onFieldSubmitted: (String value) => onFieldSubmitted(),
                    decoration: InputDecoration(
                      hintText: _isLoadingStates ? "Loading..." : "State",
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      prefixIcon: Icon(
                        Icons.map,
                        color: secondaryText,
                        size: 16,
                      ), // Smaller Icon
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 8,
                      ), // Adjusted padding
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13), // Smaller Font
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
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () => onSelected(option),
                        dense: true,
                        visualDensity: VisualDensity.compact,
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

  Widget _buildCustomerCard(Customer customer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${customer.phoneNumber} • ${customer.state}",
                  style: TextStyle(color: secondaryText, fontSize: 11),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: secondaryText, size: 18),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'edit') _showEditSheet(customer);
              if (value == 'delete') _deleteCustomer(customer.id!);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                height: 35,
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text("Edit", style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                height: 35,
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: deleteColor),
                    SizedBox(width: 8),
                    Text(
                      "Delete",
                      style: TextStyle(color: deleteColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4, left: 2), // Tighter label padding
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
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
    // Enforcing 32px Height
    return SizedBox(
      height: 40,
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        validator: (val) => val!.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          hintText: hint,
          errorStyle: TextStyle(fontSize: 0, height: 0),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          prefixIcon: Icon(
            icon,
            color: secondaryText,
            size: 16,
          ), // Smaller Icon
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 8,
          ), // Adjusted Padding
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13), // Smaller Font
      ),
    );
  }
}
