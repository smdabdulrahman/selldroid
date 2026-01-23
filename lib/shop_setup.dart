import 'dart:convert'; // Import for JSON decoding
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import HTTP package
import 'package:image_picker/image_picker.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/file_helper.dart';
import 'package:selldroid/home.dart';
import 'package:selldroid/introduction_screen.dart';
import 'package:selldroid/models/shop.dart';

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _upiController = TextEditingController();

  // State Controller (Searchable)
  final _stateController =
      TextEditingController(); // Stores the selected state text

  List<dynamic> _statesList = [];
  List<String> _stateNames = []; // Simple list for search
  bool _isLoadingStates = false;

  File? _logoImage;
  final ImagePicker _picker = ImagePicker();

  // State to track if button should be enabled
  bool _isFormValid = false;

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
    _fetchStates();

    // Add listeners for live validation
    _nameController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _addressController.addListener(_validateForm);
    _cityController.addListener(_validateForm);
    _stateController.addListener(_validateForm);
  }

  // --- API: Fetch States ---
  Future<void> _fetchStates() async {
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
            // Convert to simple list for easier searching
            _stateNames = _statesList
                .map<String>((e) => e['name'].toString())
                .toList();
          });
        }
      } else {
        debugPrint(response.reasonPhrase);
      }
    } catch (e) {
      debugPrint("Error fetching states: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingStates = false);
      }
    }
  }

  void _validateForm() {
    bool isValid =
        _nameController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _addressController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _stateController.text.isNotEmpty; // Check state text

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

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

  Future<void> _saveShopDetails() async {
    if (_formKey.currentState!.validate()) {
      ShopDetails shop = ShopDetails(
        id: 1,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(), // Use text from controller
        phoneNumber: _phoneController.text.trim(),
        logo: _logoImage?.path ?? "",
        upiId: _upiController.text.trim(),
      );

      await DatabaseHelper.instance.updateShopDetails(shop);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Shop Details Saved Successfully!")),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return IntroScreen();
            },
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          "Shop Details",
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              // --- 1. Logo Upload ---
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFFF0F0F0),
                            backgroundImage: _logoImage != null
                                ? FileImage(_logoImage!)
                                : null,
                            child: _logoImage == null
                                ? Icon(
                                    Icons.storefront,
                                    size: 40,
                                    color: Colors.grey[400],
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Shop Logo",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Tap to upload a new logo",
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- 2. Basic Information ---
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.store, "BASIC INFORMATION"),
                    const SizedBox(height: 20),

                    _buildLabel("SHOP NAME"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: "e.g. Droid Electronics",
                      inputAction: TextInputAction.next,
                      validator: (value) =>
                          value!.isEmpty ? "Enter Shop Name" : null,
                    ),

                    const SizedBox(height: 20),

                    _buildLabel("PHONE NUMBER"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _phoneController,
                      hint: "+91 98765 43210",
                      inputType: TextInputType.phone,
                      inputAction: TextInputAction.next,
                      suffixIcon: Icons.phone,
                      validator: (value) =>
                          value!.isEmpty ? "Enter Phone Number" : null,
                    ),
                    _buildLabel("UPI ID (Optional)"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _upiController,
                      hint: "e.g. shopname@okhdfcbank",
                      inputAction: TextInputAction.next,
                      suffixIcon: Icons.qr_code,
                      validator: (value) => null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- 3. Address Details ---
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.location_on, "ADDRESS DETAILS"),
                    const SizedBox(height: 20),

                    _buildLabel("STREET ADDRESS"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _addressController,
                      hint: "Building name, Street no, Area...",
                      inputAction: TextInputAction.next,
                      validator: (value) =>
                          value!.isEmpty ? "Enter Address" : null,
                    ),

                    const SizedBox(height: 20),

                    // CITY & STATE ROW
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CITY INPUT
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("CITY"),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _cityController,
                              hint: "e.g. Mumbai",
                              inputAction: TextInputAction.done,
                              validator: (value) =>
                                  value!.isEmpty ? "Enter City" : null,
                            ),
                          ],
                        ),
                        const SizedBox(width: 10, height: 10),

                        // SEARCHABLE STATE DROPDOWN
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("STATE"),
                            const SizedBox(height: 8),

                            // Using LayoutBuilder to match dropdown width to text field
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return RawAutocomplete<String>(
                                  textEditingController: _stateController,
                                  focusNode: FocusNode(),

                                  // 1. FILTER LOGIC
                                  optionsBuilder:
                                      (TextEditingValue textEditingValue) {
                                        if (_stateNames.isEmpty) {
                                          return const Iterable<String>.empty();
                                        }
                                        if (textEditingValue.text.isEmpty) {
                                          return _stateNames; // Show all states if typing nothing
                                        }
                                        return _stateNames.where((
                                          String option,
                                        ) {
                                          return option.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          );
                                        });
                                      },

                                  // 2. SELECTION LOGIC
                                  onSelected: (String selection) {
                                    _stateController.text = selection;
                                    _validateForm(); // Re-validate
                                  },

                                  // 3. INPUT FIELD UI
                                  fieldViewBuilder:
                                      (
                                        BuildContext context,
                                        TextEditingController
                                        textEditingController,
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
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: inputFill,
                                            hintText: "Select State",
                                            hintStyle: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 14,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 14,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide.none,
                                            ),
                                            // Dropdown Icon
                                            suffixIcon: const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                          ),
                                        );
                                      },

                                  // 4. DROPDOWN LIST UI
                                  optionsViewBuilder:
                                      (
                                        BuildContext context,
                                        AutocompleteOnSelected<String>
                                        onSelected,
                                        Iterable<String> options,
                                      ) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            color: Colors.white,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(10),
                                              ),
                                            ),
                                            // Force width to match parent widget
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
                                                      final String option =
                                                          options.elementAt(
                                                            index,
                                                          );
                                                      return ListTile(
                                                        title: Text(
                                                          option,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                color:
                                                                    primaryText,
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
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- 4. Save Button ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isFormValid ? _saveShopDetails : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _isFormValid ? 4 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Save Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isFormValid ? Colors.white : Colors.grey[500],
                        ),
                      ),
                      if (_isFormValid) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check, color: Colors.white, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: accentColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryText,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: secondaryText,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType inputType = TextInputType.text,
    TextInputAction inputAction = TextInputAction.next,
    IconData? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      textInputAction: inputAction,
      validator: validator,
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
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: Colors.grey[400], size: 20)
            : null,
      ),
    );
  }
}
