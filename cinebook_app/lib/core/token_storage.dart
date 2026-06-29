import 'package:flutter_secure_storage/flutter_secure_storage.dart';

//Persists the JWT pair across launches so customers stay logged in.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'cb_access';
  static const _refreshKey = 'cb_refresh';

  String? accessToken;
  String? refreshToken;

  Future<void> load() async {
    accessToken = await _storage.read(key: _accessKey);
    refreshToken = await _storage.read(key: _refreshKey);
  }

  Future<void> save(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  bool get hasSession => refreshToken != null;
}
