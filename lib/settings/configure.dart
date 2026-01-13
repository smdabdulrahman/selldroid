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

    // Logic: Match the saved symbol (e.g., "$") to our full list item ("$ (USD)")
    // If no match found, fallback to the first item that starts with it, or default.
    String matchedCurrency = _currencyList.firstWhere(
      (element) => element.startsWith(dbSymbol),
      orElse: () => "₹ (INR)",
    );

    // 2. Fetch Printer using your Model
    Printer? savedPrinter = await DatabaseHelper.instance.getPrinter();

    setState(() {
      _currentCurrency = matchedCurrency;
      _connectedPrinterName =
          savedPrinter?.name; // Accessing .name from your model
      _isLoading = false;
    });
  }

  // --- SAVE LOGIC ---
  Future<void> _saveCurrency(String fullString) async {
    // We only want to save the symbol (e.g., "₹") into the DB, not "₹ (INR)"
    String symbol = fullString.split(" ")[0];

    await DatabaseHelper.instance.setCurrency(symbol);

    setState(() => _currentCurrency = fullString);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Currency updated to $symbol")));
  }

  Future<void> _savePrinter(String name) async {
    await DatabaseHelper.instance.setPrinter(name);

    setState(() => _connectedPrinterName = name);
    Navigator.pop(context); // Close dialog
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
                      children: [
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
                        Text(
                          "Only paired devices can be selected. Please pair your printer in Bluetooth settings first.",
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
