import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._api, this._tokens);
  final ApiClient _api;
  final TokenStorage _tokens;

  Future<String?> requestOtp(String phone) async {
    final res = await _api.post('/auth/request-otp', body: {'phone': phone});
    return res.data is Map ? res.data['devCode'] as String? : null;
  }

  Future<AppUser> verifyOtp(String phone, String code) async {
    final res = await _api.post(
      '/auth/verify-otp',
      body: {'phone': phone, 'code': code},
    );
    final data = res.data as Map<String, dynamic>;
    await _tokens.save(
      data['accessToken'] as String,
      data['refreshToken'] as String,
    );
    return AppUser.fromJson((data['user'] as Map).cast<String, dynamic>());
  }

  Future<AppUser> me() async {
    final res = await _api.get('/auth/me');
    return AppUser.fromJson(
      ((res.data as Map)['user'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> logout() async {
    final refresh = _tokens.refreshToken;
    if (refresh != null) {
      try {
        await _api.post(
          '/auth/logout',
          body: {'refreshToken': refresh},
          retry: false,
        );
      } catch (_) {
        //Best-effort; the local session is cleared regardless.
      }
    }
    await _tokens.clear();
  }
}
