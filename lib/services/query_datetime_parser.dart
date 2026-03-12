class ParsedDateTimeContext {
  final String originalText;
  final DateTime referenceNow;
  final DateTime? parsedDateTime;
  final DateTime? parsedDate;
  final String? parsedTime;
  final bool hasDate;
  final bool hasTime;

  const ParsedDateTimeContext({
    required this.originalText,
    required this.referenceNow,
    required this.parsedDateTime,
    required this.parsedDate,
    required this.parsedTime,
    required this.hasDate,
    required this.hasTime,
  });

  bool get hasAnyTemporalReference => hasDate || hasTime;

  String toPromptContext() {
    if (!hasAnyTemporalReference) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('Temporal context extracted from the user message:');
    buffer.writeln('reference_now: ${referenceNow.toIso8601String()}');

    if (hasDate) {
      buffer.writeln(
        'parsed_date: ${parsedDate!.toIso8601String().split('T').first}',
      );
    }
    if (hasTime && parsedTime != null) {
      buffer.writeln('parsed_time: $parsedTime');
    }
    if (parsedDateTime != null) {
      buffer.writeln('resolved_datetime: ${parsedDateTime!.toIso8601String()}');
    }

    buffer.writeln(
      'Use this normalized temporal context when the user refers to dates, weekdays, today, tomorrow, or a specific time.',
    );
    return buffer.toString().trim();
  }
}

class QueryDateTimeParser {
  static final RegExp _timeRegex = RegExp(
    r'\b(?:at\s*)?([01]?\d|2[0-3])[:.]([0-5]\d)\b',
    caseSensitive: false,
  );

  static final RegExp _dateRegex = RegExp(
    r'\b(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?\b',
  );

  static final RegExp _isoDateRegex = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

  static ParsedDateTimeContext parse(String text, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final normalized = text.toLowerCase();

    DateTime? parsedDate =
        _parseExplicitIsoDate(normalized, reference) ??
        _parseExplicitDate(normalized, reference) ??
        _parseRelativeDate(normalized, reference) ??
        _parseWeekday(normalized, reference);

    final parsedTime =
        _parseExplicitTime(normalized) ?? _parsePartOfDay(normalized);

    DateTime? parsedDateTime;
    if (parsedDate != null && parsedTime != null) {
      final parts = parsedTime.split(':');
      parsedDateTime = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } else if (parsedDate != null) {
      parsedDateTime = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
    } else if (parsedTime != null) {
      final parts = parsedTime.split(':');
      parsedDateTime = DateTime(
        reference.year,
        reference.month,
        reference.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    return ParsedDateTimeContext(
      originalText: text,
      referenceNow: reference,
      parsedDateTime: parsedDateTime,
      parsedDate: parsedDate,
      parsedTime: parsedTime,
      hasDate: parsedDate != null,
      hasTime: parsedTime != null,
    );
  }

  static DateTime? _parseExplicitIsoDate(String text, DateTime now) {
    final match = _isoDateRegex.firstMatch(text);
    if (match == null) {
      return null;
    }

    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static DateTime? _parseExplicitDate(String text, DateTime now) {
    final match = _dateRegex.firstMatch(text);
    if (match == null) {
      return null;
    }

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final rawYear = match.group(3);
    final year = rawYear == null
        ? now.year
        : rawYear.length == 2
        ? 2000 + int.parse(rawYear)
        : int.parse(rawYear);

    return DateTime(year, month, day);
  }

  static DateTime? _parseRelativeDate(String text, DateTime now) {
    const offsets = {
      'today': 0,
      'сегодня': 0,
      'tomorrow': 1,
      'завтра': 1,
      'day after tomorrow': 2,
      'послезавтра': 2,
      'yesterday': -1,
      'вчера': -1,
    };

    for (final entry in offsets.entries) {
      if (text.contains(entry.key)) {
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).add(Duration(days: entry.value));
      }
    }

    return null;
  }

  static DateTime? _parseWeekday(String text, DateTime now) {
    const weekdays = {
      'monday': DateTime.monday,
      'понедельник': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'вторник': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'среда': DateTime.wednesday,
      'среду': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'четверг': DateTime.thursday,
      'friday': DateTime.friday,
      'пятница': DateTime.friday,
      'пятницу': DateTime.friday,
      'saturday': DateTime.saturday,
      'суббота': DateTime.saturday,
      'субботу': DateTime.saturday,
      'sunday': DateTime.sunday,
      'воскресенье': DateTime.sunday,
    };

    final startOfToday = DateTime(now.year, now.month, now.day);
    final hasNext = text.contains('next ') || text.contains('следующ');
    final hasThis = text.contains('this ') || text.contains('эт');

    for (final entry in weekdays.entries) {
      if (!text.contains(entry.key)) {
        continue;
      }

      var daysAhead = (entry.value - now.weekday) % 7;
      if (daysAhead == 0 && !hasThis) {
        daysAhead = 7;
      }
      if (hasNext) {
        daysAhead += daysAhead == 0 ? 7 : 7;
      }

      return startOfToday.add(Duration(days: daysAhead));
    }

    return null;
  }

  static String? _parseExplicitTime(String text) {
    final match = _timeRegex.firstMatch(text);
    if (match == null) {
      return null;
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String? _parsePartOfDay(String text) {
    const parts = {
      'morning': '09:00',
      'утром': '09:00',
      'in the morning': '09:00',
      'afternoon': '14:00',
      'днем': '14:00',
      'днём': '14:00',
      'evening': '19:00',
      'вечером': '19:00',
      'night': '22:00',
      'ночью': '22:00',
    };

    for (final entry in parts.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }
}
