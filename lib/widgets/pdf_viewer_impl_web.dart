import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

Widget buildPdfViewer(String pdfUrl) {
  final viewType = 'pdf-${pdfUrl.hashCode.abs()}';
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => html.IFrameElement()
      ..src = pdfUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%',
  );
  return SizedBox(
    height: 500,
    child: HtmlElementView(viewType: viewType),
  );
}
