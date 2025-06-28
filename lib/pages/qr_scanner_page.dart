import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'home_page.dart'; // make sure this is correct path

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool _isScanned = false;

  Future<void> _handleScan(String code) async {
    if (_isScanned) return;

    setState(() {
      _isScanned = true;
    });

    try {
      await FirebaseFirestore.instance.collection('qr_logins').add({
        'code': code,
        'scannedAt': DateTime.now().toIso8601String(),
      });

      // Navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      setState(() {
        _isScanned = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving QR scan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: const Color(0xFF66A6FF),
      ),
      body: MobileScanner(
        controller: MobileScannerController(),
        onDetect: (barcodeCapture) {
          final List<Barcode> barcodes = barcodeCapture.barcodes;
          for (final barcode in barcodes) {
            final String? code = barcode.rawValue;
            if (code != null && !_isScanned) {
              _handleScan(code);
              break;
            }
          }
        },
      ),
    );
  }
}
