import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/features/invites/presentation/controllers/scanner_capture.dart';

void main() {
  test('raw capture trims edges without inventing an invitation format', () {
    expect(
      ScannerCapture.normalize('  STUDYMATES_CAMERA_SPIKE_ONLY  '),
      'STUDYMATES_CAMERA_SPIKE_ONLY',
    );
    expect(
      ScannerCapture.normalize('https://example.com/opaque'),
      'https://example.com/opaque',
    );
    for (final value in [
      null,
      '',
      '  ',
      'bad\u0000code',
      'two\nlines',
      'x' * 2049,
    ]) {
      expect(ScannerCapture.normalize(value), isNull);
    }
  });

  test(
    'repeated detections and manual submission race return once after stop',
    () async {
      final capture = ScannerCapture();
      final stopped = Completer<void>();
      final results = <String>[];
      expect(capture.accept(' QR '), isTrue);
      final delivery = capture.deliver(
        stop: () => stopped.future,
        canDeliver: () => true,
        onResult: results.add,
      );
      expect(capture.accept('QR'), isFalse);
      expect(capture.accept('manual'), isFalse);
      expect(results, isEmpty);
      stopped.complete();
      await delivery;
      await capture.deliver(
        stop: () async => fail('already delivered'),
        canDeliver: () => true,
        onResult: results.add,
      );
      expect(results, ['QR']);
    },
  );

  test('invalid capture does not consume the interaction', () {
    final capture = ScannerCapture();
    expect(capture.accept(' '), isFalse);
    expect(capture.accept('valid'), isTrue);
  });

  test(
    'failed stop never returns a result and supports shutdown retry',
    () async {
      final capture = ScannerCapture()..accept('test');
      final results = <String>[];
      await expectLater(
        capture.deliver(
          stop: () async => throw StateError('camera busy'),
          canDeliver: () => true,
          onResult: results.add,
        ),
        throwsStateError,
      );
      expect(results, isEmpty);
      expect(capture.accept('another'), isFalse);
      await capture.deliver(
        stop: () async {},
        canDeliver: () => true,
        onResult: results.add,
      );
      expect(results, ['test']);
    },
  );

  test(
    'covered or backgrounded capture defers callback until visible',
    () async {
      final capture = ScannerCapture()..accept('test');
      final results = <String>[];
      await capture.deliver(
        stop: () async {},
        canDeliver: () => false,
        onResult: results.add,
      );
      expect(results, isEmpty);
      await capture.deliver(
        stop: () async {},
        canDeliver: () => true,
        onResult: results.add,
      );
      expect(results, ['test']);
    },
  );

  test(
    'leaving while camera shutdown is pending suppresses callback',
    () async {
      final capture = ScannerCapture()..accept('test');
      final stopped = Completer<void>();
      final results = <String>[];
      final delivery = capture.deliver(
        stop: () => stopped.future,
        canDeliver: () => true,
        onResult: results.add,
      );
      capture.close();
      stopped.complete();
      await delivery;
      expect(results, isEmpty);
      expect(capture.accept('late'), isFalse);
      expect(ScannerCapture().accept('new interaction'), isTrue);
    },
  );
}
