import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../exceptions/app_exception.dart';
import '../storage/access_token_source.dart';
import 'api_response.dart';
import 'app_config.dart';

enum ApiMethod { get, post, put, patch, delete }

class ApiClient {
  ApiClient({
    required AppConfig config,
    http.Client? client,
    AccessTokenSource? tokenSource,
    this.timeout = AppConstants.requestTimeout,
  }) : _config = config,
       _client = client ?? http.Client(),
       _tokens = tokenSource {
    if (timeout <= Duration.zero) {
      throw ArgumentError('Timeout must be positive.');
    }
  }

  final AppConfig _config;
  final http.Client _client;
  final AccessTokenSource? _tokens;
  final Duration timeout;
  bool _closed = false;

  Future<ApiResponse> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = false,
    Set<int> acceptedStatuses = const {},
  }) => request(
    ApiMethod.get,
    path,
    query: query,
    authenticated: authenticated,
    acceptedStatuses: acceptedStatuses,
  );

  Future<ApiResponse> request(
    ApiMethod method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    bool authenticated = false,
    Set<int> acceptedStatuses = const {},
  }) async {
    if (_closed) throw const AppException(AppErrorKind.network);
    final base = _config.baseUrl;
    if (base == null) throw const AppException(AppErrorKind.configuration);
    if (!RegExp(r'^[a-zA-Z0-9_-]+(?:/[a-zA-Z0-9_-]+)*$').hasMatch(path)) {
      throw ArgumentError('Use a relative API resource path.');
    }
    final abort = Completer<void>();
    try {
      return await _send(
        method,
        base.resolve(path).replace(queryParameters: query),
        body,
        authenticated,
        acceptedStatuses,
        abort,
      ).timeout(
        timeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const AppException(AppErrorKind.timeout);
        },
      );
    } on AppException {
      rethrow;
    } on http.ClientException {
      throw const AppException(AppErrorKind.network);
    } on FormatException {
      throw const AppException(AppErrorKind.invalidResponse);
    } catch (_) {
      // Never retain raw transport failures, URLs, bodies or credentials.
      throw const AppException(AppErrorKind.network);
    }
  }

  Future<ApiResponse> _send(
    ApiMethod method,
    Uri uri,
    Map<String, Object?>? body,
    bool authenticated,
    Set<int> acceptedStatuses,
    Completer<void> abort,
  ) async {
    final request =
        http.AbortableRequest(
            method.name.toUpperCase(),
            uri,
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers['Accept'] = 'application/json';
    if (authenticated) {
      final token = await _tokens?.readAccessToken();
      if (token == null ||
          token.length > 4096 ||
          !RegExp(
            r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
          ).hasMatch(token)) {
        throw const AppException(AppErrorKind.authentication);
      }
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (abort.isCompleted) throw const AppException(AppErrorKind.timeout);
    if (method != ApiMethod.get) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.headers['X-Auth-Request'] = '1';
      try {
        request.body = jsonEncode(body ?? <String, Object?>{});
      } on JsonUnsupportedObjectError {
        throw const AppException(AppErrorKind.validation);
      }
    }
    final response = await _client.send(request);
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > AppConstants.maxResponseBytes) {
        if (!abort.isCompleted) abort.complete();
        throw const AppException(AppErrorKind.invalidResponse);
      }
      bytes.addAll(chunk);
    }
    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim();
    if (contentType != 'application/json') {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> || decoded['success'] is! bool) {
      throw const AppException(AppErrorKind.invalidResponse);
    }
    final requestId = _requestId(decoded['requestId']);
    if (decoded['success'] == false) {
      throw AppException(
        _errorKind(response.statusCode),
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    if (!decoded.containsKey('data') ||
        (response.statusCode >= 300 &&
            !acceptedStatuses.contains(response.statusCode))) {
      throw AppException(
        _errorKind(response.statusCode),
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    // A datasource may explicitly accept a report at a non-success HTTP status.
    return ApiResponse(
      data: decoded['data'],
      statusCode: response.statusCode,
      requestId: requestId,
    );
  }

  static String? _requestId(Object? value) =>
      value is String && RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(value)
      ? value
      : null;

  static AppErrorKind _errorKind(int status) => switch (status) {
    400 || 422 => AppErrorKind.validation,
    401 => AppErrorKind.authentication,
    403 => AppErrorKind.authorization,
    404 => AppErrorKind.notFound,
    409 => AppErrorKind.conflict,
    429 => AppErrorKind.rateLimited,
    >= 500 => AppErrorKind.server,
    _ => AppErrorKind.invalidResponse,
  };

  void close() {
    if (!_closed) {
      _closed = true;
      _client.close();
    }
  }
}
