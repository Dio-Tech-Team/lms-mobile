import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

class PdfViewOnlyPage extends StatefulWidget {
  final Uint8List bytes;
  final String title;

  const PdfViewOnlyPage({
    super.key,
    required this.bytes,
    this.title = 'Leave Form',
  });

  @override
  State<PdfViewOnlyPage> createState() => _PdfViewOnlyPageState();
}

class _PdfViewOnlyPageState extends State<PdfViewOnlyPage> {
  // Created once, not on every build — a fresh closure/Future each rebuild
  // makes PdfPreview think the document changed and re-rasterize it.
  late final Future<Uint8List> _doc = Future.value(widget.bytes);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF13224A),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => _doc,
        dynamicLayout: false,
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        useActions: false,
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Color(0xFF13224A)),
        ),
        scrollViewDecoration: BoxDecoration(color: Colors.grey.shade200),
      ),
    );
  }
}
