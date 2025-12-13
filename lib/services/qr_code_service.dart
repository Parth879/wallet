import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/customer.dart';
import 'toast_service.dart';

class QRCodeService {
  static Future<void> generateAndDownloadQRCode(
      BuildContext context, Customer customer) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: customer.qrCode ?? customer.id,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        throw Exception('QR Code generation failed');
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        gapless: true,
      );

      final pdf = pw.Document();
      final picData = await painter.toImageData(300);
      final pngBytes = picData!.buffer.asUint8List();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Customer QR Code',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Image(
                      pw.MemoryImage(pngBytes),
                      width: 250,
                      height: 250,
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    customer.name,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Phone: ${customer.phone}',
                      style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'ID: ${customer.qrCode ?? customer.id}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Save into application documents directory (no external storage permission required)
      final output = await getApplicationDocumentsDirectory();
      final file = File(
          '${output.path}/customer_qr_${customer.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ToastService.show(context, 'QR Code saved successfully');
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Customer QR Code - ${customer.name}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastService.show(context, 'Error: $e', isError: true);
      }
    }
  }

  static void showQRCode(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Customer QR Code',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: QrImageView(
                  data: customer.qrCode ?? customer.id,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(customer.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(customer.phone,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        generateAndDownloadQRCode(context, customer);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}