import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/features/invites/data/invitation_token.dart';

void main() {
  const token = 'ABCDEFGHJK23MNPQ';

  test('parses the canonical v1 QR invitation', () {
    expect(
      InvitationTokenParser.parseQr('studymates://invite/v1/$token'),
      token,
    );
  });

  test('normalizes manual entry and matches the QR token', () {
    const manual = 'abcd-efgh-jk23-mnpq';
    final qrToken = InvitationTokenParser.parseQr(
      'studymates://invite/v1/$token',
    );

    expect(InvitationTokenParser.parseManual(manual), token);
    expect(InvitationTokenParser.parseManual(' abcd efgh-jk23 mnpq '), token);
    expect(InvitationTokenParser.parseManual(manual), qrToken);
  });

  test('rejects QR tokens that are lowercase or malformed', () {
    for (final raw in [
      'studymates://invite/v1/abcdefghjk23mnpq',
      'studymates://invite/v1/ABCDEFGHJK23MNP',
      'studymates://invite/v1/ABCDEFGHJK23MNPQR',
      'studymates://invite/v1/ABCDEFGIJK23MNPQ',
      'studymates://invite/v1/ABCDEFGHJL23MNPQ',
      'studymates://invite/v1/ABCDEFGHJO23MNPQ',
      'studymates://invite/v1/ABCDEFGHJK01MNPQ',
    ]) {
      expect(InvitationTokenParser.parseQr(raw), isNull, reason: raw);
    }
  });

  test('rejects unsupported, decorated, extra-segment and arbitrary URLs', () {
    for (final raw in [
      'studymates://invite/v2/$token',
      'studymates://invite/v1/$token?source=room',
      'studymates://invite/v1/$token#join',
      'studymates://invite/v1/$token/extra',
      'https://example.com/$token',
      'https://studymates://invite/v1/$token',
      'studymates://invite/v1/%41BCDEFGHJK23MNPQ',
      'studymates://other/v1/$token',
      'studymates://invite/v1/$token\n',
    ]) {
      expect(InvitationTokenParser.parseQr(raw), isNull, reason: raw);
    }
  });

  test('manual normalization rejects whitespace and invalid characters', () {
    for (final raw in [
      'abcd\tefgh-jk23-mnpq',
      'abcd\nefgh-jk23-mnpq',
      'abcd\refgh-jk23-mnpq',
      'abcd\u00a0efgh-jk23-mnpq',
      'abcd\u2003efgh-jk23-mnpq',
      'abcd_efgh_jk23_mnpq',
      'abcd-efgh-ij23-mnpq',
      'abcd-efgh-ol23-mnpq',
      'abcd-efgh-0123-mnpq',
      'abc-efgh-jk23-mnpq',
      'abcd-efgh-jk23-mnpqr',
      'äbcd-efgh-jk23-mnpq',
      '',
    ]) {
      expect(InvitationTokenParser.parseManual(raw), isNull, reason: raw);
    }
  });

  test('manual input only removes ASCII spaces and hyphens', () {
    expect(
      InvitationTokenParser.parseManual(
        ' a-b c d - e f g h - j k 2 3 - m n p q ',
      ),
      token,
    );
  });
}
