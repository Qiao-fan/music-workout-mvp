import 'platform_utils_stub.dart'
    if (dart.library.html) 'platform_utils_web.dart' as impl;

/// Reloads the app (web only). Use after logout to clear Firestore client state.
void reloadPage() => impl.reloadPage();
