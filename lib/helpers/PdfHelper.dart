import 'dart:io';
import 'dart:ui' as ui;
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path/path.dart'; // Needed for join()
import 'package:qr_flutter/qr_flutter.dart';
import 'package:selldroid/helpers/database_helper.dart';
import 'package:selldroid/helpers/file_helper.dart';
import 'package:selldroid/models/preference_model.dart';
import 'package:selldroid/models/sale.dart';
import 'package:selldroid/models/shop.dart';
import 'package:selldroid/models/sold_item.dart';
import 'package:selldroid/models/general_models.dart';
import 'package:intl/intl.dart';

class PdfBillHelper {
  static NumberFormat num_format = NumberFormat.decimalPattern("en_IN");

  static Future<Uint8List?> generateQrBytes(String text) async {
    try {
      // 1. Create the painter
      final painter = QrPainter(
        data: text,
        version: QrVersions.auto,
        gapless: false,
        color: const Color(0xFF000000), // QR Color (Black)
        emptyColor: const Color(0xFFFFFFFF), // Background Color (White)
      );

      // 2. Generate Image (Size 200x200)
      // You can increase '200' for higher resolution
      final ui.Image image = await painter.toImage(300);

      // 3. Convert to ByteData (PNG format)
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      // 4. Return Uint8List
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print("Error generating QR bytes: $e");
      return null;
    }
  }

  static Future<String> createBill({
    required ShopDetails shop,
    required Sale sale,
    required List<SoldItem> items,
    required String customerName,
    required String customerPhone,
    required String customerPlace,
    required String customerState,
    required PreferenceModel prefs,
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logoImage;
    if (shop.logo.isNotEmpty && File(shop.logo).existsSync()) {
      final imageBytes = File(shop.logo).readAsBytesSync();
      logoImage = pw.MemoryImage(imageBytes);
    }
    pw.MemoryImage? qrImage = pw.MemoryImage(
      (await generateQrBytes(
        "upi://pay?pa=${shop.upiId}&am=${sale.finalAmount}&tn=${sale.id}&cu=INR",
      ))!,
    );
    // Determine GST Type logic
    bool isInterState =
        shop.state.toLowerCase().trim() != customerState.toLowerCase().trim();
    final fontforRupee = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(5),
        build: (pw.Context context) {
          return _buildBillContent(
            shop,
            sale,
            items,
            logoImage,
            customerName,
            customerPhone,
            customerPlace,
            isInterState,
            prefs,
            qrImage,
            fontforRupee,
          );
        },
      ),
    );

    // Save Logic
    if (sale.isStockSales) {
      Directory sd = Directory(join(FileHelper.dir.path, "stock_sales_bills"));
      if (!sd.existsSync()) sd.createSync();
      File billPdf = File(join(sd.path, "bill_no_S${sale.id}.pdf"));
      billPdf.writeAsBytesSync(await doc.save());
      return billPdf.path;
    } else {
      Directory qd = Directory(join(FileHelper.dir.path, "quick_sales_bills"));
      if (!qd.existsSync()) qd.createSync();
      File billPdf = File(join(qd.path, "bill_no_Q${sale.id}.pdf"));
      billPdf.writeAsBytesSync(await doc.save());
      return billPdf.path;
    }
  }

  static Map<String, double> calculateInclusiveGst({
    required double inclusivePrice,
    required double gstRate,
  }) {
    // 1. Calculate Base Price (Reverse calculation)
    double basePrice = inclusivePrice / (1 + (gstRate / 100));

    // 2. Calculate GST Amount
    double gstAmount = inclusivePrice - basePrice;

    return {
      "base_price": basePrice,
      "gst_amount": gstAmount,
      "total_price": inclusivePrice,
    };
  }

  static Map<String, double> calculateExclusiveGst({
    required double basePrice,
    required double gstRate,
  }) {
    // 1. Calculate GST Amount
    double gstAmount = basePrice * (gstRate / 100);

    // 2. Calculate Total Price
    double totalPrice = basePrice + gstAmount;

    return {
      "base_price": basePrice,
      "gst_amount": gstAmount,
      "total_price": totalPrice,
    };
  }

  static double discountPercentage({
    required double amount,
    required double discountAmount,
  }) {
    if (amount <= 0) return 0;
    return (discountAmount / amount) * 100;
  }

  static pw.Widget _buildBillContent(
    ShopDetails shop,
    Sale sale,
    List<SoldItem> items,
    pw.MemoryImage? logo,
    String cName,
    String cPhone,
    String cPlace,
    bool isInterState,
    PreferenceModel prefs,
    pw.MemoryImage? qrImage,
    pw.Font fontforRupee,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('hh:mm:ss a');
    final DateTime billDate = DateTime.parse(sale.billedDate);

    const textStyle = pw.TextStyle(fontSize: 9);
    final boldStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );

    int tot_qty = 0;
    Map<int, double> gsts = {0: 0, 5: 0, 12: 0, 18: 0, 28: 0};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // --- 1. HEADER ---
        pw.Center(
          child: pw.Column(
            children: [
              if (logo != null)
                pw.Container(height: 50, width: 50, child: pw.Image(logo)),
              pw.SizedBox(height: 5),
              pw.Text(shop.name, style: headerStyle),
              pw.Text("${shop.address}, ${shop.city}", style: textStyle),
              pw.Text("${shop.state}", style: textStyle),
              pw.Text("Contact: ${shop.phoneNumber}", style: textStyle),
            ],
          ),
        ),

        _buildDashedLine(),

        // --- 2. DETAILS ---
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "Bill No : ${sale.isStockSales ? "S" : "Q"}${sale.id}",
                        style: textStyle,
                      ),
                      pw.Text(
                        "Payment Mode : ${sale.paymentMode}",
                        style: textStyle,
                      ),
                    ],
                  ),
                ),
                pw.Padding(padding: pw.EdgeInsets.all(1)),
                pw.Container(
                  width: 190,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "Date : ${dateFormat.format(billDate)}",
                        style: textStyle,
                      ),
                      pw.Text(
                        "Time : ${timeFormat.format(billDate)}",
                        style: textStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (cPhone != "") _buildDashedLine(),
        if (cPhone != "")
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Customer: $cName", style: textStyle),
              pw.Padding(padding: pw.EdgeInsets.all(1)),
              pw.Text("Phone No: $cPhone", style: textStyle),
              pw.Padding(padding: pw.EdgeInsets.all(1)),
              pw.Text("State: $cPlace", style: textStyle),
            ],
          ),

        _buildDashedLine(),
        // --- 3. HEADERS ---
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text("Product Name", style: boldStyle),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                "Rate",
                style: boldStyle,
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                "Qty",
                style: boldStyle,
                textAlign: pw.TextAlign.right,
              ),
            ),

            pw.Expanded(
              flex: 2,
              child: pw.Text(
                "Amount",
                style: boldStyle,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),

        _buildDashedLine(),

        // --- 4. ITEMS ---
        ...items.map((item) {
          // Fix 1: Calculate rate using simple division (amount / qty)
          double rate = 0;
          if (item.qty > 0) rate = item.amount / item.qty;
          if (prefs.includeGst && prefs.isGstInclusive) {
            rate = calculateInclusiveGst(
              inclusivePrice: rate,
              gstRate: item.igst,
            )["base_price"]!.toDouble();
          }
          tot_qty += item.qty;
          // Fix 2: Logic for displaying Tax Percentage
          // Since we don't have 'gstRate', we assume stored values are rates or deduce them.
          // But your prompt said "Don't change logic", just fix error.
          // The error is accessing item.gstRate.
          // I will display the stored tax values directly or construct a string.
          if (prefs.includeGst && prefs.isGstInclusive) {
            gsts[item.igst.toInt()] =
                gsts[item.igst.toInt()]! +
                calculateInclusiveGst(
                  inclusivePrice:
                      item.amount -
                      ((discountPercentage(
                                amount: sale.totalAmount.toDouble(),
                                discountAmount: sale.discountAmount.toDouble(),
                              ) /
                              100) *
                          item.amount),
                  gstRate: item.igst,
                )["gst_amount"]!.toDouble();
          } else {
            gsts[item.igst.toInt()] =
                gsts[item.igst.toInt()]! +
                calculateExclusiveGst(
                  basePrice:
                      item.amount -
                      ((discountPercentage(
                                amount: sale.totalAmount.toDouble(),
                                discountAmount: sale.discountAmount.toDouble(),
                              ) /
                              100) *
                          item.amount),
                  gstRate: item.igst,
                )["gst_amount"]!.toDouble();
          }
          String taxDisplay = "";
          if (isInterState) {
            // If model stores IGST as percentage, display it.
            // If model stores IGST as Amount, we can't display % easily without calculation.
            // Assuming your model stores RATES based on previous context:

            taxDisplay =
                "${(prefs.isGstInclusive ? calculateInclusiveGst(inclusivePrice: item.amount, gstRate: item.igst)["gst_amount"] : calculateExclusiveGst(basePrice: item.amount, gstRate: item.igst)["gst_amount"])!.toStringAsFixed(1)}";
          } else {
            // Split display
            taxDisplay =
                "${(prefs.isGstInclusive ? calculateInclusiveGst(inclusivePrice: item.amount, gstRate: item.sgst)["gst_amount"] : calculateExclusiveGst(basePrice: item.amount, gstRate: item.sgst)["gst_amount"])!.toStringAsFixed(1)}+${(prefs.isGstInclusive ? calculateInclusiveGst(inclusivePrice: item.amount, gstRate: item.cgst)["gst_amount"] : calculateExclusiveGst(basePrice: item.amount, gstRate: item.cgst)["gst_amount"])!.toStringAsFixed(1)}";
          }

          return pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 1),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(item.itemName, style: textStyle),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    rate.toStringAsFixed(1),
                    style: textStyle,
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    item.qty.toString(),
                    style: textStyle,
                    textAlign: pw.TextAlign.right,
                  ),
                ),

                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    (rate * item.qty).toStringAsFixed(1),
                    style: textStyle,
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        _buildDashedLine(),
        pw.Container(
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Total Items : ${items.length}", style: textStyle),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "Total Qty : ${tot_qty.toString()}",
                    style: textStyle,
                  ),
                ],
              ),
              pw.Text(
                num_format.format(sale.totalAmount + sale.discountAmount),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        // --- 5. TOTALS ---
        if (prefs.includeGst)
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                ...[0, 5, 12, 18, 28].map((key) {
                  if (gsts[key] == 0) {
                    return pw.Container();
                  }
                  if (isInterState)
                    return _buildSummaryRow(
                      "IGST ${key}%",
                      gsts[key]!.toStringAsFixed(1),
                    );

                  return pw.Column(
                    children: [
                      _buildSummaryRow(
                        "SGST ${key / 2}%",
                        (gsts[key]! / 2).toStringAsFixed(1),
                      ),
                      _buildSummaryRow(
                        "CGST ${key / 2}%",
                        (gsts[key]! / 2).toStringAsFixed(1),
                      ),
                      pw.SizedBox(height: 3),
                    ],
                  );
                }),
              ],
            ),
          ),
        if (sale.discountAmount > 0)
          _buildSummaryRow(
            "Discount Amount",
            "${sale.discountAmount.toStringAsFixed(1)}",
          ),
        _buildDashedLine(),
        pw.SizedBox(height: 3),
        if (shop.upiId != "")
          pw.Center(
            child: pw.Container(
              height: 50,
              width: 50,
              child: pw.Image(qrImage!),
            ),
          ),
        pw.SizedBox(height: 3),
        // --- 6. GRAND TOTAL ---
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              "TOTAL  :  ",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                font: fontforRupee,
              ),
            ),
            pw.Text(
              "₹ ${num_format.format(sale.finalAmount)}",
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                font: fontforRupee,
              ),
            ),
          ],
        ),

        _buildDashedLine(),

        // --- 7. FOOTER ---
        pw.SizedBox(height: 5),
        pw.Center(
          child: pw.Text("*** Thank You , Visit Again ***", style: boldStyle),
        ),
        pw.SizedBox(height: 5),
        pw.Center(
          child: pw.Text(
            "Technology Partner BUYP - 1800 890 0803",
            style: boldStyle,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDashedLine() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Text(
        "-----------------------------------------------------------------------",
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 10),
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      width: 220,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(width: 20),
          pw.Text(value, style: pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}
