// ============================================================================
// Account Detail Screen
// ----------------------------------------------------------------------------
// Reached by tapping a wallet on the Money screen. Shows:
//   - Top bar: back, wallet name, notification bell
//   - Balance card: Available Balance with an eye to hide / show it
//   - Actions: Add Balance, Send, Scan (+ Apply Interest when the wallet
//     has an interest rate)
//   - Monthly Spending: expenses of this wallet grouped by week
//   - Recent Transactions of this wallet
//
// EVERY action on this screen only changes THIS wallet:
//   Add Balance -> adds to this wallet
//   Send        -> deducts from this wallet only
//   Scan        -> a receipt / bill deducts from this wallet only;
//                  a deposit slip adds to this wallet only
//
// Add Balance, Send and Scan all present as bottom sheets sharing the same
// frame as _ScanSourceSheet: drag handle, tinted icon-chip header with
// title + subtitle, reassurance banner, section label, hint row, full-width
// action buttons at the bottom.
//
// Add Balance and Send also play a "processing" animation and then show a
// receipt (see _TransactionFlowSheet).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utilities/receipt_parser.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../services/money_service.dart';
import '../../services/notification_center.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/transaction_item.dart';
import '../notifications/notifications_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final Account account;
  final MoneyService moneyService;

  const AccountDetailScreen({
    super.key,
    required this.account,
    required this.moneyService,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  static const int _collapsedTransactionCount = 4;
  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late Account _account;
  late Future<List<Transaction>> _transactionsFuture;
  bool _busy = false;
  bool _hideBalance = false;
  bool _showAllTransactions = false;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _reloadTransactions();
  }

  void _reloadTransactions() {
    _transactionsFuture =
        widget.moneyService.getTransactionsForAccount(_account.id!);
  }

  Future<void> _refreshAccount() async {
    // MoneyService doesn't expose getAccountById directly in this codebase's
    // known shape — re-pull from getAccounts() and find by id as a safe
    // fallback. Swap for a direct lookup if one exists on your service.
    final accounts = await widget.moneyService.getAccounts();
    final refreshed = accounts.where((a) => a.id == _account.id);
    if (refreshed.isNotEmpty && mounted) {
      setState(() {
        _account = refreshed.first;
        _reloadTransactions();
      });
    } else if (mounted) {
      setState(_reloadTransactions);
    }
  }

  // ---------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------

  String _dbDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _maskable(String value) =>
      _hideBalance ? '\u2022\u2022\u2022\u2022\u2022\u2022' : value;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Saves one transaction on THIS wallet and refreshes the screen.
  /// (Still used by the Scan flow.)
  Future<void> _record(
    Transaction transaction, {
    required String success,
    required String failure,
  }) async {
    setState(() => _busy = true);
    try {
      await widget.moneyService.recordTransaction(transaction);
      if (mounted) {
        await _refreshAccount();
        _snack(success);
      }
    } catch (_) {
      _snack(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stamp(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '${_monthNames[d.month - 1]} ${d.day}, ${d.year} \u2022 $h12:$mm $ap';
  }

  // Display-only reference shown on the receipt (not stored).
  String _reference(DateTime d) =>
      'LT-${d.millisecondsSinceEpoch.toString().substring(4, 13)}';

  /// Rounded, tinted field that matches the cards in the Scan sheet.
  InputDecoration _fieldDecoration(String label, {bool money = false}) {
    final s = context.season;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      prefixText: money ? ' ' : null,
      filled: true,
      fillColor: s.accent.withValues(alpha: 0.08),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(s.accent, 1.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  /// Runs [task] behind the processing animation, then shows the receipt
  /// built by [buildReceipt] (called after the task, so it can read the
  /// refreshed balance). If [task] throws, the sheet closes and [failure]
  /// is shown as a snackbar — same messages as before.
  Future<void> _showFlow({
    required _FlowKind kind,
    required Future<void> Function() task,
    required _ReceiptData Function() buildReceipt,
    required String failure,
  }) async {
    setState(() => _busy = true);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _TransactionFlowSheet(
        kind: kind,
        task: task,
        buildReceipt: buildReceipt,
      ),
    );
    if (mounted) setState(() => _busy = false);
    if (ok == false) _snack(failure);
  }

  // ---------------------------------------------------------------------
  // Shared bottom-sheet frame — mirrors _ScanSourceSheet exactly:
  // drag handle, icon-chip header, reassurance banner, section label,
  // hint row, full-width actions at the bottom.
  // ---------------------------------------------------------------------

  Widget _actionSheet({
    required IconData headerIcon,
    required String title,
    required String subtitle,
    required String reassurance,
    required String sectionLabel,
    required Widget body,
    Widget? hint,
    required String primaryLabel,
    required VoidCallback onPrimary,
    required String secondaryLabel,
    required VoidCallback onSecondary,
  }) {
    final theme = Theme.of(context);
    final s = context.season;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Header (identical to _ScanSourceSheet) ----------
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
                    child: Icon(headerIcon, size: 24, color: s.accentText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ---------- Reassurance banner ----------
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 20, color: s.accentText),
                    const SizedBox(width: 10),
                    Expanded(
                      child:
                          Text(reassurance, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---------- Section label ----------
              Text(sectionLabel, style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),

              // ---------- The actual form ----------
              body,

              // ---------- Hint row (same as the Scan sheet) ----------
              if (hint != null) ...[
                const SizedBox(height: 14),
                hint,
              ],

              const SizedBox(height: 20),

              // ---------- Full-width stacked actions ----------
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Add balance
  // ---------------------------------------------------------------------

  Future<void> _addBalance() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? error;

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _actionSheet(
          headerIcon: Icons.add_card_rounded,
          title: 'Add balance',
          subtitle: 'To ${_account.name} \u2022 ${_account.type}',
          reassurance:
              'Only ${_account.name} will be credited. Nothing is saved until you tap Add.',
          sectionLabel: 'AMOUNT & NOTE',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDecoration('Amount', money: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: _fieldDecoration('Note (optional)'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          hint: _ScanHintRow(
            icon: Icons.south_west_rounded,
            title: _account.name,
            subtitle: 'Credited with the amount you enter',
            result: 'Adds',
            resultColor: LifeTrackColors.mint,
          ),
          primaryLabel: 'Add',
          onPrimary: () {
            final amount = double.tryParse(amountController.text.trim());
            if (amount == null || amount <= 0) {
              setSheetState(() => error = 'Enter a valid amount.');
              return;
            }
            Navigator.pop(sheetContext, amount);
          },
          secondaryLabel: 'Cancel',
          onSecondary: () => Navigator.pop(sheetContext),
        ),
      ),
    );

    final note = noteController.text.trim();
    amountController.dispose();
    noteController.dispose();

    if (result == null || !mounted) return;

    final account = _account;
    final now = DateTime.now();

    await _showFlow(
      kind: _FlowKind.add,
      failure: 'Unable to add balance.',
      // Same service call as before.
      task: () async {
        await widget.moneyService
            .addBalance(account, result, note: note.isEmpty ? null : note);
        if (mounted) await _refreshAccount();
      },
      buildReceipt: () => _ReceiptData(
        title: 'Balance added',
        subtitle: 'Your wallet has been credited',
        amountText: '+${_peso(result)}',
        isCredit: true,
        rows: [
          ('Reference no.', _reference(now)),
          ('Date', _stamp(now)),
          ('To wallet', '${account.name} \u2022 ${account.type}'),
          if (note.isNotEmpty) ('Note', note),
          ('New balance', _peso(_account.balance)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Send (deducts from THIS wallet only)
  // ---------------------------------------------------------------------

  Future<void> _sendMoney() async {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? error;

    final request = await showModalBottomSheet<_SendRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _actionSheet(
          headerIcon: Icons.north_east_rounded,
          title: 'Send money',
          subtitle: 'From ${_account.name} \u2022 ${_account.type}',
          reassurance:
              'Only ${_account.name} will be debited. Available: ${_peso(_account.balance)}.',
          sectionLabel: 'RECIPIENT & AMOUNT',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: recipientController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration('Send to (name)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDecoration('Amount', money: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: _fieldDecoration('Note (optional)'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          hint: _ScanHintRow(
            icon: Icons.north_east_rounded,
            title: _account.name,
            subtitle: 'Debited with the amount you send',
            result: 'Deducts',
            resultColor: LifeTrackColors.coral,
          ),
          primaryLabel: 'Send',
          onPrimary: () {
            final recipient = recipientController.text.trim();
            final amount = double.tryParse(amountController.text.trim());
            if (recipient.isEmpty) {
              setSheetState(() => error = 'Enter who you are sending to.');
              return;
            }
            if (amount == null || amount <= 0) {
              setSheetState(() => error = 'Enter a valid amount.');
              return;
            }
            if (CurrencyController.toPhp(amount) > _account.balance) {
              setSheetState(() => error = 'Not enough balance in this wallet.');
              return;
            }
            Navigator.pop(
              sheetContext,
              _SendRequest(
                recipient: recipient,
                amount: amount,
                note: noteController.text.trim(),
              ),
            );
          },
          secondaryLabel: 'Cancel',
          onSecondary: () => Navigator.pop(sheetContext),
        ),
      ),
    );

    recipientController.dispose();
    amountController.dispose();
    noteController.dispose();

    if (request == null || !mounted) return;

    final account = _account;
    final now = DateTime.now();
    final php = CurrencyController.toPhp(request.amount);
    final note = request.note.isEmpty
        ? 'Sent to ${request.recipient}'
        : 'Sent to ${request.recipient} - ${request.note}';

    await _showFlow(
      kind: _FlowKind.send,
      failure: 'Unable to send.',
      // Same transaction as before: only THIS wallet is charged.
      task: () async {
        await widget.moneyService.recordTransaction(
          Transaction(
            accountId: account.id!,
            type: TransactionType.expense,
            amount: php,
            category: 'Transfer',
            note: note,
            date: _dbDate(now),
          ),
        );
        if (mounted) await _refreshAccount();
      },
      buildReceipt: () => _ReceiptData(
        title: 'Money sent',
        subtitle: 'Your transfer was successful',
        amountText: '-${_peso(php)}',
        isCredit: false,
        rows: [
          ('Reference no.', _reference(now)),
          ('Date', _stamp(now)),
          ('From wallet', '${account.name}'),
          ('Sent to', request.recipient),
          if (request.note.isNotEmpty) ('Note', request.note),
          ('New balance', _peso(_account.balance)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Scan a bill / receipt / deposit slip (changes THIS wallet only)
  // ---------------------------------------------------------------------

  Future<void> _scanReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _ScanSourceSheet(
        walletName: _account.name,
        walletType: _account.type,
        icon: _accountIcon(_account.type),
      ),
    );
    if (source == null) return;

    setState(() => _busy = true);
    ReceiptScan? scan;
    try {
      final picked =
          await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (picked == null) return;

      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognized =
            await recognizer.processImage(InputImage.fromFilePath(picked.path));
        scan = ReceiptParser.parse(recognized.text);
      } finally {
        await recognizer.close();
      }
    } catch (_) {
      _snack('Unable to read that image. Try a clearer photo.');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    if (scan.rawText.trim().isEmpty) {
      _snack('No text found. Try a clearer, well-lit photo.');
      return;
    }
    await _reviewScan(scan);
  }

  // The scan is only a guess, so the user checks and edits it first.
  Future<void> _reviewScan(ReceiptScan scan) async {
    final amountController = TextEditingController(
      text: scan.amount == null ? '' : scan.amount!.toStringAsFixed(2),
    );
    final categoryController = TextEditingController(text: scan.category);
    final noteController = TextEditingController(text: scan.merchant);
    var kind = scan.kind;
    var date = scan.date;
    String? error;

    final entry = await showDialog<_ScanEntry>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Check scanned details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.amount == null
                      ? 'We could not find the amount. Please enter it.'
                      : 'Please check these details. This only changes ${_account.name}.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<ScanKind>(
                  segments: const [
                    ButtonSegment(
                      value: ScanKind.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.trending_down_rounded),
                    ),
                    ButtonSegment(
                      value: ScanKind.deposit,
                      label: Text('Deposit'),
                      icon: Icon(Icons.trending_up_rounded),
                    ),
                  ],
                  selected: {kind},
                  onSelectionChanged: (selected) =>
                      setDialogState(() => kind = selected.first),
                ),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: ' '),
                ),
                TextField(
                  controller: categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                      labelText: 'Store / note (optional)'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: date,
                    );
                    if (selected != null) {
                      setDialogState(() => date = selected);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dbDate(date)),
                ),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                final category = categoryController.text.trim();
                if (amount == null || amount <= 0) {
                  setDialogState(() => error = 'Enter a valid amount.');
                  return;
                }
                if (category.isEmpty) {
                  setDialogState(() => error = 'Enter a category.');
                  return;
                }
                if (kind == ScanKind.expense &&
                    CurrencyController.toPhp(amount) > _account.balance) {
                  setDialogState(
                      () => error = 'Not enough balance in this wallet.');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _ScanEntry(
                    kind: kind,
                    amount: amount,
                    category: category,
                    note: noteController.text.trim(),
                    date: date,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    categoryController.dispose();
    noteController.dispose();

    if (entry == null) return;

    final isDeposit = entry.kind == ScanKind.deposit;
    await _record(
      Transaction(
        accountId: _account.id!, // only THIS wallet changes
        type: isDeposit ? TransactionType.income : TransactionType.expense,
        amount: CurrencyController.toPhp(entry.amount),
        category: entry.category,
        note: entry.note.isEmpty ? null : entry.note,
        date: _dbDate(entry.date),
      ),
      success: isDeposit
          ? 'Deposit added to ${_account.name}.'
          : 'Expense saved from ${_account.name}.',
      failure: 'Unable to save the scanned receipt.',
    );
  }

  // ---------------------------------------------------------------------
  // Interest
  // ---------------------------------------------------------------------

  Future<void> _applyInterest() async {
    final estimated = _account.balance * (_account.interestRate / 100);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply interest'),
        content: Text(
          'This will add ${_peso(estimated)} to ${_account.name} '
          '(${_account.interestRate}% of ${_peso(_account.balance)}).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply')),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.moneyService.applyInterest(_account);
      if (mounted) await _refreshAccount();
    } catch (_) {
      _snack('Unable to apply interest.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    NotificationCenter.instance.refreshUnread();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          children: [
            _header(context),
            const SizedBox(height: 12),
            _brandChip(context),
            const SizedBox(height: 12),
            _balanceCard(context),
            const SizedBox(height: 16),
            _actionRow(context),
            if (_account.interestRate > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _applyInterest,
                  icon: const Icon(Icons.percent_rounded),
                  label: Text(
                    'Apply interest (~${_maskable(_peso(_account.balance * _account.interestRate / 100))})',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FutureBuilder<List<Transaction>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Unable to load transactions.'));
                }
                final transactions = snapshot.data ?? const <Transaction>[];
                return Column(
                  children: [
                    _monthlySpendingCard(context, transactions),
                    const SizedBox(height: 16),
                    _recentTransactionsCard(context, transactions),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header, brand chip, balance card, actions
  // ---------------------------------------------------------------------

  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(
            _account.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: NotificationCenter.instance.unreadCount,
          builder: (context, unread, _) {
            return IconButton(
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                backgroundColor: LifeTrackColors.coral,
                textColor: Colors.white,
                child: const Icon(Icons.notifications_outlined),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _brandChip(BuildContext context) {
    final s = context.season;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: s.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'LIFETRACK \u2022 ${_account.type.toUpperCase()}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: s.accentText,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  // Friendly hero card: wallet type, eye toggle, big balance, quick facts.
  Widget _balanceCard(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);
    final addedOn = DateTime.tryParse(_account.createdAt);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [s.accent, s.accentDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: s.accent.withValues(alpha: 0.3),
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
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s.onAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_accountIcon(_account.type),
                              size: 20, color: s.onAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _account.type,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: s.onAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip:
                              _hideBalance ? 'Show balance' : 'Hide balance',
                          onPressed: () =>
                              setState(() => _hideBalance = !_hideBalance),
                          icon: Icon(
                            _hideBalance
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: s.onAccent.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Balance',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: s.onAccent.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _maskable(_peso(_account.balance)),
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: s.onAccent,
                                fontSize: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _infoChip(
                                context,
                                Icons.event_outlined,
                                addedOn == null
                                    ? 'Wallet added'
                                    : 'Added ${_monthNames[addedOn.month - 1]} ${addedOn.day}, ${addedOn.year}',
                              ),
                              if (_account.interestRate > 0) ...[
                                _infoChip(
                                  context,
                                  Icons.trending_up_rounded,
                                  '${_account.interestRate}% APY',
                                ),
                                _infoChip(
                                  context,
                                  Icons.savings_outlined,
                                  '~${_maskable(_peso(_account.balance * _account.interestRate / 100))} / year',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _infoChip(BuildContext context, IconData icon, String label) {
    final s = context.season;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: s.onAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: s.onAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: s.onAccent,
                  fontSize: 12,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_card_rounded,
            label: 'Add Balance',
            filled: true,
            onPressed: _busy ? null : _addBalance,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.north_east_rounded,
            label: 'Send',
            filled: false,
            onPressed: _busy ? null : _sendMoney,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.document_scanner_outlined,
            label: 'Scan',
            filled: false,
            onPressed: _busy ? null : _scanReceipt,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Monthly Spending
  // ---------------------------------------------------------------------

  List<DateTime> _monthChoices() {
    final now = DateTime.now();
    return List.generate(
      12,
      (i) => DateTime(now.year, now.month - i),
    );
  }

  String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

  /// Expenses of the selected month, grouped into 7-day buckets.
  ({double total, List<({String label, double amount})> weeks}) _weeklySpending(
      List<Transaction> all) {
    final prefix =
        '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final bucketCount = (daysInMonth / 7).ceil();
    final amounts = List<double>.filled(bucketCount, 0);

    for (final t in all) {
      if (t.type != TransactionType.expense) continue;
      if (!t.date.startsWith(prefix)) continue;
      final day =
          int.tryParse(t.date.length >= 10 ? t.date.substring(8, 10) : '');
      if (day == null || day < 1) continue;
      final index = ((day - 1) ~/ 7).clamp(0, bucketCount - 1);
      amounts[index] += t.amount;
    }

    final monthName = _monthNames[_selectedMonth.month - 1];
    return (
      total: amounts.fold<double>(0, (sum, a) => sum + a),
      weeks: [
        for (var i = 0; i < bucketCount; i++)
          (label: '$monthName ${i * 7 + 1}', amount: amounts[i]),
      ],
    );
  }

  Widget _monthlySpendingCard(
      BuildContext context, List<Transaction> transactions) {
    final theme = Theme.of(context);
    final s = context.season;
    final spending = _weeklySpending(transactions);
    final maxAmount =
        spending.weeks.fold<double>(0, (m, w) => w.amount > m ? w.amount : m);
    const barAreaHeight = 110.0;

    return LifeTrackCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('Monthly Spending', style: theme.textTheme.titleLarge),
              ),
              PopupMenuButton<DateTime>(
                tooltip: 'Choose month',
                onSelected: (month) => setState(() => _selectedMonth = month),
                itemBuilder: (context) => [
                  for (final month in _monthChoices())
                    PopupMenuItem<DateTime>(
                      value: month,
                      child: Text(_monthLabel(month)),
                    ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_monthLabel(_selectedMonth),
                        style: theme.textTheme.labelLarge),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Total spent this month: ${_peso(spending.total)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: s.accentText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: barAreaHeight + 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final week in spending.weeks)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: _peso(week.amount),
                            triggerMode: TooltipTriggerMode.tap,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              height: maxAmount == 0
                                  ? 6
                                  : 6 +
                                      (week.amount / maxAmount) *
                                          (barAreaHeight - 6),
                              decoration: BoxDecoration(
                                color: week.amount == 0
                                    ? s.accent.withValues(alpha: 0.25)
                                    : s.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(week.label,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (spending.total == 0) ...[
            const SizedBox(height: 8),
            Text('No spending recorded this month.',
                style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Recent Transactions
  // ---------------------------------------------------------------------

  Widget _recentTransactionsCard(
      BuildContext context, List<Transaction> transactions) {
    final theme = Theme.of(context);
    final s = context.season;
    final canExpand = transactions.length > _collapsedTransactionCount;
    final visible = _showAllTransactions || !canExpand
        ? transactions
        : transactions.take(_collapsedTransactionCount).toList();

    return LifeTrackCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Recent Transactions',
                    style: theme.textTheme.titleLarge),
              ),
              if (canExpand)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(
                      () => _showAllTransactions = !_showAllTransactions),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showAllTransactions ? 'Show less' : 'See all',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: s.accentText),
                        ),
                        Icon(
                          _showAllTransactions
                              ? Icons.expand_less_rounded
                              : Icons.chevron_right_rounded,
                          size: 20,
                          color: s.accentText,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No transactions on this wallet yet.',
                  style: theme.textTheme.bodyMedium),
            )
          else
            Column(
              children: visible
                  .map((t) => TransactionItem(
                        entry: t,
                        formatCurrency: _peso,
                        onDelete: () async {
                          await widget.moneyService.deleteTransaction(t);
                          if (mounted) await _refreshAccount();
                        },
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  IconData _accountIcon(String type) => switch (type.toLowerCase()) {
        'cash' => Icons.payments_rounded,
        'gcash' => Icons.phone_android_rounded,
        'bank' => Icons.account_balance_rounded,
        'paypal' => Icons.account_balance_wallet_rounded,
        _ => Icons.wallet_rounded,
      };

  String _peso(double value) => CurrencyController.format(value);
}

// Values collected by the Send dialog.
class _SendRequest {
  const _SendRequest({
    required this.recipient,
    required this.amount,
    required this.note,
  });
  final String recipient;
  final double amount;
  final String note;
}

// Values collected by the "Check scanned details" dialog.
class _ScanEntry {
  const _ScanEntry({
    required this.kind,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
  });
  final ScanKind kind;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
}

// ============================================================================
// "Scan a bill or receipt" sheet: wallet header, safety note, two big source
// cards (camera / gallery) and a short guide to what can be read.
// ============================================================================

class _ScanSourceSheet extends StatelessWidget {
  const _ScanSourceSheet({
    required this.walletName,
    required this.walletType,
    required this.icon,
  });

  final String walletName;
  final String walletType;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: which wallet this scan is for.
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
                  child: Icon(icon, size: 24, color: s.accentText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scan a bill or receipt',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text('For $walletName \u2022 $walletType',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Reassurance: only this wallet changes, and the user confirms.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 20, color: s.accentText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only $walletName will change. Nothing is saved until you check the details.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Two big source cards.
            Row(
              children: [
                Expanded(
                  child: _ScanSourceCard(
                    icon: Icons.photo_camera_rounded,
                    title: 'Take photo',
                    subtitle: 'Use the camera',
                    filled: true,
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScanSourceCard(
                    icon: Icons.photo_library_rounded,
                    title: 'Gallery',
                    subtitle: 'Pick a saved photo',
                    filled: false,
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // What the scanner understands.
            Text('WHAT WE CAN READ', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            const _ScanHintRow(
              icon: Icons.receipt_long_rounded,
              title: 'Receipts & bills',
              subtitle: 'Store receipts, utility and online bills',
              result: 'Deducts',
              resultColor: LifeTrackColors.coral,
            ),
            const SizedBox(height: 8),
            const _ScanHintRow(
              icon: Icons.south_west_rounded,
              title: 'Deposit slips',
              subtitle: 'Cash-in and deposit confirmations',
              result: 'Adds',
              resultColor: LifeTrackColors.mint,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: theme.textTheme.bodyMedium?.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: lay it flat, use good light and keep the whole total in view.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanSourceCard extends StatelessWidget {
  const _ScanSourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final foreground = filled ? s.onAccent : s.accentText;
    final radius = BorderRadius.circular(20);

    return Material(
      color: filled ? s.accent : s.accent.withValues(alpha: 0.12),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30, color: foreground),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanHintRow extends StatelessWidget {
  const _ScanHintRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.result,
    required this.resultColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String result;
  final Color resultColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: resultColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              result,
              style: theme.textTheme.labelSmall?.copyWith(
                color: resultColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Big icon-over-label action button (filled or outlined).
// ============================================================================

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final foreground = filled ? s.onAccent : s.accentText;
    final radius = BorderRadius.circular(18);

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: filled ? s.accent : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Container(
            height: 78,
            decoration: BoxDecoration(
              borderRadius: radius,
              border:
                  filled ? null : Border.all(color: s.accentText, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: foreground),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
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
// NEW: processing animation -> animated check -> receipt
// Used by Add Balance and Send. Pops `true` on Done, `false` if the task
// threw (the caller then shows its usual failure snackbar).
// ============================================================================

enum _FlowKind { add, send }

class _ReceiptData {
  const _ReceiptData({
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.isCredit,
    required this.rows,
  });
  final String title;
  final String subtitle;
  final String amountText;
  final bool isCredit;
  final List<(String, String)> rows;
}

class _TransactionFlowSheet extends StatefulWidget {
  const _TransactionFlowSheet({
    required this.kind,
    required this.task,
    required this.buildReceipt,
  });

  final _FlowKind kind;
  final Future<void> Function() task;
  final _ReceiptData Function() buildReceipt;

  @override
  State<_TransactionFlowSheet> createState() => _TransactionFlowSheetState();
}

class _TransactionFlowSheetState extends State<_TransactionFlowSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  _ReceiptData? _receipt;
  bool _copied = false;

  bool get _isSend => widget.kind == _FlowKind.send;
  bool get _done => _receipt != null;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
    // Keep the animation visible long enough to be seen.
    const minimum = Duration(milliseconds: 1800);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) await Future.delayed(minimum - elapsed);
    if (!mounted) return;
    if (!ok) {
      Navigator.pop(context, false);
      return;
    }
    _loop.stop();
    setState(() => _receipt = widget.buildReceipt());
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Future<void> _copy(_ReceiptData r) async {
    final text = StringBuffer()
      ..writeln('LifeTrack \u2022 ${r.title}')
      ..writeln(r.amountText);
    for (final row in r.rows) {
      text.writeln('${row.$1}: ${row.$2}');
    }
    await Clipboard.setData(ClipboardData(text: text.toString().trim()));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final r = _receipt;
    return PopScope(
      canPop: _done,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            child: r == null ? _processing(context) : _receiptView(context, r),
          ),
        ),
      ),
    );
  }

  Widget _processing(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Column(
      key: const ValueKey('processing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: s.accent,
                  backgroundColor: s.accent.withValues(alpha: 0.15),
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: AnimatedBuilder(
                    animation: _loop,
                    builder: (context, _) {
                      // u: -1 -> 1 across one loop; icon fades at both ends.
                      final u = _loop.value * 2 - 1;
                      final opacity = (1 - u * u).clamp(0.0, 1.0);
                      final dx = _isSend ? u * 28 : 0.0;
                      final dy = _isSend ? -u * 28 : u * 28;
                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Opacity(
                          opacity: opacity,
                          child: Icon(
                            _isSend
                                ? Icons.north_east_rounded
                                : Icons.arrow_downward_rounded,
                            size: 40,
                            color: s.accentText,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isSend ? 'Sending money\u2026' : 'Adding balance\u2026',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Please wait, this only takes a moment.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _receiptView(BuildContext context, _ReceiptData r) {
    final theme = Theme.of(context);
    final s = context.season;
    final amountColor =
        r.isCredit ? LifeTrackColors.mint : LifeTrackColors.coral;

    return Column(
      key: const ValueKey('receipt'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: s.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 44, color: s.onAccent),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(r.title,
            textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(r.subtitle,
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 18),

        // Receipt card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text('AMOUNT', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  r.amountText,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: amountColor,
                    fontSize: 36,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Divider(color: theme.dividerColor, height: 1),
              const SizedBox(height: 10),
              for (final row in r.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.$1, style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          row.$2,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Done'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _copy(r),
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 18),
          label: Text(_copied ? 'Copied' : 'Copy receipt'),
        ),
      ],
    );
  }
}
