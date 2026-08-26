import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class CurrencyController {
  CurrencyController._();

  static const _key = 'settings.currency_code';
  static final ValueNotifier<String> code = ValueNotifier(AppConstants.defaultCurrencyCode);

  static const symbols = <String, String>{'PHP': '₱', 'USD': '4', 'EUR': '€', 'JPY': '¥'};

  static String get symbol => symbols[code.value] ?? AppConstants.defaultCurrencySymbol;

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_key);
    if (saved != null && AppConstants.supportedCurrencyCodes.contains(saved)) code.value = saved;
  }

  static Future<void> setCode(String value) async {
    if (!AppConstants.supportedCurrencyCodes.contains(value)) return;
    code.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }
}
