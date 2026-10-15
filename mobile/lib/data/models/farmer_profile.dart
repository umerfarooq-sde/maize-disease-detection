import '../../core/exceptions/app_exception.dart';

class FarmerProfile {
  const FarmerProfile({
    required this.displayName,
    required this.region,
    required this.countryCode,
    required this.fieldAreaHectares,
    required this.avatarUrl,
    required this.revision,
    required this.updatedAt,
  });
  final String displayName;
  final String? region, countryCode, fieldAreaHectares;
  final Uri? avatarUrl;
  final String revision;
  final DateTime updatedAt;
  static FarmerProfile? fromResponse(Object? value) {
    if (value is! Map<String, dynamic> || !value.containsKey('profile')) {
      throw _invalid();
    }
    final raw = value['profile'];
    if (raw == null) return null;
    if (raw is! Map<String, dynamic> || raw.length != 7) throw _invalid();
    final name = raw['displayName'],
        region = raw['region'],
        country = raw['countryCode'],
        area = raw['fieldAreaHectares'];
    final revision = raw['revision'], updated = raw['updatedAt'];
    final photo = raw['avatarUrl'];
    final uri = photo is String ? Uri.tryParse(photo) : null;
    if (name is! String ||
        ProfileDraft.nameError(name) != null ||
        (region != null &&
            (region is! String || ProfileDraft.regionError(region) != null)) ||
        (country != null &&
            (country is! String || !RegExp(r'^[A-Z]{2}$').hasMatch(country))) ||
        (area != null &&
            (area is! String || ProfileDraft.areaError(area) != null)) ||
        revision is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(revision) ||
        updated is! String ||
        DateTime.tryParse(updated) == null ||
        (photo != null &&
            (uri == null ||
                !RegExp(
                  r'^profile/avatar\?v=[a-f0-9]{64}$',
                ).hasMatch(photo)))) {
      throw _invalid();
    }
    return FarmerProfile(
      displayName: name,
      region: region as String?,
      countryCode: country as String?,
      fieldAreaHectares: area as String?,
      avatarUrl: uri,
      revision: revision,
      updatedAt: DateTime.parse(updated),
    );
  }
}

class ProfileDraft {
  const ProfileDraft(
    this.displayName,
    this.region,
    this.countryCode,
    this.fieldAreaHectares,
  );
  final String displayName, region, countryCode, fieldAreaHectares;
  static bool _readable(String value, int maximum) =>
      value.runes.length <= maximum &&
      !value.runes.any((code) => code < 32 || code == 127);
  static String? nameError(String? value) {
    final text = (value ?? '').trim();
    return text.isNotEmpty && _readable(text, 120)
        ? null
        : 'Enter a display name with 1–120 readable characters.';
  }

  static String? regionError(String? value) =>
      _readable((value ?? '').trim(), 120)
      ? null
      : 'Use up to 120 readable characters.';
  static String? countryError(String? value) =>
      (value ?? '').trim().isEmpty ||
          RegExp(r'^[A-Za-z]{2}$').hasMatch(value!.trim())
      ? null
      : 'Use a two-letter country code, or leave blank.';
  static String? areaError(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    return RegExp(r'^(?:0|[1-9][0-9]{0,7})(?:\.[0-9]{1,4})?$').hasMatch(text) &&
            (double.tryParse(text) ?? 0) > 0
        ? null
        : 'Enter positive hectares, up to 8 whole digits and 4 decimal places.';
  }

  Map<String, Object?> toJson(String? revision) {
    if (nameError(displayName) != null ||
        regionError(region) != null ||
        countryError(countryCode) != null ||
        areaError(fieldAreaHectares) != null) {
      throw const AppException(AppErrorKind.validation);
    }
    String? optional(String text) => text.trim().isEmpty ? null : text.trim();
    return {
      'expectedRevision': revision,
      'displayName': displayName.trim(),
      'region': optional(region),
      'countryCode': optional(countryCode)?.toUpperCase(),
      'fieldAreaHectares': optional(fieldAreaHectares),
    };
  }
}

AppException _invalid() => const AppException(AppErrorKind.invalidResponse);
