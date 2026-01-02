import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/file_helper.dart';
import 'package:selldroid/models/shop.dart';

class EditShopDetailsScreen extends StatefulWidget {
  const EditShopDetailsScreen({super.key});

  @override
  State<EditShopDetailsScreen> createState() => _EditShopDetailsScreenState();
}

class _EditShopDetailsScreenState extends State<EditShopDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _upiController = TextEditingController();
  final _stateController = TextEditingController();

  List<dynamic> _statesList = [];
  List<String> _stateNames = [];
  bool _isLoadingStates = false;

  File? _logoImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoadingData = true;

  // --- NEW: Variables to track original data and navigation ---
  ShopDetails? _originalShop;
  bool _allowPop = false; // To control the PopScope manually

  // Colors
  static const Color bgColor = Color(0xFFE8ECEF);
  static const Color primaryText = Color(0xFF46494C);
  static const Color secondaryText = Color(0xFF757575);
  static const Color accentColor = Color(0xFF2585A1);
  static const Color cardColor = Colors.white;
  static const Color inputFill = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();

    _fetchStates().then((_) {
      _loadCurrentData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _upiController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  // --- NEW: Check if any data has changed ---
  bool _hasUnsavedChanges() {
    if (_originalShop == null) return false;

    // Check Image: Compare current path with original path
    // If _logoImage is null, check if original was empty.
    // If _logoImage is not null, check if path matches original.
    String currentLogoPath = _logoImage?.path ?? "";
    if (currentLogoPath != _originalShop!.logo) return true;

    // Check Text Fields
    if (_nameController.text.trim() != _originalShop!.name) return true;
    if (_phoneController.text.trim() != _originalShop!.phoneNumber) return true;
    if (_addressController.text.trim() != _originalShop!.address) return true;
    if (_cityController.text.trim() != _originalShop!.city) return true;
    if (_stateController.text.trim() != _originalShop!.state) return true;
    if (_upiController.text.trim() != _originalShop!.upiId) return true;

    return false;
  }

  // --- NEW: Handle Back Navigation & Show Dialog ---
  Future<void> _handlePopRequest() async {
    // If no changes, allow exit immediately
    if (!_hasUnsavedChanges()) {
      setState(() => _allowPop = true); // Unlock the door
      if (mounted) Navigator.pop(context);
      return;
    }

    // If changes exist, show "Neat" Dialog
    final bool shouldDiscard =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text("Unsaved Changes"),
              ],
            ),
            content: const Text(
              "You have unsaved changes. Are you sure you want to discard them and leave?",
              style: TextStyle(fontSize: 15, color: primaryText),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            actions: [
              // Cancel Button
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(false), // Return false
                style: TextButton.styleFrom(foregroundColor: secondaryText),
                child: const Text("Keep Editing"),
              ),
              // Discard Button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true), // Return true
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Discard",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    // If user clicked Discard, allow exit
    if (shouldDiscard) {
      setState(() => _allowPop = true); // Unlock the door
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _fetchStates() async {
    // ... (Your existing code remains exactly the same) ...
    setState(() => _isLoadingStates = true);
    var headers = {
      'X-CSCAPI-KEY':
          'eGNkOGtuYk42RmtCdVc1bDczbzI5eE9MZGdGTk5tN2NNY1Y1MktQaQ==',
    };

    try {
      var request = http.Request(
        'GET',
        Uri.parse('https://api.countrystatecity.in/v1/countries/IN/states'),
      );
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String data = await response.stream.bytesToString();
        if (mounted) {
          setState(() {
            _statesList = jsonDecode(data);
            _stateNames = _statesList
                .map<String>((e) => e['name'].toString())
                .toList();
            _isLoadingStates = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStates = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStates = false);
    }
  }

  Future<void> _loadCurrentData() async {
    try {
      ShopDetails shop = await DatabaseHelper.instance.getShopDetails();
      if (mounted) {
        setState(() {
          // --- NEW: Store original data for comparison ---
          _originalShop = shop;

          _nameController.text = shop.name;
          _phoneController.text = shop.phoneNumber;
          _addressController.text = shop.address;
          _cityController.text = shop.city;
          _upiController.text = shop.upiId;
          _stateController.text = shop.state;

          if (shop.logo.isNotEmpty) {
            _logoImage = File(shop.logo);
          }
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => _isLoadingData = false);
    }
  }

  // ... (pickImage and saveChanges remain same) ...
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        pickedFile.saveTo(FileHelper.dir.path + "/" + pickedFile.name);
        _logoImage = File(FileHelper.dir.path + "/" + pickedFile.name);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      ShopDetails updatedShop = ShopDetails(
        id: 1,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        logo: _logoImage?.path ?? "",
        upiId: _upiController.text.trim(),
      );

      await DatabaseHelper.instance.updateShopDetails(updatedShop);

      if (mounted) {
        showAutoCloseSuccessDialog(
          context: context,
          message: "Shop Details Updated Successfully",
          onCompleted: () {
            setState(() => _allowPop = true);
            Navigator.pop(context, true);
          },
        );

        // --- NEW: Since we saved, we can allow pop without dialog ---
      }
    }
  }

  void showAutoCloseSuccessDialog({
    required BuildContext context,
    required String message,
    VoidCallback? onCompleted, // Optional: What to do after closing
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // User can't click outside to close
      builder: (BuildContext dialogContext) {
        // --- AUTOMATIC TIMER ---
        Future.delayed(const Duration(seconds: 2), () {
          // 1. Close the Dialog
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }

          // 2. Execute next step (Navigate or Refresh)
          if (onCompleted != null) {
            onCompleted();
          }
        });

        // --- DIALOG UI ---
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated-style Static Icon
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Success!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    // --- NEW: Wrap Scaffold in PopScope ---
    // This intercepts the System Back Button (Android gesture/button)
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // If pop was allowed, do nothing
        _handlePopRequest(); // If pop was blocked, show logic
      },
      child: Scaffold(
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
            // --- NEW: Call our custom back handler instead of direct pop ---
            onPressed: _handlePopRequest,
          ),
          title: const Text(
            "Edit Shop Details",
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ... (Rest of your UI code remains exactly the same as previous step) ...
                // Logo Section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _logoImage != null
                            ? FileImage(_logoImage!)
                            : null,
                        child: _logoImage == null
                            ? const Icon(
                                Icons.store,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Fields
                _buildCard(
                  children: [
                    _buildLabel("SHOP NAME"),
                    _buildTextField(_nameController, "Shop Name", Icons.store),
                    const SizedBox(height: 16),

                    _buildLabel("PHONE NUMBER"),
                    _buildTextField(
                      _phoneController,
                      "Phone",
                      Icons.phone,
                      inputType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel("UPI ID (Optional)"),
                    _buildTextField(
                      _upiController,
                      "e.g. shopname@okhdfcbank",
                      Icons.qr_code,
                      isRequired: false,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildCard(
                  children: [
                    _buildLabel("ADDRESS"),
                    _buildTextField(
                      _addressController,
                      "Street Address",
                      Icons.location_on,
                    ),
                    const SizedBox(height: 16),

                    // CITY & STATE (Updated Vertical Layout from previous request)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("CITY"),
                        _buildTextField(
                          _cityController,
                          "City",
                          Icons.location_city,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("STATE"),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return RawAutocomplete<String>(
                              textEditingController: _stateController,
                              focusNode: FocusNode(),
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (_stateNames.isEmpty) {
                                      return const Iterable<String>.empty();
                                    }
                                    if (textEditingValue.text.isEmpty) {
                                      return _stateNames;
                                    }
                                    return _stateNames.where((String option) {
                                      return option.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      );
                                    });
                                  },
                              onSelected: (String selection) {
                                _stateController.text = selection;
                              },
                              fieldViewBuilder:
                                  (
                                    BuildContext context,
                                    TextEditingController textEditingController,
                                    FocusNode focusNode,
                                    VoidCallback onFieldSubmitted,
                                  ) {
                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      onFieldSubmitted: (String value) =>
                                          onFieldSubmitted(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: primaryText,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      validator: (val) =>
                                          val!.isEmpty ? "Required" : null,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: inputFill,
                                        hintText: "Select State",
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.map_outlined,
                                          color: Colors.grey[400],
                                          size: 20,
                                        ),
                                        suffixIcon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    );
                                  },
                              optionsViewBuilder:
                                  (
                                    BuildContext context,
                                    AutocompleteOnSelected<String> onSelected,
                                    Iterable<String> options,
                                  ) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4.0,
                                        color: Colors.white,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            bottom: Radius.circular(10),
                                          ),
                                        ),
                                        child: Container(
                                          width: constraints.maxWidth,
                                          constraints: const BoxConstraints(
                                            maxHeight: 200,
                                          ),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            itemCount: options.length,
                                            itemBuilder:
                                                (
                                                  BuildContext context,
                                                  int index,
                                                ) {
                                                  final String option = options
                                                      .elementAt(index);
                                                  return ListTile(
                                                    title: Text(
                                                      option,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: primaryText,
                                                      ),
                                                    ),
                                                    dense: true,
                                                    onTap: () =>
                                                        onSelected(option),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _allowPop ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Save Changes",
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
        ),
      ),
    );
  }

  // --- Helper Widgets (No changes needed here) ---
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: secondaryText,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: (val) => (isRequired && val!.isEmpty) ? "Required" : null,
      style: const TextStyle(
        fontSize: 14,
        color: primaryText,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: inputFill,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
      ),
    );
  }
}
