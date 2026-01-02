import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selldroid/helpers/file_helper.dart';

import 'package:selldroid/splash_screen.dart'; // Ensure this path is correct

void main() {
  FileHelper.createFolderInMedia();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // --- 1. Define Colors from your file ---
  static const Color kPrimaryColor = Color.fromARGB(255, 25, 133, 161); // Teal
  static const Color kBackgroundColor = Color.fromARGB(
    255,
    220,
    220,
    221,
  ); // Light Grey
  static const Color kPrimaryText = Color.fromARGB(
    255,
    70,
    73,
    76,
  ); // Dark Grey
  static const Color kSecondaryText = Color.fromARGB(255, 76, 92, 104); // Slate
  static const Color kBorderColor = Color.fromARGB(
    255,
    197,
    195,
    198,
  ); // Medium Grey

  // We use White for cards/inputs to ensure contrast against the grey background
  static const Color kCardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    // Set Status Bar to transparent so background color shows through
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'SellDroid',
      debugShowCheckedModeBanner: false,

      // --- 2. GLOBAL THEME CONFIGURATION ---
      theme: ThemeData(
        useMaterial3: true,

        // Define the Color Scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          primary: kPrimaryColor,
          surface: kBackgroundColor,
          onSurface: kPrimaryText,
        ),

        // Scaffold (Page) Background
        scaffoldBackgroundColor: kBackgroundColor,

        // AppBar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: kBackgroundColor,
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: kPrimaryText),
          titleTextStyle: TextStyle(
            color: kPrimaryText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
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
          fillColor: kCardColor, // White fill looks best on grey background
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintStyle: const TextStyle(color: kSecondaryText, fontSize: 14),

          // Default Border (using your Medium Grey)
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
            borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
        ),

        // Floating Action Button
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
        ),

        // Divider Theme
        dividerTheme: const DividerThemeData(color: kBorderColor, thickness: 1),
      ),

      home: const SplashScreen(), // Ensure you have this screen
    );
  }
}
