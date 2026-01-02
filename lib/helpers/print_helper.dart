import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:image/image.dart';

class PrintHelper {
  static Future<void> askPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse, // Sometimes still required for scanning
    ].request();

    // Check individual statuses if needed
    print(statuses);
  }

  static Future<List<Uint8List>> convertPdfToImages(File pdfFile) async {
    final List<Uint8List> images = [];
    final Uint8List documentBytes = await pdfFile.readAsBytes();

    // The raster function processes the PDF pages into an image stream
    await for (var page in Printing.raster(
      await documentBytes,
      pages: [0],
      dpi: 175,
    )) {
      final imageBytes = await page
          .toPng(); // or page.toImage() for a Flutter Image object
      images.add(imageBytes);
    }
    return images;
  }

  static void showErrorSnackBar(String txt, BuildContext context) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(txt, style: TextStyle(color: Colors.white)),
        action: SnackBarAction(label: "OK", onPressed: () {}),
        backgroundColor: Colors.red[800],
      ),
    );
  }

  static void showSuccessSnackBar(String txt, BuildContext context) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(txt, style: TextStyle(color: Colors.white)),
        action: SnackBarAction(label: "OK", onPressed: () {}),
        backgroundColor: Colors.green[800],
      ),
    );
  }

  static void showInfoSnackBar(String txt, BuildContext context) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(txt, style: TextStyle(color: Colors.white)),
        action: SnackBarAction(label: "OK", onPressed: () {}),
        backgroundColor: Colors.blue[800],
      ),
    );
  }

  static Future<List<BluetoothInfo>> pairedDevices(BuildContext context) async {
    if (await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      if (await PrintBluetoothThermal.bluetoothEnabled) {
        return PrintBluetoothThermal.pairedBluetooths;
      } else {
        showErrorSnackBar("Turn ON Bluetooth", context);
      }
    } else {
      askPermission();
      showInfoSnackBar("Try again, After granting permission", context);
    }
    List<BluetoothInfo> l = [];
    return l;
  }

  static Future<void> print80mmBill(
    File pdf,
    String printer_name,
    BuildContext context,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    if (await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      if (await PrintBluetoothThermal.bluetoothEnabled) {
        String? printer_mac;
        showInfoSnackBar("Searching Printer...", context);
        //getting mac address of the printer
        (await PrintBluetoothThermal.pairedBluetooths).forEach((e) {
          if (e.name == printer_name) {
            printer_mac = e.macAdress;
          }
          print(e.name);
        });
        if (printer_mac == null) {
          showErrorSnackBar("Printer is not paired", context);
          return;
        }
        if (await PrintBluetoothThermal.connectionStatus) {
          print("connected printing..");
          showInfoSnackBar("Printing...", context);
          // PrintBluetoothThermal.writeBytes(
          //File(Filehelper.dir.path + "/bill_no_19.pdf").readAsBytesSync(),
          // );

          Uint8List imgg = (await convertPdfToImages(pdf))[0];

          PrintBluetoothThermal.writeBytes(generator.image(decodeImage(imgg)!));
          PrintBluetoothThermal.writeBytes(generator.cut());
          showSuccessSnackBar("Printed", context);
          // Add some line feeds (important)

          /*   PrintBluetoothThermal.writeString(
            printText: PrintTextSize(size: 2, text: "hello world\n"),
          ).then((val) {

            print(val);
          }); */
        } else {
          PrintBluetoothThermal.connect(macPrinterAddress: printer_mac!).then((
            val,
          ) async {
            if (val) {
              Uint8List imgg = (await convertPdfToImages(pdf))[0];
              showInfoSnackBar("Printing...", context);
              PrintBluetoothThermal.writeBytes(
                generator.image(decodeImage(imgg)!),
              );
              PrintBluetoothThermal.writeBytes(generator.cut());
              showSuccessSnackBar("Printed", context);
            } else {
              showErrorSnackBar("Printer is Offline", context);
            }
          });
        }
      } else {
        showErrorSnackBar("Turn ON Bluetooth", context);
      }
    } else {
      showErrorSnackBar("Allow Permission for Bluetooth", context);
      askPermission();
    }
  }
}
