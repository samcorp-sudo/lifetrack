import 'package:flutter/material.dart';

IconData iconForEmoji(String value) => switch (value) {
      '💵' => Icons.payments_rounded,
      '📱' => Icons.phone_android_rounded,
      '🏦' => Icons.account_balance_rounded,
      '💻' => Icons.laptop_mac_rounded,
      '🖥️' => Icons.desktop_windows_rounded,
      '💳' => Icons.credit_card_rounded,
      '🏫' => Icons.school_rounded,
      '🍴' => Icons.restaurant_rounded,
      '🟢' => Icons.circle_rounded,
      '🧑‍💻' => Icons.engineering_rounded,
      '☕' => Icons.coffee_rounded,
      '⚛️' => Icons.science_rounded,
      '🦋' => Icons.flutter_dash_rounded,
      '🐍' => Icons.code_rounded,
      '⭐' => Icons.star_rounded,
      '🌐' => Icons.language_rounded,
      '😴' => Icons.bedtime_rounded,
      _ => Icons.category_rounded,
    };