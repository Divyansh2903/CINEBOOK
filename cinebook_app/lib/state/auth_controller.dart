import 'package:flutter/foundation.dart';

import '../core/token_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

//Owns the session: restores it on launch, exposes the current user, and
//flips the app between the auth flow and the main shell.
class AuthController extends ChangeNotifier {
  AuthController(this._auth, this._tokens);
  final AuthService _auth;
  final TokenStorage _tokens;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;

  Future<void> bootstrap() async {
    await _tokens.load();
    if (!_tokens.hasSession) {
      _set(AuthStatus.unauthenticated);
      return;
    }
    try {
      user = await _auth.me();
      _set(AuthStatus.authenticated);
    } catch (_) {
      await _tokens.clear();
      _set(AuthStatus.unauthenticated);
    }
  }

  void onLoggedIn(AppUser u) {
    user = u;
    _set(AuthStatus.authenticated);
  }

  Future<void> refreshProfile() async {
    try {
      user = await _auth.me();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _auth.logout();
    user = null;
    _set(AuthStatus.unauthenticated);
  }

  //Triggered by the API client when a refresh token is rejected.
  void onSessionExpired() {
    if (status == AuthStatus.unauthenticated) return;
    user = null;
    _set(AuthStatus.unauthenticated);
  }

  void _set(AuthStatus s) {
    status = s;
    notifyListeners();
  }
}
