import 'dart:html' as html;

/// Signs out and navigates to signup (full reload). Web only.
void reloadPage() {
  final base = html.window.location.origin;
  html.window.location.href = '$base/signup';
}
