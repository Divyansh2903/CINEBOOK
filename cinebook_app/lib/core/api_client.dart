import 'package:dio/dio.dart';

import 'config.dart';
import 'token_storage.dart';

//A friendly, typed wrapper over backend error envelopes.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final dynamic details;

  @override
  String toString() => message;
}

//Called when the refresh token is rejected — the session is unrecoverable.
typedef SessionExpiredCallback = void Function();

class ApiClient {
  ApiClient(this.tokens) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        contentType: 'application/json',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachToken, onError: _normalizeError),
    );
  }

  final TokenStorage tokens;
  SessionExpiredCallback? onSessionExpired;
  late final Dio dio;

  void _attachToken(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokens.accessToken;
    if (token != null && options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  //Dio only enters onError for transport failures; HTTP error codes are
  //surfaced by the callers below via _wrap.
  void _normalizeError(DioException e, ErrorInterceptorHandler handler) {
    handler.next(e);
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool retry = true,
  }) => _send(() => dio.get(path, queryParameters: _clean(query)), retry);

  Future<Response<dynamic>> post(
    String path, {
    Object? body,
    bool retry = true,
  }) => _send(() => dio.post(path, data: body), retry);

  Future<Response<dynamic>> delete(String path, {Object? body}) =>
      _send(() => dio.delete(path, data: body), true);

  //Runs a request, transparently refreshing once on a 401.
  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() run,
    bool retry,
  ) async {
    late Response<dynamic> res;
    try {
      res = await run();
    } on DioException catch (e) {
      throw ApiException(
        'Network error — is the server running?',
        statusCode: e.response?.statusCode,
      );
    }
    if (res.statusCode == 401 && retry && tokens.refreshToken != null) {
      final refreshed = await _refresh();
      if (refreshed) {
        res = await run();
      }
    }
    return _wrap(res);
  }

  Response<dynamic> _wrap(Response<dynamic> res) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return res;
    final data = res.data;
    final message = data is Map && data['message'] is String
        ? data['message'] as String
        : 'Request failed ($code)';
    throw ApiException(
      message,
      statusCode: code,
      details: data is Map ? data['details'] : null,
    );
  }

  bool _refreshing = false;
  Future<bool> _refresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final res = await dio.post(
        '/auth/refresh',
        data: {'refreshToken': tokens.refreshToken},
        options: Options(headers: {'Authorization': null}),
      );
      if (res.statusCode == 200 && res.data is Map) {
        await tokens.save(
          res.data['accessToken'] as String,
          res.data['refreshToken'] as String,
        );
        return true;
      }
      await tokens.clear();
      onSessionExpired?.call();
      return false;
    } catch (_) {
      await tokens.clear();
      onSessionExpired?.call();
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return Map.fromEntries(
      query.entries.where((e) => e.value != null && e.value != ''),
    );
  }
}
