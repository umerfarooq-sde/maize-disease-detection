import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/app_constants.dart';
import '../exceptions/app_exception.dart';
import '../storage/access_token_source.dart';
import 'api_response.dart';
import 'app_config.dart';
import 'upload_request.dart';

enum ApiMethod { get, post, put, patch, delete }

class ApiClient {
  ApiClient({
    required AppConfig config,
    http.Client? client,
    AccessTokenSource? tokenSource,
    this.timeout = AppConstants.requestTimeout,
    this.uploadTimeout = AppConstants.uploadTimeout,
  }) : _config = config,
       _client = client ?? http.Client(),
       _tokens = tokenSource {
    if (timeout <= Duration.zero || uploadTimeout <= Duration.zero) {
      throw ArgumentError('Timeout must be positive.');
    }
  }

  final AppConfig _config;
  final http.Client _client;
  final AccessTokenSource? _tokens;
  final Duration timeout;
  final Duration uploadTimeout;
  bool _closed = false;

  Future<ApiResponse> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String idempotencyKey,
    void Function(double)? onProgress,
  }) async {
    if (_closed) throw const AppException(AppErrorKind.network);
    final base = _config.baseUrl;
    if (base == null) throw const AppException(AppErrorKind.configuration);
    if (bytes.isEmpty ||
        bytes.length > AppConstants.maxImageBytes ||
        !const ['image/jpeg', 'image/png', 'image/webp'].contains(mimeType) ||
        !RegExp(r'^leaf\.(jpg|png|webp)$').hasMatch(filename) ||
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(idempotencyKey)) {
      throw const AppException(AppErrorKind.validation);
    }
    final abort = Completer<void>();
    try {
      final request =
          UploadRequest(
              'POST',
              base.resolve('scans'),
              abortTrigger: abort.future,
              onProgress: (value) {
                if (!abort.isCompleted) onProgress?.call(value);
              },
            )
            ..followRedirects = false
            ..headers.addAll({
              'Accept': 'application/json',
              'X-Auth-Request': '1',
              'Idempotency-Key': idempotencyKey,
            })
            ..files.add(
              http.MultipartFile.fromBytes(
                'image',
                bytes,
                filename: filename,
                contentType: MediaType.parse(mimeType),
              ),
            );
      Future<ApiResponse> send() async {
        // A supplied secure token source means authenticated mode. Missing/invalid
        // credentials fail closed; they never silently become an anonymous scan.
        if (_tokens != null) await _authenticate(request);
        if (abort.isCompleted) throw const AppException(AppErrorKind.timeout);
        return _readResponse(await _client.send(request), const {}, abort);
      }

      return await send().timeout(
        uploadTimeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const AppException(AppErrorKind.timeout);
        },
      );
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(AppErrorKind.invalidResponse);
    } catch (_) {
      throw const AppException(AppErrorKind.network);
    }
  }

  Future<void> _authenticate(http.BaseRequest request) async {
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
      await _authenticate(request);
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
    return _readResponse(response, acceptedStatuses, abort);
  }

  Future<ApiResponse> _readResponse(
    http.StreamedResponse response,
    Set<int> acceptedStatuses,
    Completer<void> abort,
  ) async {
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
      final error = decoded['error'];
      final code = error is Map<String, dynamic> ? error['code'] : null;
      throw AppException(
        switch (code) {
          'INVALID_IMAGE' => AppErrorKind.invalidImage,
          'UPLOAD_IN_PROGRESS' => AppErrorKind.uploadInProgress,
          _ => _errorKind(response.statusCode),
        },
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
    413 => AppErrorKind.imageTooLarge,
    415 => AppErrorKind.invalidImage,
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
