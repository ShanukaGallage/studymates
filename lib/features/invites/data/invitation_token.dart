/// Parses the canonical StudyMates invitation QR URI and manual token format.
///
/// This parser only returns opaque token text. It never navigates to scanned
/// URLs or performs a lookup.
abstract final class InvitationTokenParser {
  static final RegExp _tokenPattern = RegExp(r'^[A-HJ-KM-NP-Z2-9]{16}$');

  /// Returns a token only for the exact canonical, uppercase v1 QR format.
  static String? parseQr(String? raw) {
    if (raw == null || raw.contains('?') || raw.contains('#')) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'studymates' ||
        uri.host != 'invite' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'v1') {
      return null;
    }

    final token = uri.pathSegments[1];
    if (!isOpaqueToken(token)) return null;

    // Reject alternate spellings, escaped characters, and noncanonical URI
    // forms even when Uri could parse them to the same components.
    return raw == 'studymates://invite/v1/$token' ? token : null;
  }

  /// Removes ASCII spaces and hyphens, uppercases ASCII letters, then validates.
  /// All other whitespace and punctuation are preserved and rejected.
  static String? parseManual(String? raw) {
    if (raw == null) return null;

    final normalized = StringBuffer();
    for (final codeUnit in raw.codeUnits) {
      if (codeUnit == 0x20 || codeUnit == 0x2D) continue;
      normalized.writeCharCode(
        codeUnit >= 0x61 && codeUnit <= 0x7A ? codeUnit - 0x20 : codeUnit,
      );
    }

    final token = normalized.toString();
    return isOpaqueToken(token) ? token : null;
  }

  static bool isOpaqueToken(String token) =>
      token.length == 16 && _tokenPattern.hasMatch(token);
}
