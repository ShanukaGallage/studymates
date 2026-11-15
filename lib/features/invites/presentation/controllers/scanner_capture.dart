/// Raw capture for the camera spike, not a production invitation parser.
class ScannerCapture {
  static const maxLength = 2048;
  String? _value;
  bool _delivered = false;
  bool _closed = false;

  bool get hasResult => _value != null;
  bool get delivered => _delivered;

  static String? normalize(String? raw) {
    if (raw == null || raw.length > maxLength) return null;
    final value = raw.trim();
    if (value.isEmpty || RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      return null;
    }
    return value;
  }

  /// Claims synchronously so camera/manual input cannot race during shutdown.
  bool accept(String? raw) {
    if (_closed || hasResult) return false;
    final value = normalize(raw);
    if (value == null) return false;
    _value = value;
    return true;
  }

  /// Caller serializes camera operations. Failed stops retain the claimed value
  /// for retry; they must never allow a second capture or an early callback.
  Future<void> deliver({
    required Future<void> Function() stop,
    required bool Function() canDeliver,
    required void Function(String) onResult,
  }) async {
    if (_closed || _delivered || !hasResult) return;
    await stop();
    if (_closed || _delivered || !canDeliver()) return;
    _delivered = true;
    onResult(_value!);
  }

  void close() => _closed = true;
}
