// ============================================================================
// Settings Screen (plan Section 11)
// ----------------------------------------------------------------------------
// REDESIGN NOTES — visual layout only. All logic, icons, and colors are
// unchanged from the original. Changes:
// - Icons now sit in a soft tinted "chip" (same colors as before, just at
//   low opacity as a background) instead of floating bare — gives each row
//   a clearer anchor and more visual weight.
// - Section labels get slightly more letter-spacing and a touch more
//   breathing room above/below.
// - Row height increased slightly and icon/label gap tightened for a more
//   modern, denser-but-legible rhythm.
// - Cards get a subtle shadow instead of relying purely on a flat border,
//   so sections read as distinct surfaces.
// - Destructive row and chevron treatment tightened for consistency.
//
// WIRING NOTES — unchanged from original, still applicable:
//
// SECURITY (Phase 9):
// - App Lock / Biometric toggles are local-only bool state right now.
//   Wire to secure storage (e.g. flutter_secure_storage) + local_auth for
//   the biometric prompt, and gate app launch behind a lock screen in
//   main.dart when App Lock is ON.
// - Auto Lock duration ("5 min") should be a picker writing the chosen
//   duration to the same secure settings store.
//
// APPEARANCE:
// - Dark Mode toggle is local-only bool state right now. Wire it to the
//   ThemeMode passed into MaterialApp in main.dart (see the todo there) —
//   likely via a shared ValueNotifier<ThemeMode> or a state-management
//   provider both main.dart and this screen read/write.
// - Currency ("PHP") is hard-coded everywhere `_peso()` formatting helpers
//   are used across screens. If multi-currency support is ever added,
//   this setting should drive a shared currency-formatting service instead
//   of each screen's local `_peso` helper.
//
// DATA (Phase 9):
// - Export Backup and Import Backup are wired to JSON file storage.
//   Automatic Backup runs a persisted 24-hour in-app backup timer.
//
// CLOUD (Phase 9, optional):
// - Cloud Sync toggle is local-only bool state. Wiring this depends on
//   which backend (if any) is chosen for sync — out of scope until that
//   decision is made.
//
// DESTRUCTIVE:
// - "Delete All Data" already opens a confirmation via LifeTrackDialog.
//   Wire `onConfirm` to actually wipe the SQLite database and reset all
//   in-memory state, then likely restart onto a fresh/empty Home screen.
//
// ABOUT:
// - "About LifeTrack" should open an about dialog/screen with app version,
//   licenses, etc. showAboutDialog() is the quickest built-in option.
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_dialog.dart';
import '../../core/security/security_service.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/app_constants.dart';
import '../../app/theme_mode_controller.dart';
import '../../app/currency_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _automaticBackupKey = 'settings.automatic_backup';
  static const _automaticBackupInterval = Duration(days: 1);

  // ---------------------------------------------------------------------
  // Layout spacing scale — redesigned rhythm. Icons, colors, and
  // typography styles are untouched; this governs gaps, padding, and box
  // rhythm across the screen.
  // ---------------------------------------------------------------------
  static const double _screenHorizontalPadding = 20;
  static const double _screenTopPadding = 24;
  static const double _screenBottomPadding = 40;
  static const double _headerBottomGap = 32;
  static const double _headerIconTitleGap = 14;
  static const double _sectionGap = 24;
  static const double _sectionLabelBottomGap = 10;
  static const double _rowVerticalPadding = 12;
  static const double _rowIconLabelGap = 14;
  static const double _cardContentHorizontalPadding = 8;
  static const double _iconChipSize = 34;
  static const double _cardRadius = 18;

  final _securityService = SecurityService();
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
    _loadSecuritySettings();
    _loadAutomaticBackupSetting();
  }

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
    } catch (_) {
      // Automatic backups should never interrupt the user workflow.
    }
  }

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

  @override
  void dispose() {
    _automaticBackupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          _screenHorizontalPadding,
          _screenTopPadding,
          _screenHorizontalPadding,
          _screenBottomPadding,
        ),
        children: [
          _header(context),
          const SizedBox(height: _headerBottomGap),
          _sectionLabel(context, 'SECURITY'),
          _sectionCard(context, [
            _switchRow(context, Icons.lock_rounded, 'App Lock', _appLock,
                _toggleAppLock),
            _navRow(context, Icons.timer_rounded, 'Auto Lock', _autoLockLabel,
                _pickAutoLock),
            _switchRow(context, Icons.fingerprint_rounded, 'Biometric',
                _biometric, _toggleBiometric),
          ]),
          const SizedBox(height: _sectionGap),
          _sectionLabel(context, 'APPEARANCE'),
          _sectionCard(context, [
            _switchRow(context, Icons.dark_mode_rounded, 'Dark Mode', _darkMode,
                (v) {
              ThemeModeController.mode.value =
                  v ? ThemeMode.dark : ThemeMode.light;
              setState(() {});
            }),
            _navRow(context, Icons.currency_exchange_rounded, 'Currency',
                _currencyCode, _pickCurrency),
          ]),
          const SizedBox(height: _sectionGap),
          _sectionLabel(context, 'DATA'),
          _sectionCard(context, [
            _actionRow(context, Icons.save_alt_rounded, 'Export Backup',
                _exportBackup),
            _actionRow(context, Icons.file_download_rounded, 'Import Backup',
                _importBackup),
            _switchRow(context, Icons.backup_rounded, 'Automatic Backup',
                _automaticBackup, _toggleAutomaticBackup),
          ]),
          const SizedBox(height: _sectionGap),
          _sectionLabel(context, 'CLOUD'),
          _sectionCard(context, [
            _switchRow(context, Icons.cloud_rounded, 'Cloud Sync', _cloudSync,
                (v) => setState(() => _cloudSync = v)),
          ]),
          const SizedBox(height: _sectionGap),
          _sectionCard(context, [
            _destructiveRow(context),
          ]),
          const SizedBox(height: _sectionGap),
          _sectionCard(context, [
            _aboutRow(context),
          ]),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        const SizedBox(width: _headerIconTitleGap),
        Text('Settings', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  // Wraps a section's rows in a single elevated card with a soft shadow,
  // rounded corners, and a thin divider between rows. Uses Card (not a
  // plain Container) so it provides the Material ancestor that Switch
  // and other Material widgets inside the rows require.
  Widget _sectionCard(BuildContext context, List<Widget> rows) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).cardColor,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _cardContentHorizontalPadding,
          vertical: 4,
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  indent: _iconChipSize + _rowIconLabelGap + 8,
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(
            bottom: _sectionLabelBottomGap, left: 8, top: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 0.6,
              ),
        ),
      );

  // Small tinted chip behind a row icon — uses the icon's own color at low
  // opacity as the background, so no new colors are introduced.
  Widget _iconChip(Color color, IconData icon) {
    return Container(
      width: _iconChipSize,
      height: _iconChipSize,
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
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _rowVerticalPadding, horizontal: 8),
      child: Row(
        children: [
          _iconChip(color, icon),
          const SizedBox(width: _rowIconLabelGap),
          Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: LifeTrackColors.highlight),
        ],
      ),
    );
  }

  Widget _navRow(BuildContext context, IconData icon, String label,
      String value, VoidCallback onTap) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: _rowVerticalPadding, horizontal: 8),
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
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: _rowVerticalPadding, horizontal: 8),
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
        padding: const EdgeInsets.symmetric(
            vertical: _rowVerticalPadding, horizontal: 8),
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
      onTap: () {
        showAboutDialog(
          context: context,
          applicationName: 'LifeTrack',
          applicationVersion: '0.3.0',
          applicationLegalese:
              'Personal time, money, goals and skills tracker.',
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: _rowVerticalPadding, horizontal: 8),
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
}
