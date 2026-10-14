import 'dart:convert';
import '../../core/exceptions/app_exception.dart';

const assistantQuestionMinimumCharacters = 3;
const assistantQuestionMaximumCharacters = 1000;
const assistantQuestionMaximumBytes = 1800;

/// Shared client input validation; retrieval scope and evidence admission remain
/// server-authoritative. Unicode bounds match the Node question contract.
String normalizeAssistantQuestion(String question) {
  final normalized = question.replaceAll(
    RegExp(r'^[\s\u0085]+|[\s\u0085]+$', unicode: true),
    '',
  );
  final characters = normalized.runes.toList();
  final bytes = utf8.encode(normalized);
  if (characters.length < assistantQuestionMinimumCharacters ||
      characters.length > assistantQuestionMaximumCharacters ||
      bytes.length > assistantQuestionMaximumBytes ||
      utf8.decode(bytes) != normalized ||
      characters.any((char) => char < 32 && char != 10 && char != 9)) {
    throw const AppException(AppErrorKind.validation);
  }
  return normalized;
}
