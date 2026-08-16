import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

class PdfViewOnlyPage extends StatelessWidget {
  final Uint8List bytes;
  final String title;

  const PdfViewOnlyPage({
    super.key,
    required this.bytes,
    this.title = 'Leave Form',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF13224A),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) async => bytes,
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        useActions: false,
        scrollViewDecoration: BoxDecoration(color: Colors.grey.shade200),
      ),
    );
  }
}