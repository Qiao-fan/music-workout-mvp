import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pdf_viewer_impl_stub.dart'
    if (dart.library.html) 'pdf_viewer_impl_web.dart' as impl;

/// Platform-agnostic PDF viewer. Uses iframe on web, pdfx on mobile.
Widget buildPdfViewer(String pdfUrl) {
  return impl.buildPdfViewer(pdfUrl);
}
