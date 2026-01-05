import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:selldroid/helpers/file_helper.dart';
import 'package:selldroid/splash_screen.dart';
import 'package:selldroid/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for async calls in main
  FileHelper.createFolderInMedia();

  runApp(
    MultiProvider(
      providers: [
        // Initialize ThemeProvider and load saved colors immediately
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Listen to the ThemeProvider
    // Using context.watch ensures the app rebuilds when colors change
    final theme = context.watch<ThemeProvider>();

    // Set Status Bar color dynamically based on the current background color
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness
            .dark, // Adjust based on theme.bgColor brightness if needed
      ),
    );

    return MaterialApp(
      title: 'SellDroid',
      debugShowCheckedModeBanner: false,

      // --- 2. GLOBAL THEME CONFIGURATION (Dynamic) ---
      theme: ThemeData(
        useMaterial3: true,

        // Define the Color Scheme using Provider colors
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.accentColor, // Was kPrimaryColor
          primary: theme.accentColor,
          surface: theme.bgColor, // Was kBackgroundColor
          onSurface: theme.primaryText, // Was kPrimaryText
        ),

        // Scaffold (Page) Background
        scaffoldBackgroundColor: theme.bgColor,

        // AppBar Theme
        appBarTheme: AppBarTheme(
          backgroundColor: theme.bgColor,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: theme.primaryText),
          titleTextStyle: TextStyle(
            color: theme.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.accentColor,
            foregroundColor: Colors.white, // Keep text white for contrast
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),

        // Input Field (TextField) Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: theme.cardColor, // Was kCardColor
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintStyle: TextStyle(color: theme.secondaryText, fontSize: 14),

          // Default Border
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.accentColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
        ),

        // Floating Action Button
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: theme.accentColor,
          foregroundColor: Colors.white,
        ),

        // Divider Theme
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade300, // Or derive from secondaryText
          thickness: 1,
        ),

        // Card Theme
        cardTheme: CardThemeData(
          color: theme.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}
