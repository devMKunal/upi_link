import 'upi_link.dart';

/// Thrown when a [UpiLink] is constructed with an invalid argument.
///
/// [field] names the offending constructor parameter (for example
/// `payeeAddress`), so callers can map the error back to a form field.
///
/// Parsing errors are reported as [FormatException] instead, matching
/// `Uri.parse` and `int.parse` from `dart:core`.
final class UpiLinkException implements Exception {
  /// Creates an exception for [field] with a human-readable [message].
  const UpiLinkException(this.field, this.message);

  /// The name of the constructor parameter that failed validation,
  /// for example `payeeAddress` or `amount`.
  final String field;

  /// Why the value was rejected.
  final String message;

  @override
  String toString() => 'UpiLinkException($field): $message';
}
