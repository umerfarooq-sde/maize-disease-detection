enum AppErrorKind {
  configuration,
  network,
  timeout,
  validation,
  authentication,
  authorization,
  notFound,
  conflict,
  rateLimited,
  server,
  invalidResponse,
}

class AppException implements Exception {
  const AppException(this.kind, {this.statusCode, this.requestId});
  final AppErrorKind kind;
  final int? statusCode;
  final String? requestId;

  String get message => switch (kind) {
    AppErrorKind.configuration =>
      'The service connection is not available yet.',
    AppErrorKind.network =>
      'We could not connect. Check your internet and try again.',
    AppErrorKind.timeout => 'The connection took too long. Please try again.',
    AppErrorKind.validation => 'Please check your details and try again.',
    AppErrorKind.authentication => 'Please sign in to continue.',
    AppErrorKind.authorization => 'You do not have access to this area.',
    AppErrorKind.notFound => 'We could not find what you requested.',
    AppErrorKind.conflict => 'This information already exists.',
    AppErrorKind.rateLimited =>
      'Too many attempts. Please wait before trying again.',
    AppErrorKind.server =>
      'The service is temporarily unavailable. Please try again.',
    AppErrorKind.invalidResponse =>
      'We could not read the response. Please try again.',
  };

  @override
  String toString() => 'AppException(${kind.name})';
}
