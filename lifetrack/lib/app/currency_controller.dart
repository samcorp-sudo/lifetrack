import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class CurrencyController {
  CurrencyController._();

  static const _key = 'settings.currency_code';
  static final ValueNotifier<String> code =
      ValueNotifier(AppConstants.defaultCurrencyCode);

  static const symbols = <String, String>{
    'PHP': '₱',
    'USD': '\$',
    'EUR': '€',
    'JPY': '¥',
  };

  // Conversion rate FROM 1 PHP TO the target currency.
  // e.g. if 1 PHP = 0.017 USD, ratesFromPhp['USD'] = 0.017
  static const ratesFromPhp = <String, double>{
    'PHP': 1.0,
    'USD': 0.017,
    'EUR': 0.016,
    'JPY': 2.6,
  };

  static String get symbol =>
      symbols[code.value] ?? AppConstants.defaultCurrencySymbol;

  static double fromPhp(double amount) =>
      amount * (ratesFromPhp[code.value] ?? 1);

  static double toPhp(double amount) =>
      amount / (ratesFromPhp[code.value] ?? 1);

  static String format(double amount) => NumberFormat.currency(
        symbol: symbol,
        decimalDigits: code.value == 'JPY' ? 0 : 2,
      ).format(fromPhp(amount));

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_key);
    if (saved != null && AppConstants.supportedCurrencyCodes.contains(saved)) {
      code.value = saved;
    }
  }

  static Future<void> setCode(String value) async {
    if (!AppConstants.supportedCurrencyCodes.contains(value)) return;
    code.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }
}