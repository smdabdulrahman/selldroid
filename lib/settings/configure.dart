import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/print_helper.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:selldroid/theme_provider.dart';

class ConfigurePage extends StatefulWidget {
  const ConfigurePage({super.key});

  @override
  State<ConfigurePage> createState() => _ConfigurePageState();
}

class _ConfigurePageState extends State<ConfigurePage> {
  // --- State ---
  String _currentCurrency = "₹ (INR)"; // Default UI display
  String? _connectedPrinterName;
  bool _isLoading = true;

  // New State for Paper Size
  int? _paperSize; // Default to 3 inch

  // Global Currency List (Symbol + Name)
  final List<String> _currencyList = [
    "₹ (INR)",
    "\$ (USD)",
    "€ (EUR)",
    "£ (GBP)",
    "¥ (JPY)",
    "د.إ (AED)",
    "৳ (BDT)",
    "Rs (PKR)",
  ];

  // Simulated Bluetooth Devices
  List<String> _availablePrinters = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    // 1. Fetch Currency using your Model
    Currency? savedCurrency = await DatabaseHelper.instance.getCurrency();
    String dbSymbol = savedCurrency?.name ?? "₹";

    String matchedCurrency = _currencyList.firstWhere(
      (element) => element.startsWith(dbSymbol),
      orElse: () => "₹ (INR)",
    );

    // 2. Fetch Printer using your Model
    Printer? savedPrinter = await DatabaseHelper.instance.getPrinter();

    // 3. (Optional) Fetch Paper Size if you have a method for it
    // int savedSize = await DatabaseHelper.instance.getPaperSize() ?? 2;

    setState(() {
      _currentCurrency = matchedCurrency;
      _connectedPrinterName = savedPrinter?.name;
      if (savedPrinter != null) _paperSize = savedPrinter!.width;

      _isLoading = false;
    });
  }

  // --- SAVE LOGIC ---
  Future<void> _saveCurrency(String fullString) async {
    String symbol = fullString.split(" ")[0];
    await DatabaseHelper.instance.setCurrency(symbol);

    setState(() => _currentCurrency = fullString);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Currency updated to $symbol")));
  }

  Future<void> _savePrinter(String name) async {
    if (_paperSize == null) {
      setState(() {
        _paperSize = 3;
      });
    }
    await DatabaseHelper.instance.setPrinter(name, _paperSize!);
    setState(() => _connectedPrinterName = name);
    Navigator.pop(context);
  }

  // Helper to change paper size
  void _selectPaperSize(int size) {
    setState(() {
      _paperSize = size;
    });
    if (_connectedPrinterName != null && _connectedPrinterName!.isNotEmpty) {
      DatabaseHelper.instance.setPrinter(_connectedPrinterName!, _paperSize!);
    }
    // Add DatabaseHelper.instance.setPaperSize(size) here if needed
  }

  // --- UI: Scan Dialog (Simulated) ---
  void _showPrinterScanDialog() async {
    List<String> ps = [];
    (await PrintHelper.pairedDevices(context)).forEach((e) {
      ps.add(e.name);
    });
    setState(() {
      _availablePrinters = ps;
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Paired Bluetooth Devices"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availablePrinters.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.print, color: Colors.blueGrey),
                  title: Text(_availablePrinters[index]),
                  onTap: () => _savePrinter(_availablePrinters[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  // --- WIDGET: Modern Paper Size Button ---
  Widget _buildPaperSizeBtn(int size, String label, Color accentColor) {
    bool isSelected = _paperSize == size;
    return Expanded(
      child: InkWell(
        onTap: () => _selectPaperSize(size),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentColor : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      appBar: AppBar(
        title: const Text(
          "Configuration",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: CURRENCY ---
                  const Text(
                    "CURRENCY SETTINGS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currentCurrency,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: _currencyList.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2585A1),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) _saveCurrency(newValue);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- SECTION 2: BLUETOOTH PRINTER ---
                  const Text(
                    "PRINTER SETTINGS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
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
                        // --- NEW: Paper Size Selection ---
                        const Text(
                          "Paper Size",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPaperSizeBtn(
                              2,
                              "2 Inch (58mm)",
                              theme.accentColor,
                            ),
                            const SizedBox(width: 15),
                            _buildPaperSizeBtn(
                              3,
                              "3 Inch (80mm)",
                              theme.accentColor,
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(),
                        ),

                        // --- Existing: Printer Connection ---
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.bluetooth,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Connected Printer",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _connectedPrinterName ??
                                      "No Printer Selected",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _connectedPrinterName != null
                                        ? Colors.black
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showPrinterScanDialog,
                            icon: const Icon(Icons.search, color: Colors.white),
                            label: const Text(
                              "Scan & Select Printer",
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accentColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Only paired devices can be selected. Please pair your printer in Bluetooth settings first.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
