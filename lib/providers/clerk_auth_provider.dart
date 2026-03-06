import 'package:clerk_flutter/clerk_flutter.dart' as clerk;

/// Singleton that holds a reference to [ClerkAuthState] so that
/// [ApiClient] (which has no BuildContext) can retrieve a fresh JWT.
class ClerkAuthProvider {
  ClerkAuthProvider._();

  static final ClerkAuthProvider instance = ClerkAuthProvider._();

  clerk.ClerkAuthState? _authState;

  /// Called once from the root widget tree after [ClerkAuth] is in scope.
  void setAuthState(clerk.ClerkAuthState authState) {
    _authState = authState;
  }

  /// Returns the current Clerk session JWT, or null if not signed in.
  Future<String?> getToken() async {
    try {
      final state = _authState;
      if (state == null) return null;
      final token = await state.sessionToken();
      return token.jwt;
    } catch (_) {
      return null;
    }
  }
}
