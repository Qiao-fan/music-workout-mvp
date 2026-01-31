import 'package:flutter/material.dart';
import 'package:internet_file/internet_file.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildPdfViewer(String pdfUrl) {
  return _PdfViewerNative(pdfUrl: pdfUrl);
}

class _PdfViewerNative extends StatefulWidget {
  final String pdfUrl;

  const _PdfViewerNative({required this.pdfUrl});

  @override
  State<_PdfViewerNative> createState() => _PdfViewerNativeState();
}

class _PdfViewerNativeState extends State<_PdfViewerNative> {
  PdfController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = PdfDocument.openData(InternetFile.get(widget.pdfUrl));
      if (!mounted) return;
      setState(() {
        _controller = PdfController(document: doc, initialPage: 1);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _fallback() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Open PDF to view',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse(widget.pdfUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _fallback();
    if (_controller == null) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 300),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 400, maxHeight: 600),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PdfView(
          controller: _controller!,
          builders: PdfViewBuilders<DefaultBuilderOptions>(
            documentLoaderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            pageLoaderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __) => _fallback(),
          ),
        ),
      ),
    );
  }
}
