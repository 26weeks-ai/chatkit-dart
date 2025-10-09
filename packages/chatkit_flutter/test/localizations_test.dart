import 'package:chatkit_flutter/src/localization/localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatKitLocalizations.format', () {
    test('replaces placeholders with provided values', () {
      final l10n = ChatKitLocalizations(locale: 'en', overrides: null);
      final formatted = l10n.format('rate_limit_retry_in', {'seconds': '42'});
      expect(formatted, equals('Retry in 42s.'));
    });

    test('uses override strings when supplied', () {
      final l10n = ChatKitLocalizations(
        locale: 'en',
        overrides: {
          'rate_limit_retry_in': 'Again in {seconds} seconds.',
        },
      );
      final formatted = l10n.format('rate_limit_retry_in', {'seconds': '5'});
      expect(formatted, equals('Again in 5 seconds.'));
    });
  });
}
