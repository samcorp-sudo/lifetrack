/// App-wide constant values.
class AppConstants {
  static const String appName = 'LifeTrack';

  static const String defaultCurrencyCode = 'PHP';
  static const String defaultCurrencySymbol = '₱';
  static const List<String> supportedCurrencyCodes = ['PHP', 'USD', 'EUR', 'JPY'];

  static const List<String> scheduleCategories = [
    'School',
    'Coding',
    'Freelance',
    'Farming',
    'Personal',
    'Rest',
  ];

  static const List<String> incomeCategories = [
    'Freelance',
    'Allowance',
    'Business',
    'Gift',
    'Other',
  ];

  static const List<String> expenseCategories = [
    'Food',
    'Transportation',
    'School',
    'Software',
    'Internet',
    'Personal',
    'Family',
    'Farming',
    'Other',
  ];

  static const List<String> accountTypes = [
    'Cash',
    'GCash',
    'Bank',
    'PayPal',
    'Other',
  ];

  static const List<String> goalCategories = [
    'Emergency savings',
    'New phone',
    'Computer',
    'Business',
    'Education',
    'Travel',
    'Custom goal',
  ];

  static const List<int> freeTimeOptionsMinutes = [30, 60, 120, 180];

  // Phase 4 — waking-hours window used for free-time-block detection
  // (Time Analytics §8). Whatever isn't covered by a schedule entry inside
  // this window counts as free time.
  static const String dayStartTime = '06:00';
  static const String dayEndTime = '22:00';

  // Phase 4 §9 — Focus Timer defaults.
  static const int focusDurationMinutes = 25;
  static const int focusBreakMinutes = 5;
}