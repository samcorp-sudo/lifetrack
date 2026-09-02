// ============================================================================
// ReceiptParser
// ----------------------------------------------------------------------------
// Turns the raw text read from a photo of a bill / receipt / deposit slip
// into a suggested transaction: kind (expense or deposit), amount, merchant,
// category and date.
//
// This is a best-effort guess. The app always shows the result to the user
// to check and edit before anything is saved.
// ============================================================================

enum ScanKind { expense, deposit }

class ReceiptScan {
  const ReceiptScan({
    required this.kind,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.date,
    required this.rawText,
  });

  final ScanKind kind;

  /// null when no amount could be found.
  final double? amount;
  final String merchant;
  final String category;
  final DateTime date;
  final String rawText;
}

class ReceiptParser {
  ReceiptParser._();

  // Words that mean money is coming IN (a deposit / cash-in slip).
  static const List<String> _depositWords = [
    'deposit',
    'cash in',
    'cash-in',
    'cashin',
    'credited',
    'top up',
    'top-up',
    'topup',
    'money in',
    'incoming',
    'you received',
    'received from',
  ];

  // Lines that usually hold the final amount, best match first.
  static const List<String> _totalKeywords = [
    'grand total',
    'total amount',
    'amount due',
    'total due',
    'total payable',
    'amount to pay',
    'net amount',
    'total',
    'amount paid',
    'amount',
    'payment',
  ];

  static const List<String> _months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  // 1,250.00  .  550.00  .  12.5 is ignored (needs 2 decimals).
  static final RegExp _decimalMoney =
      RegExp(r'(?<![\d.,])(\d{1,3}(?:,\d{3})+|\d+)\.(\d{2})(?!\d)');

  // 1,250  .  550  (whole pesos), only used on lines that name a total.
  static final RegExp _wholeMoney =
      RegExp(r'(?<![\d.,])(\d{1,3}(?:,\d{3})+|\d{2,7})(?![\d.,])');

  static ReceiptScan parse(String text, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final lower = text.toLowerCase();

    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final kind = _depositWords.any(lower.contains)
        ? ScanKind.deposit
        : ScanKind.expense;

    final merchant = _findMerchant(lines);
    final category = kind == ScanKind.deposit
        ? 'Deposit'
        : _guessCategory(lines.take(6).join(' ').toLowerCase());

    return ReceiptScan(
      kind: kind,
      amount: _findAmount(lines),
      merchant: merchant,
      category: category,
      date: _findDate(text, today) ??
          DateTime(today.year, today.month, today.day),
      rawText: text,
    );
  }

  // --- Amount ---------------------------------------------------------------

  static double? _findAmount(List<String> lines) {
    for (final keyword in _totalKeywords) {
      for (var i = 0; i < lines.length; i++) {
        final lower = lines[i].toLowerCase();
        if (!lower.contains(keyword)) continue;

        if (keyword == 'total' &&
            (lower.contains('subtotal') ||
                lower.contains('sub total') ||
                lower.contains('total item') ||
                lower.contains('total qty'))) {
          continue;
        }

        var value = _lastAmount(lines[i]);
        if (value == null && i + 1 < lines.length) {
          value = _lastAmount(lines[i + 1]);
        }
        if (value != null && value > 0) return value;
      }
    }

    // Fallback: the largest price-looking number anywhere on the page.
    double? best;
    for (final line in lines) {
      for (final match in _decimalMoney.allMatches(line)) {
        final value = _toNumber(match.group(1)!, match.group(2));
        if (value != null && (best == null || value > best)) best = value;
      }
    }
    return best;
  }

  /// The last amount on a line (totals are usually at the right-hand end).
  static double? _lastAmount(String line) {
    final decimals = _decimalMoney.allMatches(line).toList();
    if (decimals.isNotEmpty) {
      final m = decimals.last;
      return _toNumber(m.group(1)!, m.group(2));
    }
    final wholes = _wholeMoney.allMatches(line).toList();
    if (wholes.isNotEmpty) {
      return _toNumber(wholes.last.group(1)!, null);
    }
    return null;
  }

  static double? _toNumber(String whole, String? decimals) {
    final clean = whole.replaceAll(',', '');
    return double.tryParse(decimals == null ? clean : '$clean.$decimals');
  }

  // --- Merchant ---------------------------------------------------------------

  static String _findMerchant(List<String> lines) {
    const skip = [
      'receipt',
      'invoice',
      'official',
      'tel',
      'tin',
      'vat',
      'date',
      'www',
      'http',
      'cashier',
      'order',
    ];

    for (final line in lines.take(6)) {
      if (!RegExp(r'[A-Za-z]{3,}').hasMatch(line)) continue;
      final lower = line.toLowerCase();
      if (skip.any(lower.contains)) continue;
      return line.length > 40 ? line.substring(0, 40).trim() : line;
    }
    return '';
  }

  // --- Category ---------------------------------------------------------------

  static String _guessCategory(String header) {
    bool has(List<String> words) => words.any(header.contains);

    if (has(['meralco', 'electric', 'water', 'internet', 'pldt', 'converge', 'globe', 'smart', 'bill', 'utilit'])) {
      return 'Bills';
    }
    if (has(['jollibee', 'mcdo', 'mcdonald', 'kfc', 'restaurant', 'cafe', 'coffee', 'starbucks', 'bakery', 'food', 'grill', 'pizza'])) {
      return 'Food';
    }
    if (has(['supermarket', 'grocery', 'groceries', 'market', 'mart', 'sm ', '7-eleven', '7 eleven', 'puregold'])) {
      return 'Groceries';
    }
    if (has(['petron', 'shell', 'caltex', 'gas', 'fuel', 'grab', 'transport'])) {
      return 'Transport';
    }
    if (has(['pharmacy', 'drug', 'mercury', 'clinic', 'hospital', 'medical'])) {
      return 'Health';
    }
    return 'Shopping';
  }

  // --- Date ---------------------------------------------------------------------

  static DateTime? _findDate(String text, DateTime today) {
    final candidates = <DateTime?>[];

    // 2026-11-02, 2026/11/02
    for (final m in RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').allMatches(text)) {
      candidates.add(_build(int.parse(m.group(1)!), int.parse(m.group(2)!),
          int.parse(m.group(3)!), today));
    }

    // 11/02/2026 (month first), or 25/11/2026 (day first when 25 > 12)
    for (final m in RegExp(r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})').allMatches(text)) {
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final year = int.parse(m.group(3)!);
      candidates.add(a > 12
          ? _build(year, b, a, today)
          : _build(year, a, b, today));
    }

    // Nov 2, 2026   .   November 2 2026
    for (final m in RegExp(
            r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})',
            caseSensitive: false)
        .allMatches(text)) {
      candidates.add(_build(int.parse(m.group(3)!),
          _months.indexOf(m.group(1)!.toLowerCase()) + 1,
          int.parse(m.group(2)!), today));
    }

    // 2 Nov 2026
    for (final m in RegExp(
            r'(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?,?\s+(\d{4})',
            caseSensitive: false)
        .allMatches(text)) {
      candidates.add(_build(int.parse(m.group(3)!),
          _months.indexOf(m.group(2)!.toLowerCase()) + 1,
          int.parse(m.group(1)!), today));
    }

    for (final c in candidates) {
      if (c != null) return c;
    }
    return null;
  }

  /// A real, sensible date (not in the far future), or null.
  static DateTime? _build(int year, int month, int day, DateTime today) {
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.month != month) return null; // e.g. Feb 31 rolled over
    final limit = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 1));
    if (date.isAfter(limit)) return null;
    return date;
  }
}
