import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../peer/local_family.dart';
import '../widgets/common.dart';

/// Point the camera at another phone's family QR code. Pops with the code it carries
/// (or nothing, if the person goes back).
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _found(BarcodeCapture capture) {
    if (_done) return;

    for (final barcode in capture.barcodes) {
      final invite = LocalFamilyInvite.parse(barcode.rawValue ?? '');
      if (invite != null) {
        _done = true;
        Navigator.of(context).pop(invite.code);
        return;
      }
    }

    if (!_wrong) setState(() => _wrong = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('app_offline_scan_title'), style: const TextStyle(fontSize: 18))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _found,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.t('app_offline_scan_denied'), textAlign: TextAlign.center),
              ),
            ),
          ),
          if (_wrong)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                child: Text(context.t('app_offline_scan_wrong'), style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
