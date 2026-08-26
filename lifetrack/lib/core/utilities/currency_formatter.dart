import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Formats numbers as currency, defaulting to PHP (₱) per Phase 2 §9.
/// Centralized here so switching the user's currency later (Settings)
/// only means changing the symbol passed in, not touching every screen.
class CurrencyFormatter {
  static String format(
    double amount, {
    String symbol = AppConstants.defaultCurrencySymbol,
  }) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: amount == amount.roundToDouble() ? 0 : 2,
    );
    return formatter.format(amount);
  }

  /// e.g. "+₱2,000" / "-₱150" for transaction rows (Screen 4).
  static String formatSigned(double amount, {String symbol = AppConstants.defaultCurrencySymbol}) {
    final sign = amount >= 0 ? '+' : '-';
    return '$sign${format(amount.abs(), symbol: symbol)}';
  }
}
