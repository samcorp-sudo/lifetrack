// ============================================================================
// Profile Screen  (hosts Settings, Plan picker, Payment UI, Receipt UI)
// ----------------------------------------------------------------------------
// Sign-out flow (redesigned):
//   1. "Sign out?" confirmation dialog (centered AlertDialog with icon, title,
//      message, Cancel / Sign out).
//   2. _SignOutProgressDialog — same visual language as the sign-in and
//      payment sheets:
//        - Rotating logout icon in a ring while the sign out runs.
//        - After success: accent checkmark pops in, "Signed out" title,
//          "See you soon!" subtitle, progress bar.
//        - Minimum 1.5s so it never flashes.
//   3. Profile screen pops.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/currency_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/security/local_mode.dart';
import '../../../core/security/security_service.dart';
import '../../../services/profile_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/lifetrack_dialog.dart';
import '../../../main.dart' show AuthGate;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- Layout tokens -------------------------------------------------------
  static const double _avatarRadius = 40;
  static const double _sectionGap = 24;
  static const double _iconChipSize = 40;

  static const double _screenHorizontalPadding = 20;
  static const double _screenTopPadding = 24;
  static const double _screenBottomPadding = 40;
  static const double _settingsSectionGap = 24;
  static const double _settingsSectionLabelBottomGap = 10;
  static const double _rowVerticalPadding = 12;
  static const double _rowIconLabelGap = 14;
  static const double _cardContentHorizontalPadding = 14;
  static const double _cardContentVerticalPadding = 10;
  static const double _settingsIconChipSize = 34;
  static const double _settingsCardRadius = 18;
  static const double _rowBetweenGap = 6;

  static const double _rowGap = 12;
  static const _automaticBackupKey = 'settings.automatic_backup';
  static const _automaticBackupInterval = Duration(days: 1);
  static const _selectedPlanKey = 'profile.selected_plan';

  // --- Services / futures --------------------------------------------------
  final _service = ProfileService();
  final _securityService = SecurityService();
  late Future<User?> _profileFuture;
  late Future<_PlanInfo> _planFuture;

  // --- Settings state ------------------------------------------------------
  Timer? _automaticBackupTimer;
  bool _automaticBackup = false;
  bool _appLock = false;
  bool _biometric = false;
  bool get _darkMode => ThemeModeController.mode.value == ThemeMode.dark;
  bool _cloudSync = false;
  int _autoLockMinutes = 5;
  String get _currencyCode => CurrencyController.code.value;

  @override
  void initState() {
    super.initState();
    _profileFuture = _service.getCurrentProfile();
    _loadSelectedPlan();
    _loadSecuritySettings();
    _loadAutomaticBackupSetting();
  }

  @override
  void dispose() {
    _automaticBackupTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Plan persistence
  // ---------------------------------------------------------------------

  Future<void> _loadSelectedPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_selectedPlanKey);
      final tier = _PlanTier.values.firstWhere(
        (t) => t.name == saved,
        orElse: () => _PlanTier.free,
      );
      if (!mounted) return;
      setState(() {
        _planFuture = Future.value(_PlanInfo.forTier(tier));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _planFuture = Future.value(_PlanInfo.forTier(_PlanTier.free));
      });
    }
  }

  Future<void> _saveSelectedPlan(_PlanTier tier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedPlanKey, tier.name);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Profile actions
  // ---------------------------------------------------------------------

  Future<void> _editDisplayName(User user) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _EditNameSheet(
        initialName: user.displayName ?? '',
        email: user.email,
      ),
    );
    if (name == null || name == user.displayName) return;
    try {
      await _service.updateDisplayName(name);
      if (mounted) {
        setState(() => _profileFuture = _service.getCurrentProfile());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to update your name.')));
      }
    }
  }

  Future<void> _signOutKeepingData() async {
    await LocalMode.set(true);
    try {
      await _service.signOut();
    } catch (_) {
      await LocalMode.set(false);
      rethrow;
    }
  }

  Future<void> _goToSignIn() async {
    await LocalMode.set(false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  // ---------------------------------------------------------------------
  // Sign out — confirmation, then redesigned animation, then leave.
  // ---------------------------------------------------------------------

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.logout_rounded,
            size: 32, color: context.season.accentText),
        title: const Text('Sign out?'),
        content: const Text(
          'Your data stays on this phone. You can sign in again anytime.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SignOutProgressDialog(task: _signOutKeepingData),
    );
    if (!mounted) return;
    if (ok == false) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to sign out. Try again.')));
      return;
    }
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------
  // Plan flow
  // ---------------------------------------------------------------------

  Future<void> _showPlanPicker() async {
    final current = await _planFuture;
    if (!mounted) return;
    final picked = await showModalBottomSheet<_PlanTier>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _PlanPickerSheet(currentTier: current.tier),
    );
    if (picked == null || picked == current.tier) return;

    if (picked == _PlanTier.free) {
      await _saveSelectedPlan(picked);
      if (!mounted) return;
      setState(() {
        _planFuture = Future.value(_PlanInfo.forTier(picked));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switched to Free plan.')),
        );
      }
      return;
    }

    final plan = _PlanInfo.forTier(picked);
    final paid = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => _PaymentSheet(plan: plan),
    );
    if (paid != true) return;

    await _saveSelectedPlan(picked);
    if (!mounted) return;
    setState(() {
      _planFuture = Future.value(plan);
    });

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _ReceiptSheet(
        plan: plan,
        reference: _generateReference(),
        paidAt: DateTime.now(),
      ),
    );
  }

  Future<void> _showPlanDetails(_PlanInfo plan) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _PlanDetailsSheet(
        plan: plan,
        onManage: () {
          Navigator.pop(sheetContext);
          _onManagePlan(plan);
        },
      ),
    );
  }

  void _onManagePlan(_PlanInfo plan) {
    if (plan.tier == _PlanTier.free) {
      _showPlanPicker();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TODO: open manage-subscription flow')),
    );
  }

  String _generateReference() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    final seed = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer('LT-');
    var v = seed;
    for (var i = 0; i < 6; i++) {
      buffer.write(chars[v % chars.length]);
      v ~/= chars.length;
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------
  // Security
  // ---------------------------------------------------------------------

  Future<void> _loadSecuritySettings() async {
    final appLock = await _securityService.isAppLockEnabled();
    final biometric = await _securityService.isBiometricEnabled();
    final autoLockMinutes = await _securityService.getAutoLockMinutes();
    if (!mounted) return;
    setState(() {
      _appLock = appLock;
      _biometric = biometric;
      _autoLockMinutes = autoLockMinutes;
    });
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (!enabled) {
      await _securityService.setAppLockEnabled(false);
      if (mounted) setState(() => _appLock = false);
      return;
    }
    if (!await _securityService.hasPin()) {
      final pin = await _requestPin();
      if (pin == null) return;
      await _securityService.setPin(pin);
    } else {
      await _securityService.setAppLockEnabled(true);
    }
    if (mounted) setState(() => _appLock = true);
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (!enabled) {
      await _securityService.setBiometricEnabled(false);
      if (mounted) setState(() => _biometric = false);
      return;
    }
    if (!await _securityService.isBiometricAvailable()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Register a fingerprint or face unlock in your phone settings first.')));
      }
      return;
    }
    if (!await _securityService.hasPin()) {
      final pin = await _requestPin();
      if (pin == null) return;
      await _securityService.setPin(pin);
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable biometric unlock?'),
        content: const Text(
            'LifeTrack uses the biometric registered on this phone. Your biometric data is never stored by LifeTrack.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final authenticated = await _securityService.authenticateBiometric();
    if (!mounted) return;
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric setup was not completed.')));
      return;
    }
    await _securityService.setAppLockEnabled(true);
    await _securityService.setBiometricEnabled(true);
    if (mounted) {
      setState(() {
        _appLock = true;
        _biometric = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock is enabled.')));
    }
  }

  Future<String?> _requestPin() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set app PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(hintText: '4 digits'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{4}$').hasMatch(controller.text)) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return pin;
  }

  String get _autoLockLabel => _autoLockMinutes == 0
      ? 'Immediately'
      : _autoLockMinutes < 0
          ? 'Never'
          : '$_autoLockMinutes min';

  Future<void> _pickAutoLock() async {
    const options = <int>[0, 1, 5, 15, -1];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Auto Lock'),
        children: options.map((minutes) {
          final label = minutes == 0
              ? 'Immediately'
              : minutes < 0
                  ? 'Never'
                  : '$minutes minute${minutes == 1 ? '' : 's'}';
          return ListTile(
            title: Text(label),
            trailing: minutes == _autoLockMinutes
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () => Navigator.pop(dialogContext, minutes),
          );
        }).toList(),
      ),
    );
    if (selected == null) return;
    await _securityService.setAutoLockMinutes(selected);
    if (mounted) setState(() => _autoLockMinutes = selected);
  }

  // ---------------------------------------------------------------------
  // Automatic backup
  // ---------------------------------------------------------------------

  Future<void> _loadAutomaticBackupSetting() async {
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_automaticBackupKey) ?? false;
    if (!mounted) return;
    setState(() => _automaticBackup = enabled);
    if (enabled) _scheduleAutomaticBackup();
  }

  void _scheduleAutomaticBackup() {
    _automaticBackupTimer?.cancel();
    _automaticBackupTimer = Timer.periodic(
      _automaticBackupInterval,
      (_) => _runAutomaticBackup(),
    );
  }

  Future<void> _toggleAutomaticBackup(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_automaticBackupKey, enabled);
    if (!mounted) return;
    setState(() => _automaticBackup = enabled);
    if (enabled) {
      _scheduleAutomaticBackup();
      await _runAutomaticBackup();
    } else {
      _automaticBackupTimer?.cancel();
      _automaticBackupTimer = null;
    }
  }

  Future<void> _runAutomaticBackup() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      final tables = <String, List<Map<String, Object?>>>{};
      for (final row in tableRows) {
        final tableName = row['name']! as String;
        tables[tableName] = await db.query(tableName);
      }
      final exportedAt = DateTime.now().toUtc();
      final backup = <String, Object?>{
        'format': 'lifetrack-backup',
        'version': 1,
        'exportedAt': exportedAt.toIso8601String(),
        'currencyCode': CurrencyController.code.value,
        'tables': tables,
      };
      final directory = await getApplicationDocumentsDirectory();
      final backupDirectory =
          Directory('${directory.path}${Platform.pathSeparator}backups');
      await backupDirectory.create(recursive: true);
      final fileName =
          'lifetrack_backup_${exportedAt.toIso8601String().replaceAll(':', '-')}.json';
      final file =
          File('${backupDirectory.path}${Platform.pathSeparator}$fileName');
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(backup));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Manual export / import
  // ---------------------------------------------------------------------

  Future<void> _exportBackup() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final tableRows = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      final tables = <String, List<Map<String, Object?>>>{};
      for (final row in tableRows) {
        final tableName = row['name']! as String;
        tables[tableName] = await db.query(tableName);
      }
      final exportedAt = DateTime.now().toUtc();
      final backup = <String, Object?>{
        'format': 'lifetrack-backup',
        'version': 1,
        'exportedAt': exportedAt.toIso8601String(),
        'currencyCode': CurrencyController.code.value,
        'tables': tables,
      };
      final json = const JsonEncoder.withIndent('  ').convert(backup);
      final fileName =
          'lifetrack_backup_${exportedAt.toIso8601String().replaceAll(':', '-')}.json';
      final location = await getSaveLocation(suggestedName: fileName);
      if (location == null) return;
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(json)),
        name: fileName,
        mimeType: 'application/json',
      );
      await file.saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup exported successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup export failed: $error')),
      );
    }
  }

  Future<void> _importBackup() async {
    try {
      final selected = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON backup', extensions: ['json']),
        ],
      );
      if (selected == null) return;

      final payload = jsonDecode(await selected.readAsString());
      if (payload is! Map ||
          payload['format'] != 'lifetrack-backup' ||
          payload['version'] != 1 ||
          payload['tables'] is! Map) {
        throw const FormatException('Invalid LifeTrack backup file.');
      }
      final rawTables = Map<Object?, Object?>.from(payload['tables'] as Map);
      const restoreOrder = <String>[
        'schedule',
        'tasks',
        'accounts',
        'transactions',
        'assets',
        'liabilities',
        'net_worth_snapshots',
        'goals',
        'goal_contributions',
        'skills',
        'skill_sessions',
        'recommendation_history'
      ];
      final tables = <String, List<Map<String, Object?>>>{};
      for (final entry in rawTables.entries) {
        if (entry.key is! String || !restoreOrder.contains(entry.key)) {
          throw const FormatException('Backup contains an unknown table.');
        }
        final rows = entry.value;
        if (rows is! List || rows.any((row) => row is! Map)) {
          throw const FormatException('Backup contains invalid table data.');
        }
        tables[entry.key as String] =
            rows.map((row) => Map<String, Object?>.from(row as Map)).toList();
      }

      if (!mounted) return;
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore Backup?'),
          content: const Text('This will replace all current LifeTrack data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (shouldRestore != true) return;

      final db = await DatabaseHelper.instance.database;
      await db.transaction((transaction) async {
        for (final tableName in restoreOrder.reversed) {
          await transaction.delete(tableName);
        }
        for (final tableName in restoreOrder) {
          for (final row in tables[tableName] ?? const []) {
            await transaction.insert(tableName, row);
          }
        }
      });
      final currencyCode = payload['currencyCode'];
      if (currencyCode is String &&
          AppConstants.supportedCurrencyCodes.contains(currencyCode)) {
        await CurrencyController.setCode(currencyCode);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup restore failed: $error')),
      );
    }
  }

  Future<void> _deleteAllData() async {
    try {
      await DatabaseHelper.instance.clearAllData();
      await _securityService.clearSettings();
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_automaticBackupKey);
      await preferences.remove(_selectedPlanKey);
      await CurrencyController.setCode(AppConstants.defaultCurrencyCode);
      ThemeModeController.mode.value = ThemeMode.system;
      _automaticBackupTimer?.cancel();
      _automaticBackupTimer = null;
      final directory = await getApplicationDocumentsDirectory();
      final backupDirectory =
          Directory('${directory.path}${Platform.pathSeparator}backups');
      if (await backupDirectory.exists()) {
        await backupDirectory.delete(recursive: true);
      }
      if (!mounted) return;
      setState(() {
        _appLock = false;
        _biometric = false;
        _automaticBackup = false;
        _autoLockMinutes = 5;
        _planFuture = Future.value(_PlanInfo.forTier(_PlanTier.free));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete all data: $error')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Currency / Season pickers
  // ---------------------------------------------------------------------

  Future<void> _pickCurrency() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Currency'),
        children: AppConstants.supportedCurrencyCodes
            .map((currency) => ListTile(
                  title: Text(currency),
                  trailing: currency == _currencyCode
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(dialogContext, currency),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    await CurrencyController.setCode(selected);
    if (mounted) setState(() {});
  }

  Future<void> _pickSeason() async {
    final selected = await showDialog<SeasonMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Season'),
        children: SeasonMode.values.map((m) {
          return ListTile(
            title: Text(m.label),
            subtitle: Text(m.subtitle),
            trailing: m == SeasonController.mode.value
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () => Navigator.pop(dialogContext, m),
          );
        }).toList(),
      ),
    );
    if (selected == null) return;
    await SeasonController.setMode(selected);
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: FutureBuilder<User?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              _screenHorizontalPadding,
              _screenTopPadding,
              _screenHorizontalPadding,
              _screenBottomPadding,
            ),
            children: [
              user == null
                  ? _guestHeader(context)
                  : _profileHeader(context, user),

              if (user == null) ...[
                const SizedBox(height: 16),
                _signInBanner(context),
              ],

              const SizedBox(height: _sectionGap),

              FutureBuilder<_PlanInfo>(
                future: _planFuture,
                builder: (context, planSnapshot) {
                  if (!planSnapshot.hasData) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _planHeroCard(context, planSnapshot.data!);
                },
              ),
              const SizedBox(height: _settingsSectionGap),

              if (user != null) ...[
                _sectionLabel(context, 'ACCOUNT'),
                _plainCard(context, [
                  _infoRow(context, 'Email', user.email ?? 'Not available',
                      Icons.email_outlined),
                  _infoRow(
                      context,
                      'Account created',
                      _formatDate(user.metadata.creationTime),
                      Icons.calendar_today_outlined),
                  _infoRow(
                      context,
                      'Last sign-in',
                      _formatDate(user.metadata.lastSignInTime),
                      Icons.login_rounded),
                ]),
                const SizedBox(height: _settingsSectionGap),
              ],

              _sectionLabel(context, 'SECURITY'),
              _plainCard(context, [
                _switchRow(context, Icons.lock_rounded, 'App Lock', _appLock,
                    _toggleAppLock),
                _navRow(context, Icons.timer_rounded, 'Auto Lock',
                    _autoLockLabel, _pickAutoLock),
                _switchRow(context, Icons.fingerprint_rounded, 'Biometric',
                    _biometric, _toggleBiometric),
              ]),
              const SizedBox(height: _settingsSectionGap),

              _sectionLabel(context, 'APPEARANCE'),
              _plainCard(context, [
                _switchRow(context, Icons.dark_mode_rounded, 'Dark Mode',
                    _darkMode, (v) {
                  ThemeModeController.mode.value =
                      v ? ThemeMode.dark : ThemeMode.light;
                  setState(() {});
                }),
                _navRow(context, Icons.wb_sunny_rounded, 'Season',
                    SeasonController.mode.value.label, _pickSeason),
                _navRow(context, Icons.currency_exchange_rounded, 'Currency',
                    _currencyCode, _pickCurrency),
              ]),
              const SizedBox(height: _settingsSectionGap),

              _sectionLabel(context, 'DATA'),
              _plainCard(context, [
                _actionRow(context, Icons.save_alt_rounded, 'Export Backup',
                    _exportBackup),
                _actionRow(context, Icons.file_download_rounded,
                    'Import Backup', _importBackup),
                _switchRow(context, Icons.backup_rounded, 'Automatic Backup',
                    _automaticBackup, _toggleAutomaticBackup),
              ]),
              const SizedBox(height: _settingsSectionGap),

              _sectionLabel(context, 'CLOUD'),
              _plainCard(context, [
                _switchRow(context, Icons.cloud_rounded, 'Cloud Sync',
                    _cloudSync, (v) => setState(() => _cloudSync = v)),
              ]),
              const SizedBox(height: _settingsSectionGap),

              _plainCard(context, [_destructiveRow(context)]),
              const SizedBox(height: _settingsSectionGap),

              _plainCard(context, [_aboutRow(context)]),
              const SizedBox(height: _settingsSectionGap),

              if (user != null)
                OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out')),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Sign-in banner
  // ---------------------------------------------------------------------

  Widget _signInBanner(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    return Material(
      color: s.accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _goToSignIn,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: s.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lock_open_rounded,
                    size: 20, color: s.accentText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sign in or sign up',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Your data is on this phone. Sign in to keep it across devices.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _goToSignIn,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------

  Widget _guestHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: context.season.accent.withValues(alpha: 0.16),
          child: Icon(Icons.person_outline_rounded,
              size: 36, color: context.season.accentText),
        ),
        const SizedBox(height: 14),
        Text('Not signed in', style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text('Your data is saved on this phone.',
            style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _profileHeader(BuildContext context, User user) {
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: context.season.accent.withValues(alpha: 0.16),
          child: Text(_initials(user),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: context.season.accentText,
              )),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                user.displayName ?? 'LifeTrack user',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Edit name',
              onPressed: () => _editDisplayName(user),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.edit_rounded,
                  size: 18, color: context.season.accentText),
            ),
          ],
        ),
        if (user.email != null) ...[
          const SizedBox(height: 2),
          Text(user.email!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Plan hero card
  // ---------------------------------------------------------------------

  Widget _planHeroCard(BuildContext context, _PlanInfo plan) {
    final theme = Theme.of(context);
    final color = plan.badgeColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(right: -40, top: -50, child: _decorCircle(170)),
            Positioned(right: 30, bottom: -70, child: _decorCircle(140)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showPlanPicker,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(plan.icon,
                                size: 22, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${plan.label} plan',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (plan.priceLabel != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    plan.priceLabel!,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              plan.isActive ? 'ACTIVE' : 'EXPIRED',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (plan.features.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        for (final feature in plan.features.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white.withValues(alpha: 0.9)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                          onPressed: _showPlanPicker,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Change plan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Info row
  // ---------------------------------------------------------------------

  Widget _infoRow(
      BuildContext context, String label, String value, IconData icon) {
    final primary = context.season.accentText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _iconChipSize,
            height: _iconChipSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Plain card
  // ---------------------------------------------------------------------

  Widget _plainCard(BuildContext context, List<Widget> rows) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).cardColor,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_settingsCardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _cardContentHorizontalPadding,
          vertical: _cardContentVerticalPadding,
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: _rowBetweenGap),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(
            bottom: _settingsSectionLabelBottomGap, left: 8, top: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 0.6,
              ),
        ),
      );

  Widget _iconChip(Color color, IconData icon) {
    return Container(
      width: _settingsIconChipSize,
      height: _settingsIconChipSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _switchRow(BuildContext context, IconData icon, String label,
      bool value, ValueChanged<bool> onChanged) {
    final color = context.season.accentText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
      child: Row(
        children: [
          _iconChip(color, icon),
          const SizedBox(width: _rowIconLabelGap),
          Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: context.season.accent),
        ],
      ),
    );
  }

  Widget _navRow(BuildContext context, IconData icon, String label,
      String value, VoidCallback onTap) {
    final color = context.season.accentText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
        child: Row(
          children: [
            _iconChip(color, icon),
            const SizedBox(width: _rowIconLabelGap),
            Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodyLarge)),
            Text(value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                    )),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _actionRow(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final color = context.season.accentText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
        child: Row(
          children: [
            _iconChip(color, icon),
            const SizedBox(width: _rowIconLabelGap),
            Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodyLarge)),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _destructiveRow(BuildContext context) {
    return GestureDetector(
      onTap: () => LifeTrackDialog.show(
        context,
        title: 'Delete All Data',
        message:
            'This permanently erases every account, goal, task and setting. This cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          _deleteAllData();
        },
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
        child: Row(
          children: [
            _iconChip(LifeTrackColors.coral, Icons.warning_amber_rounded),
            const SizedBox(width: _rowIconLabelGap),
            Expanded(
                child: Text('Delete All Data',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: LifeTrackColors.coral))),
          ],
        ),
      ),
    );
  }

  Widget _aboutRow(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAboutAndLicenses(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
        child: Row(
          children: [
            Expanded(
                child: Text('About LifeTrack',
                    style: Theme.of(context).textTheme.bodyLarge)),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showAboutAndLicenses(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'LifeTrack',
      applicationVersion: '0.3.0',
      applicationIcon: Icon(Icons.track_changes_rounded,
          size: 40, color: context.season.accent),
      applicationLegalese:
          'Personal time, money, goals and skills tracker.\n\n'
          'Open-source packages used:\n'
          '• Flutter — BSD-3-Clause (Google)\n'
          '• Firebase (core, auth, messaging) — BSD-3-Clause (Google)\n'
          '• provider — MIT\n'
          '• sqflite — BSD-2-Clause\n'
          '• path / path_provider — BSD-3-Clause\n'
          '• timezone — BSD-2-Clause\n'
          '• intl — BSD-3-Clause\n'
          '• google_fonts — Apache-2.0\n'
          '• fl_chart — MIT\n'
          '• shared_preferences — BSD-3-Clause\n'
          '• flutter_local_notifications — BSD-3-Clause\n'
          '• local_auth — BSD-3-Clause\n'
          '• flutter_secure_storage — BSD-3-Clause\n'
          '• crypto — BSD-3-Clause\n'
          '• file_selector — BSD-3-Clause\n'
          '• image_picker — BSD-3-Clause\n'
          '• cupertino_icons — MIT\n'
          '• google_mlkit_text_recognition — MIT\n\n'
          'Full license texts are bundled with the app and can be viewed '
          'under Licenses in this dialog.',
      children: [
        const SizedBox(height: 12),
        Text(
          'LifeTrack runs fully offline. Nothing is uploaded unless you '
          'explicitly enable Cloud Sync.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Small utilities
  // ---------------------------------------------------------------------

  String _initials(User user) {
    final name = user.displayName?.trim();
    if (name == null || name.isEmpty) {
      return (user.email ?? 'U').substring(0, 1).toUpperCase();
    }
    return name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.substring(0, 1))
        .join()
        .toUpperCase();
  }

  String _formatDate(DateTime? date) => date == null
      ? 'Not available'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

// ============================================================================
// Signing-out animation dialog.
// ----------------------------------------------------------------------------
// Redesigned to match the sign-in / payment sheets:
//   - Rotating logout icon in an accent ring while the task runs.
//   - After success: accent check pops in (elastic), "Signed out" title,
//     "See you soon!" subtitle, accent progress bar.
//   - Minimum 1.5s visible time so it never flashes.
// Pops `true` on success, `false` on failure.
// ============================================================================
class _SignOutProgressDialog extends StatefulWidget {
  const _SignOutProgressDialog({required this.task});

  final Future<void> Function() task;

  @override
  State<_SignOutProgressDialog> createState() => _SignOutProgressDialogState();
}

class _SignOutProgressDialogState extends State<_SignOutProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _run();
  }

  Future<void> _run() async {
    final started = DateTime.now();
    var ok = true;
    try {
      await widget.task();
    } catch (_) {
      ok = false;
    }
    const minimum = Duration(milliseconds: 1500);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) await Future<void>.delayed(minimum - elapsed);
    if (!mounted) return;
    if (!ok) {
      Navigator.pop(context, false);
      return;
    }
    _loop.stop();
    setState(() => _done = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _done
                ? Column(
                    key: const ValueKey('done'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: s.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded,
                              size: 42, color: s.onAccent),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Signed out', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('See you soon!', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 32,
                        height: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            backgroundColor:
                                s.accent.withValues(alpha: 0.18),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(s.accent),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('working'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rotating logout icon in an accent ring.
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: s.accent,
                                backgroundColor:
                                    s.accent.withValues(alpha: 0.15),
                              ),
                            ),
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: s.accent.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: AnimatedBuilder(
                                  animation: _loop,
                                  builder: (context, _) {
                                    final t = _loop.value;
                                    final angle = t * 2 * 3.1415926;
                                    final scale = 0.94 +
                                        0.06 * (1 - (t * 2 - 1).abs());
                                    return Transform.rotate(
                                      angle: angle,
                                      child: Transform.scale(
                                        scale: scale,
                                        child: Icon(Icons.logout_rounded,
                                            size: 32, color: s.accentText),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Signing out\u2026',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Please wait a moment.',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 18),
                      // Three bouncing accent dots.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return AnimatedBuilder(
                            animation: _loop,
                            builder: (context, _) {
                              final t = (_loop.value + i * 0.2) % 1.0;
                              final wave =
                                  (1 - (t * 2 - 1).abs()).clamp(0.0, 1.0);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Container(
                                  width: 8,
                                  height: 8 + 6 * wave,
                                  decoration: BoxDecoration(
                                    color: s.accent.withValues(
                                        alpha: 0.4 + 0.6 * wave),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Edit name sheet
// ============================================================================
class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({required this.initialName, this.email});

  final String initialName;
  final String? email;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  static const int _maxLength = 40;

  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();

  String get _initials {
    final name = _trimmed;
    if (name.isEmpty) {
      return (widget.email ?? 'U').substring(0, 1).toUpperCase();
    }
    return name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.substring(0, 1))
        .join()
        .toUpperCase();
  }

  void _save() {
    final value = _trimmed;
    if (value.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.edit_rounded,
                        size: 24, color: s.accentText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit name', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          'This is how your name appears in LifeTrack.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: s.accent.withValues(alpha: 0.16),
                      child: Text(
                        _initials,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(color: s.accentText),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _trimmed.isEmpty ? 'LifeTrack user' : _trimmed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (widget.email != null) ...[
                      const SizedBox(height: 2),
                      Text(widget.email!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('DISPLAY NAME', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  errorText: _error,
                  counterText: '',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: s.accentText),
                  filled: true,
                  fillColor: s.accent.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: s.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Plan picker sheet
// ============================================================================
class _PlanPickerSheet extends StatelessWidget {
  const _PlanPickerSheet({required this.currentTier});

  final _PlanTier currentTier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = _PlanInfo.allPresets;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a plan', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Switch anytime. Paid tiers open the checkout screen.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final tier in _PlanTier.values) ...[
              _PlanPickerTile(
                plan: presets[tier]!,
                selected: tier == currentTier,
                onTap: () => Navigator.pop(context, tier),
              ),
              if (tier != _PlanTier.values.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanPickerTile extends StatelessWidget {
  const _PlanPickerTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final _PlanInfo plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = plan.badgeColor;
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : theme.dividerColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(plan.icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${plan.label} plan',
                        style: theme.textTheme.titleMedium),
                    if (plan.priceLabel != null)
                      Text(plan.priceLabel!,
                          style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: color)
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Payment sheet — UI only checkout
// ============================================================================
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.plan});

  final _PlanInfo plan;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  _PaymentMethod _method = _PaymentMethod.gcash;
  bool _processing = false;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Payment failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    final plan = widget.plan;
    final color = plan.badgeColor;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(plan.icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${plan.label} plan',
                            style: theme.textTheme.titleLarge),
                        if (plan.priceLabel != null)
                          Text(plan.priceLabel!,
                              style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    _summaryLine(context, 'Plan', plan.label),
                    const SizedBox(height: 6),
                    _summaryLine(context, 'Billing', 'Monthly, auto-renew'),
                    const SizedBox(height: 6),
                    _summaryLine(
                      context,
                      'Total today',
                      plan.priceLabel ?? '—',
                      emphasized: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('PAYMENT METHOD', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              _methodTile(
                method: _PaymentMethod.gcash,
                label: 'GCash',
                subtitle: 'Pay with your GCash wallet',
                icon: Icons.phone_android_rounded,
                color: const Color(0xFF0070E0),
                current: _method,
                onChanged: (m) => setState(() => _method = m),
              ),
              const SizedBox(height: 8),
              _methodTile(
                method: _PaymentMethod.qrPh,
                label: 'QR Ph',
                subtitle: 'Scan with any QR Ph bank app',
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFF00A67E),
                current: _method,
                onChanged: (m) => setState(() => _method = m),
              ),
              const SizedBox(height: 8),
              _methodTile(
                method: _PaymentMethod.card,
                label: 'Card',
                subtitle: 'Visa, Mastercard, JCB',
                icon: Icons.credit_card_rounded,
                color: s.accentText,
                current: _method,
                onChanged: (m) => setState(() => _method = m),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _processing ? null : _pay,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    _processing
                        ? 'Processing…'
                        : 'Pay ${plan.priceLabel ?? ''}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'UI only — no real charge is made.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryLine(
    BuildContext context,
    String label,
    String value, {
    bool emphasized = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: emphasized
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium),
        Text(value,
            style: emphasized
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _methodTile({
    required _PaymentMethod method,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required _PaymentMethod current,
    required ValueChanged<_PaymentMethod> onChanged,
  }) {
    final theme = Theme.of(context);
    final selected = method == current;
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(method),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : theme.dividerColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleMedium),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Radio<_PaymentMethod>(
                value: method,
                groupValue: current,
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
                activeColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PaymentMethod { gcash, qrPh, card }

// ============================================================================
// Receipt sheet
// ============================================================================
class _ReceiptSheet extends StatelessWidget {
  const _ReceiptSheet({
    required this.plan,
    required this.reference,
    required this.paidAt,
  });

  final _PlanInfo plan;
  final String reference;
  final DateTime paidAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = plan.badgeColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: LifeTrackColors.mint.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: LifeTrackColors.mint, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text('Payment successful',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Your ${plan.label} plan is now active.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  _receiptLine(context, 'Plan', plan.label,
                      icon: plan.icon, color: color),
                  const SizedBox(height: 10),
                  _receiptLine(context, 'Amount', plan.priceLabel ?? '—',
                      emphasized: true),
                  const SizedBox(height: 10),
                  _receiptLine(context, 'Reference', reference),
                  const SizedBox(height: 10),
                  _receiptLine(context, 'Date', _formatReceiptDate(paidAt)),
                  const SizedBox(height: 10),
                  _receiptLine(context, 'Time', _formatReceiptTime(paidAt)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'UI only — no real charge was made.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptLine(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? color,
    bool emphasized = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        if (icon != null) ...[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: emphasized
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _formatReceiptDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatReceiptTime(DateTime d) {
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final min = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }
}

// ============================================================================
// Plan details sheet
// ============================================================================
class _PlanDetailsSheet extends StatelessWidget {
  const _PlanDetailsSheet({required this.plan, required this.onManage});

  final _PlanInfo plan;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final color = plan.badgeColor;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(plan.icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${plan.label} plan',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (plan.priceLabel != null)
                        Text(plan.priceLabel!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (plan.renewsOn != null) ...[
              _detailLine(context, plan.isActive ? 'Renews on' : 'Expired on',
                  plan.renewsOn!),
              const SizedBox(height: 12),
            ],
            if (plan.features.isNotEmpty) ...[
              Text('Included with this plan',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              for (final feature in plan.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded, size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(feature,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onManage,
                icon: Icon(plan.tier == _PlanTier.free
                    ? Icons.upgrade_rounded
                    : Icons.settings_rounded),
                label: Text(plan.tier == _PlanTier.free
                    ? 'Upgrade plan'
                    : 'Manage subscription'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

// ============================================================================
// Plan model + tiers
// ============================================================================
enum _PlanTier { free, student, college, personal, professional }

class _PlanInfo {
  const _PlanInfo({
    required this.tier,
    required this.label,
    required this.icon,
    required this.badgeColor,
    required this.isActive,
    this.priceLabel,
    this.renewsOn,
    this.features = const [],
  });

  final _PlanTier tier;
  final String label;
  final IconData icon;
  final Color badgeColor;
  final bool isActive;
  final String? priceLabel;
  final String? renewsOn;
  final List<String> features;

  factory _PlanInfo.forTier(_PlanTier tier) => _presets[tier]!;

  static const Map<_PlanTier, _PlanInfo> _presets = {
    _PlanTier.free: _PlanInfo(
      tier: _PlanTier.free,
      label: 'Free',
      icon: Icons.circle_outlined,
      badgeColor: LifeTrackColors.highlight,
      isActive: true,
      priceLabel: '₱0 / month',
      features: [
        'Basic schedule & task tracking',
        'Up to 1 active goal',
        'Community support',
      ],
    ),
    _PlanTier.student: _PlanInfo(
      tier: _PlanTier.student,
      label: 'Student',
      icon: Icons.school_rounded,
      badgeColor: Color(0xFF5B8DEF),
      isActive: true,
      priceLabel: '₱49 / month',
      features: [
        'Everything in Free',
        'Unlimited tasks & goals',
        'Class schedule templates',
        'Study session tracking',
        'Priority email support',
      ],
    ),
    _PlanTier.college: _PlanInfo(
      tier: _PlanTier.college,
      label: 'College',
      icon: Icons.menu_book_rounded,
      badgeColor: Color(0xFF8B5CF6),
      isActive: true,
      priceLabel: '₱79 / month',
      features: [
        'Everything in Student',
        'Semester planning view',
        'Thesis & research tracking',
        'Group project sharing',
        'Exports in PDF',
      ],
    ),
    _PlanTier.personal: _PlanInfo(
      tier: _PlanTier.personal,
      label: 'Personal',
      icon: Icons.person_rounded,
      badgeColor: LifeTrackColors.mint,
      isActive: true,
      priceLabel: '₱99 / month',
      features: [
        'Everything in Free',
        'Unlimited goals & habits',
        'Full money & net-worth tracking',
        'Cloud sync across devices',
        'Weekly insight reports',
      ],
    ),
    _PlanTier.professional: _PlanInfo(
      tier: _PlanTier.professional,
      label: 'Professional',
      icon: Icons.workspace_premium_rounded,
      badgeColor: LifeTrackColors.coral,
      isActive: true,
      priceLabel: '₱199 / month',
      features: [
        'Everything in Personal',
        'Client & project workspaces',
        'Advanced analytics & charts',
        'Multi-currency & invoices',
        'Priority support & early access',
      ],
    ),
  };

  static Map<_PlanTier, _PlanInfo> get allPresets => _presets;
}
