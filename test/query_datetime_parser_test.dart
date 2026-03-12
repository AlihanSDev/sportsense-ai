import 'package:flutter_test/flutter_test.dart';
import 'package:sportsense/services/query_datetime_parser.dart';

void main() {
  group('QueryDateTimeParser', () {
    test('parses relative russian date and explicit time', () {
      final now = DateTime(2026, 3, 12, 10, 30);
      final result = QueryDateTimeParser.parse(
        'Покажи рейтинг завтра в 18:45',
        now: now,
      );

      expect(result.hasDate, isTrue);
      expect(result.hasTime, isTrue);
      expect(result.parsedDateTime, DateTime(2026, 3, 13, 18, 45));
    });

    test('parses weekday and part of day', () {
      final now = DateTime(2026, 3, 12, 10, 30); // Thursday
      final result = QueryDateTimeParser.parse(
        'show standings next monday evening',
        now: now,
      );

      expect(result.hasDate, isTrue);
      expect(result.hasTime, isTrue);
      expect(result.parsedDateTime, DateTime(2026, 3, 23, 19, 00));
    });

    test('parses explicit calendar date without year', () {
      final now = DateTime(2026, 3, 12, 10, 30);
      final result = QueryDateTimeParser.parse('Матч 14.03 в 09:15', now: now);

      expect(result.parsedDateTime, DateTime(2026, 3, 14, 9, 15));
    });
  });
}
