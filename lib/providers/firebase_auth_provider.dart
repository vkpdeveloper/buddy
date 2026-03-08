import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth so [ApiClient] (which has no BuildContext)
/// can retrieve a fresh Firebase ID token for each request.
class FirebaseAuthProvider {
  FirebaseAuthProvider._();

  static final FirebaseAuthProvider instance = FirebaseAuthProvider._();

  /// Returns the current Firebase ID token, or null if not signed in.
  Future<String?> getToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (_) {
      return null;
    }
  }
}
