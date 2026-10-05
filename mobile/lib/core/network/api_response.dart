class ApiResponse {
  const ApiResponse({
    required this.data,
    required this.statusCode,
    this.requestId,
  });
  final Object? data;
  final int statusCode;
  final String? requestId;
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}
