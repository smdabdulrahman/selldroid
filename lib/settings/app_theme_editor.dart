import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:selldroid/theme_provider.dart';

class AppThemeEditorPage extends StatefulWidget {
  const AppThemeEditorPage({super.key});

  @override
  State<AppThemeEditorPage> createState() => _AppThemeEditorPageState();
}

class _AppThemeEditorPageState extends State<AppThemeEditorPage> {
  // Helper to open the picker and save to Provider
  void _pickColor(
    BuildContext context,
    String label,
    Color currentColor,
    Function(Color) onSave,
  ) {
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pick $label Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (c) => tempColor = c,
            showLabel: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(tempColor); // Call the save callback
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access the provider to listen for changes
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Map the Provider values to a list for easy display
    // We use a List of Maps so we can define the Label, Value, and Update Logic together
    final List<Map<String, dynamic>> themeItems = [
      {
        'label': 'Background Color',
        'color': themeProvider.bgColor,
        'onUpdate': (Color c) => themeProvider.updateTheme(newBgColor: c),
      },
      {
        'label': 'Primary Text',
        'color': themeProvider.primaryText,
        'onUpdate': (Color c) => themeProvider.updateTheme(newPrimaryText: c),
      },
      {
        'label': 'Secondary Text',
        'color': themeProvider.secondaryText,
        'onUpdate': (Color c) => themeProvider.updateTheme(newSecondaryText: c),
      },
      {
        'label': 'Accent Color',
        'color': themeProvider.accentColor,
        'onUpdate': (Color c) => themeProvider.updateTheme(newAccentColor: c),
      },
      {
        'label': 'Card/Surface Color',
        'color': themeProvider.cardColor,
        'onUpdate': (Color c) => themeProvider.updateTheme(newCardColor: c),
      },
    ];

    return Scaffold(
      backgroundColor: themeProvider.bgColor, // Live preview of background
      appBar: AppBar(
        title: const Text(
          "Theme Editor",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: themeProvider.accentColor, // Live preview of accent
        actions: [
          // --- RESET BUTTON ---
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.white),
            tooltip: "Reset to Default",
            onPressed: () {
              // Show confirmation dialog before resetting
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Reset Theme?"),
                  content: const Text(
                    "This will revert all colors to their default factory settings.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        themeProvider.resetTheme();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        "Reset",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: themeItems.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = themeItems[index];
          final String label = item['label'];
          final Color color = item['color'];
          final Function(Color) onUpdate = item['onUpdate'];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            // Color Circle Preview
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ],
              ),
            ),
            title: Text(
              label,
              style: TextStyle(
                color: themeProvider.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '#${color.value.toRadixString(16).toUpperCase().substring(2)}',
              style: TextStyle(color: themeProvider.secondaryText),
            ),
            trailing: Icon(Icons.edit, color: themeProvider.accentColor),
            onTap: () => _pickColor(context, label, color, onUpdate),
          );
        },
      ),
    );
  }
}
