/// Matches the current Zod registration contract. Passwords are never trimmed.
abstract final class RegistrationCredentials {
  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String? emailError(String? value) {
    final email = normalizeEmail(value ?? '');
    return email.length <= 254 &&
            RegExp(
              r"^(?:[A-Za-z0-9_'+\-]+\.)*[A-Za-z0-9_'+\-]*[A-Za-z0-9_+-]@(?:[A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$",
            ).hasMatch(email)
        ? null
        : 'Enter a valid email address (up to 254 characters).';
  }

  static String? passwordError(String? value) {
    final length = (value ?? '').runes.length;
    return length >= 15 && length <= 128
        ? null
        : 'Use 15–128 characters. Spaces are allowed.';
  }
}
