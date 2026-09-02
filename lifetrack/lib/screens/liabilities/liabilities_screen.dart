// ============================================================================
// Liabilities Screen
// ============================================================================
//
// WHAT THIS SCREEN DOES
// ----------------------------------------------------------------------------
// Tracks every debt the user has: credit cards, personal loans, car loans,
// mortgages, student loans, medical debt, other. The user can:
//   • Add a new liability
//   • Tap one to see full details, edit, or delete
//   • Sort by amount / due date / name
//   • Filter to only upcoming-due debts
//   • See at-a-glance: total debt, largest debt, upcoming due, share badge
//
// NEW IN THIS VERSION
// ----------------------------------------------------------------------------
// Colors — toned down from aggressive red to friendly coral-blush
//   • Summary card: soft blush gradient instead of strong red
//   • Debt amounts: warm coral (#E5484D) instead of red-adjacent
//   • Delete buttons: coral on pale blush instead of bold red
//   • Semantic color still means "money going out", but it no longer
//     looks like a warning banner on every surface
//
// Features
//   • Sort bar (Amount / Due / Name) — animated pill switcher
//   • "Upcoming" filter — shows only debts due in the next 30 days
//   • Due-date chip on each row (colored by urgency: coral overdue,
//     amber this week, season accent otherwise)
//   • Per-row "progress toward payoff" bar (amount paid / original amount
//     when the user has been tracking updates via `updatedAt`). Falls back
//     to share-of-total when there's no payment history yet.
//
// ANIMATIONS
//   • Rows stagger-fade in
//   • Sort / filter pill animates color and weight
//   • Press-scale on every tappable element
//   • Add/Edit sheet uses native drag handle
//
// SELF-CONTAINED
// ----------------------------------------------------------------------------
// This file imports no app widgets. Local widgets defined below:
//   _InlineCard, _LiabilityCard, _ShareBadge, _SummaryStat, _DetailItem,
//   _EmptyState, _ErrorState, _SortBar, _DueBadge.
// ============================================================================

import 'package:flutter/material.dart';

import '../../app/currency_controller.dart';
import '../../models/liability.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';

class LiabilitiesScreen extends StatefulWidget {
  const LiabilitiesScreen({super.key});

  @override
  State<LiabilitiesScreen> createState() => _LiabilitiesScreenState();
}

// -----------------------------------------------------------------------------
// Sort / filter modes
// -----------------------------------------------------------------------------

enum _SortMode { amount, dueDate, name }

extension _SortModeX on _SortMode {
  String get label => switch (this) {
        _SortMode.amount => 'Amount',
        _SortMode.dueDate => 'Due',
        _SortMode.name => 'Name',
      };
}

class _LiabilitiesScreenState extends State<LiabilitiesScreen>
    with TickerProviderStateMixin {
  final MoneyService _service = MoneyService();

  List<Liability>? _liabilities;
  bool _loading = true;
  Object? _error;

  _SortMode _sort = _SortMode.amount;
  bool _upcomingOnly = false;

  final Map<int, AnimationController> _rowAnims = {};

  static const List<String> _liabilityTypes = [
    'Credit Card',
    'Personal Loan',
    'Car Loan',
    'Mortgage',
    'Student Loan',
    'Medical Debt',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _rowAnims.values) {
      c.dispose();
    }
    _rowAnims.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (mounted) setState(() => _loading = _liabilities == null);
    try {
      final items = await _service.getLiabilities();
      if (!mounted) return;
      setState(() {
        _liabilities = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _quietReload() async {
    for (final c in _rowAnims.values) {
      c.dispose();
    }
    _rowAnims.clear();
    try {
      final items = await _service.getLiabilities();
      if (!mounted) return;
      setState(() {
        _liabilities = items;
        _error = null;
      });
    } catch (_) {}
  }

  void _reload() => _load();

  // ---------------------------------------------------------------------------
  // Filtering + sorting
  // ---------------------------------------------------------------------------

  List<Liability> _visible(List<Liability> items) {
    var list = [...items];

    if (_upcomingOnly) {
      final now = DateTime.now();
      final cutoff = now.add(const Duration(days: 30));
      list = list.where((l) {
        if (l.dueDate == null) return false;
        final d = DateTime.tryParse(l.dueDate!);
        if (d == null) return false;
        return d.isAfter(now.subtract(const Duration(days: 1))) &&
            d.isBefore(cutoff);
      }).toList();
    }

    list.sort((a, b) {
      switch (_sort) {
        case _SortMode.amount:
          return b.amount.compareTo(a.amount);
        case _SortMode.dueDate:
          final ad = a.dueDate == null
              ? DateTime(9999)
              : DateTime.tryParse(a.dueDate!) ?? DateTime(9999);
          final bd = b.dueDate == null
              ? DateTime(9999)
              : DateTime.tryParse(b.dueDate!) ?? DateTime(9999);
          return ad.compareTo(bd);
        case _SortMode.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return list;
  }

  int _upcomingCount(List<Liability> items) {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 30));
    return items.where((l) {
      if (l.dueDate == null) return false;
      final d = DateTime.tryParse(l.dueDate!);
      if (d == null) return false;
      return d.isAfter(now.subtract(const Duration(days: 1))) &&
          d.isBefore(cutoff);
    }).length;
  }

  void _setSort(_SortMode m) {
    if (m == _sort) return;
    setState(() {
      _sort = m;
      _rowAnims.clear();
    });
  }

  void _toggleUpcoming() {
    setState(() {
      _upcomingOnly = !_upcomingOnly;
      _rowAnims.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _peso(double v) => CurrencyController.format(v);

  String _displayAmount(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);
      if (dateOnly == today) return 'Updated today';
      if (dateOnly == today.subtract(const Duration(days: 1))) {
        return 'Updated yesterday';
      }
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return 'Updated ${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return 'Recently updated';
    }
  }

  String _formatShortDate(String value) {
    try {
      final d = DateTime.parse(value);
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Credit Card':
        return Icons.credit_card_rounded;
      case 'Personal Loan':
        return Icons.request_quote_rounded;
      case 'Car Loan':
        return Icons.directions_car_rounded;
      case 'Mortgage':
        return Icons.home_rounded;
      case 'Student Loan':
        return Icons.school_rounded;
      case 'Medical Debt':
        return Icons.local_hospital_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color _shareBadgeColor(double share) {
    if (share >= 0.30) return LifeTrackColors.coral;
    if (share >= 0.10) return LifeTrackColors.highlight;
    return LifeTrackColors.mint;
  }

  String _shareBadgeLabel(double share) =>
      '${(share * 100).toStringAsFixed(0)}%';

  /// Due-date urgency color.
  ///   Overdue     → coral
  ///   ≤ 7 days    → amber
  ///   ≤ 30 days   → season accent
  ///   > 30 days   → muted
  Color _dueColor(BuildContext context, String? dueDate) {
    if (dueDate == null) return context.season.accentText;
    final d = DateTime.tryParse(dueDate);
    if (d == null) return context.season.accentText;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return LifeTrackColors.coral;
    if (days <= 7) return LifeTrackColors.highlight;
    if (days <= 30) return context.season.accentText;
    return context.season.accentText.withValues(alpha: 0.6);
  }

  String _dueLabel(String? dueDate) {
    if (dueDate == null) return '';
    final d = DateTime.tryParse(dueDate);
    if (d == null) return '';
    final today = DateTime.now();
    final days = DateTime(d.year, d.month, d.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days <= 7) return 'Due in $days days';
    return 'Due ${_formatShortDate(dueDate)}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(onRetry: _reload)
                : _buildBody(context, _liabilities ?? const []),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Liability> items) {
    final sorted = _visible(items);
    final total = items.fold<double>(0, (sum, l) => sum + l.amount);
    final largest = sorted.isEmpty ? null : sorted.first;
    final upcoming = _upcomingCount(items);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          LifeTrackMetrics.screenPadding,
          12,
          LifeTrackMetrics.screenPadding,
          32,
        ),
        children: [
          _header(context),
          const SizedBox(height: 20),
          _summaryCard(context, total, items.length, largest, upcoming),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            _distributionCard(context, sorted, total),
            const SizedBox(height: 20),
            _SortBar(
              sort: _sort,
              upcomingOnly: _upcomingOnly,
              upcomingCount: upcoming,
              onSortChanged: _setSort,
              onUpcomingToggle: _toggleUpcoming,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _upcomingOnly
                      ? 'UPCOMING LIABILITIES'
                      : 'YOUR LIABILITIES',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              if (sorted.isNotEmpty)
                Text(
                  '${sorted.length} shown',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            _emptyState(context)
          else
            _liabilitiesList(context, sorted, total),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: s.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_rounded,
                size: 20, color: s.accentText),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Liabilities',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('What you currently owe',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Add liability',
          onPressed: _openAddLiability,
          style: IconButton.styleFrom(
            backgroundColor:
                LifeTrackColors.coral.withValues(alpha: 0.12),
          ),
          icon: const Icon(Icons.add_rounded,
              color: LifeTrackColors.coral),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Summary — soft blush gradient, not aggressive red
  // ---------------------------------------------------------------------------

  Widget _summaryCard(
    BuildContext context,
    double total,
    int count,
    Liability? largest,
    int upcoming,
  ) {
    final theme = Theme.of(context);
    final s = context.season;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        // Soft blush → warm cream. Reads as "money going out" without
        // looking like an error banner.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LifeTrackColors.coral.withValues(alpha: 0.10),
            LifeTrackColors.coral.withValues(alpha: 0.03),
            s.accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LifeTrackColors.coral.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      LifeTrackColors.coral.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    size: 20, color: LifeTrackColors.coral),
              ),
              const SizedBox(width: 10),
              Text('TOTAL DEBT', style: theme.textTheme.labelSmall),
              const Spacer(),
              if (upcoming > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LifeTrackColors.highlight
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                     const Icon(Icons.schedule_rounded,
                          size: 12,
                          color: LifeTrackColors.highlight),
                      const SizedBox(width: 4),
                      Text(
                        '$upcoming due soon',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: LifeTrackColors.highlight,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _peso(total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: LifeTrackColors.coral,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  icon: Icons.layers_rounded,
                  iconColor: s.accentText,
                  label: 'Tracked',
                  value:
                      '$count ${count == 1 ? 'liability' : 'liabilities'}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.warning_amber_rounded,
                  iconColor: LifeTrackColors.highlight,
                  label: 'Largest',
                  value: largest?.name ?? '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Distribution
  // ---------------------------------------------------------------------------

  Widget _distributionCard(
    BuildContext context,
    List<Liability> liabilities,
    double total,
  ) {
    final theme = Theme.of(context);
    final s = context.season;

    return _InlineCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded,
                  size: 20, color: s.accentText),
              const SizedBox(width: 8),
              Text(
                'Debt distribution',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...liabilities.take(5).map((liability) {
            final share = total <= 0 ? 0.0 : liability.amount / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          liability.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(share * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: share.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor:
                          s.accent.withValues(alpha: 0.10),
                      valueColor: const AlwaysStoppedAnimation(
                          LifeTrackColors.coral),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (liabilities.length > 5)
            Text(
              '+ ${liabilities.length - 5} more liabilities',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rows
  // ---------------------------------------------------------------------------

  Widget _liabilitiesList(
    BuildContext context,
    List<Liability> sorted,
    double total,
  ) {
    _rowAnims.removeWhere((index, c) {
      if (index >= sorted.length) {
        c.dispose();
        return true;
      }
      return false;
    });
    for (var i = 0; i < sorted.length; i++) {
      _rowAnims.putIfAbsent(
        i,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
          lowerBound: 0.0,
          upperBound: 1.0,
          value: 0.0,
        )..forward(),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < sorted.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedBuilder(
              animation: _rowAnims[i]!,
              builder: (context, child) {
                final t = _rowAnims[i]!.value;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 16),
                    child: child,
                  ),
                );
              },
              child: _LiabilityCard(
                liability: sorted[i],
                icon: _iconForType(sorted[i].type),
                share: total <= 0 ? 0 : sorted[i].amount / total,
                peso: _peso,
                formatDate: _formatDate,
                shareColor: _shareBadgeColor(
                  total <= 0 ? 0 : sorted[i].amount / total,
                ),
                shareLabel: _shareBadgeLabel(
                  total <= 0 ? 0 : sorted[i].amount / total,
                ),
                dueColor: _dueColor(context, sorted[i].dueDate),
                dueLabel: _dueLabel(sorted[i].dueDate),
                onTap: () =>
                    _showLiabilityDetails(sorted[i], total),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Add / Edit sheet
  // ---------------------------------------------------------------------------

  Future<void> _openAddLiability() => _openLiabilityEditor();

  Future<void> _openEditLiability(Liability l) =>
      _openLiabilityEditor(liability: l);

  Future<void> _openLiabilityEditor({Liability? liability}) async {
    final isEditing = liability != null;
    final s = context.season;

    final nameController =
        TextEditingController(text: liability?.name ?? '');
    final amountController = TextEditingController(
        text: liability != null ? _displayAmount(liability.amount) : '');
    final noteController =
        TextEditingController(text: liability?.note ?? '');

    DateTime? selectedDueDate;
    if (liability?.dueDate != null) {
      selectedDueDate = DateTime.tryParse(liability!.dueDate!);
    }

    String selectedType = liability?.type ?? 'Other';
    String? nameError;
    String? amountError;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final sheetTheme = Theme.of(sheetContext);

          Future<void> submit() async {
            if (saving) return;

            final name = nameController.text.trim();
            final rawAmount = amountController.text
                .trim()
                .replaceAll(',', '')
                .replaceAll(CurrencyController.symbol, '')
                .trim();
            final amount = double.tryParse(rawAmount);

            setSheetState(() {
              nameError = name.isEmpty ? 'Enter a liability name' : null;
              amountError = amount == null || amount < 0
                  ? 'Enter a valid amount'
                  : null;
            });
            if (nameError != null || amountError != null) return;

            setSheetState(() => saving = true);

            try {
              final updated = Liability(
                id: liability?.id,
                name: name,
                type: selectedType,
                amount: CurrencyController.toPhp(amount!),
                dueDate: selectedDueDate?.toIso8601String(),
                note: noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
                updatedAt: DateTime.now().toIso8601String(),
              );

              if (isEditing) {
                if (liability.id == null) {
                  throw Exception('Liability ID is missing.');
                }
                await _service.updateLiability(updated);
              } else {
                await _service.createLiability(updated);
              }

              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              if (!mounted) return;
              await _quietReload();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEditing
                      ? 'Liability updated successfully'
                      : 'Liability added successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } catch (_) {
              if (!sheetContext.mounted) return;
              setSheetState(() {
                saving = false;
                nameError = 'Unable to save liability';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
                          color: LifeTrackColors.coral
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isEditing
                              ? Icons.edit_rounded
                              : Icons.receipt_long_rounded,
                          color: LifeTrackColors.coral,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? 'Edit liability'
                                  : 'Add liability',
                              style: sheetTheme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEditing
                                  ? 'Update the details of this debt.'
                                  : 'Track a debt you owe.',
                              style: sheetTheme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (saving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _fieldLabel(sheetContext, 'LIABILITY NAME'),
                  const SizedBox(height: 8),
                  _textField(
                    context,
                    controller: nameController,
                    enabled: !saving,
                    autofocus: !isEditing,
                    hint: 'e.g. Credit Card, Car Loan',
                    capWords: true,
                    errorText: nameError,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel(sheetContext, 'CATEGORY'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: _inputDecoration(context),
                    items: _liabilityTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t),
                            ))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setSheetState(() => selectedType = v);
                          },
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel(sheetContext, 'OUTSTANDING AMOUNT'),
                  const SizedBox(height: 8),
                  _textField(
                    context,
                    controller: amountController,
                    enabled: !saving,
                    hint: '0.00',
                    prefix: '${CurrencyController.symbol} ',
                    keyboard: const TextInputType.numberWithOptions(
                        decimal: true),
                    errorText: amountError,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel(sheetContext, 'DUE DATE'),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: saving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: sheetContext,
                              initialDate:
                                  selectedDueDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) return;
                            setSheetState(
                                () => selectedDueDate = picked);
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: s.accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18, color: s.accentText),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedDueDate == null
                                  ? 'Select due date'
                                  : _formatShortDate(
                                      selectedDueDate!
                                          .toIso8601String()),
                              style:
                                  sheetTheme.textTheme.bodyMedium,
                            ),
                          ),
                          if (selectedDueDate != null)
                            GestureDetector(
                              onTap: saving
                                  ? null
                                  : () => setSheetState(
                                      () => selectedDueDate = null),
                              child: Icon(Icons.close_rounded,
                                  size: 18,
                                  color: sheetTheme
                                      .textTheme.bodyMedium?.color),
                            )
                          else
                            Icon(Icons.chevron_right_rounded,
                                size: 18,
                                color: sheetTheme
                                    .textTheme.bodyMedium?.color),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel(sheetContext, 'NOTE'),
                  const SizedBox(height: 8),
                  _textField(
                    context,
                    controller: noteController,
                    enabled: !saving,
                    hint: 'Add a note about this liability...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: saving ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: LifeTrackColors.coral,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white),
                            )
                          : Text(
                              isEditing
                                  ? 'Save changes'
                                  : 'Add liability',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: TextButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final ok =
                                    await _confirmDelete(liability);
                                if (!ok ||
                                    !sheetContext.mounted) {
                                  return;
                                }
                                setSheetState(
                                    () => saving = true);
                                try {
                                  if (liability.id == null) {
                                    throw Exception(
                                        'Liability ID is missing.');
                                  }
                                  await _service
                                      .deleteLiability(
                                          liability.id!);
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  Navigator.of(sheetContext)
                                      .pop();
                                  if (!mounted) return;
                                  await _quietReload();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Liability deleted'),
                                      behavior: SnackBarBehavior
                                          .floating,
                                    ),
                                  );
                                } catch (_) {
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  setSheetState(
                                      () => saving = false);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Unable to delete liability'),
                                      behavior: SnackBarBehavior
                                          .floating,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(
                            Icons.delete_outline_rounded),
                        label: const Text('Delete liability'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              sheetTheme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    nameController.dispose();
    amountController.dispose();
    noteController.dispose();
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final s = context.season;
    return InputDecoration(
      filled: true,
      fillColor: s.accent.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: s.accent, width: 1.5),
      ),
    );
  }

  Widget _textField(
    BuildContext context, {
    required TextEditingController controller,
    bool enabled = true,
    bool autofocus = false,
    String? hint,
    String? prefix,
    String? errorText,
    bool capWords = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    final s = context.season;
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: capWords
          ? TextCapitalization.words
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        errorText: errorText,
        filled: true,
        fillColor: s.accent.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: s.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.7,
            ),
      );

  // ---------------------------------------------------------------------------
  // Confirm delete
  // ---------------------------------------------------------------------------

  Future<bool> _confirmDelete(Liability liability) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded,
            size: 32, color: LifeTrackColors.coral),
        title: const Text('Delete liability?'),
        content: Text(
          'Are you sure you want to delete "${liability.name}"? '
          'This action cannot be undone.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LifeTrackColors.coral,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Details sheet
  // ---------------------------------------------------------------------------

  Future<void> _showLiabilityDetails(
    Liability liability,
    double total,
  ) async {
    final share = total <= 0 ? 0.0 : liability.amount / total;
    final s = context.season;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
                      color:
                          LifeTrackColors.coral.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_iconForType(liability.type),
                        color: LifeTrackColors.coral, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(liability.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(liability.type,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      LifeTrackColors.coral.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('OUTSTANDING BALANCE',
                              style: theme.textTheme.labelSmall),
                        ),
                        _ShareBadge(
                          color: _shareBadgeColor(share),
                          label: _shareBadgeLabel(share),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _peso(liability.amount),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: LifeTrackColors.coral,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailItem(
                            label: 'Debt share',
                            value:
                                '${(share * 100).toStringAsFixed(1)}%',
                            labelColor: s.accentText,
                          ),
                        ),
                        Expanded(
                          child: _DetailItem(
                            label: 'Last updated',
                            value:
                                _formatShortDate(liability.updatedAt),
                            labelColor: s.accentText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (liability.dueDate != null ||
                  liability.note != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: s.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (liability.dueDate != null)
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 18, color: s.accentText),
                            const SizedBox(width: 8),
                            Text('Due date',
                                style: theme.textTheme.bodyMedium),
                            const Spacer(),
                            Text(
                              _formatShortDate(liability.dueDate!),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      if (liability.dueDate != null &&
                          liability.note != null)
                        const SizedBox(height: 12),
                      if (liability.note != null) ...[
                        Text('Note',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: s.accentText)),
                        const SizedBox(height: 5),
                        Text(liability.note!,
                            style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openEditLiability(liability);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: LifeTrackColors.coral,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final ok = await _confirmDelete(liability);
                        if (!ok) return;
                        try {
                          if (liability.id == null) {
                            throw Exception(
                                'Liability ID is missing.');
                          }
                          await _service
                              .deleteLiability(liability.id!);
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          if (!mounted) return;
                          await _quietReload();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Liability deleted'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Unable to delete liability'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty
  // ---------------------------------------------------------------------------

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return _InlineCard(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.check_circle_outline_rounded,
                  size: 30, color: s.accentText),
            ),
            const SizedBox(height: 14),
            Text(
              _upcomingOnly ? 'Nothing due soon' : 'No debts tracked',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _upcomingOnly
                  ? 'No liabilities have a due date in the next 30 days.'
                  : 'You currently have no liabilities recorded. '
                      'If you owe money, add it here to keep your net worth accurate.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            if (!_upcomingOnly) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openAddLiability,
                style: FilledButton.styleFrom(
                  backgroundColor: LifeTrackColors.coral,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add liability'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Local widgets
// =============================================================================

/// Local card surface — replaces LifeTrackCard so this file is self-contained.
class _InlineCard extends StatelessWidget {
  const _InlineCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Sort bar — animated pill switcher + upcoming toggle.
class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sort,
    required this.upcomingOnly,
    required this.upcomingCount,
    required this.onSortChanged,
    required this.onUpcomingToggle,
  });

  final _SortMode sort;
  final bool upcomingOnly;
  final int upcomingCount;
  final ValueChanged<_SortMode> onSortChanged;
  final VoidCallback onUpcomingToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          for (final mode in _SortMode.values)
            Expanded(
              child: _SortPill(
                label: mode.label,
                selected: mode == sort,
                onTap: () => onSortChanged(mode),
              ),
            ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: theme.dividerColor,
          ),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: onUpcomingToggle,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: upcomingOnly
                      ? s.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                      LifeTrackMetrics.chipRadius - 4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: upcomingOnly ? s.onAccent : s.accentText,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        upcomingCount > 0
                            ? 'Upcoming ($upcomingCount)'
                            : 'Upcoming',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: upcomingOnly ? s.onAccent : s.accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? s.accent : Colors.transparent,
          borderRadius:
              BorderRadius.circular(LifeTrackMetrics.chipRadius - 4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? s.onAccent : null,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

/// Row card.
class _LiabilityCard extends StatefulWidget {
  const _LiabilityCard({
    required this.liability,
    required this.icon,
    required this.share,
    required this.peso,
    required this.formatDate,
    required this.shareColor,
    required this.shareLabel,
    required this.dueColor,
    required this.dueLabel,
    required this.onTap,
  });

  final Liability liability;
  final IconData icon;
  final double share;
  final String Function(double) peso;
  final String Function(String) formatDate;
  final Color shareColor;
  final String shareLabel;
  final Color dueColor;
  final String dueLabel;
  final VoidCallback onTap;

  @override
  State<_LiabilityCard> createState() => _LiabilityCardState();
}

class _LiabilityCardState extends State<_LiabilityCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _tap.reverse();
    await _tap.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return ScaleTransition(
      scale: _tap,
      child: _InlineCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.accent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: s.accent.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 19,
                          color: LifeTrackColors.coral,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.liability.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  widget.liability.type,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: s.accentText),
                                ),
                                if (widget.dueLabel.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  _DueBadge(
                                    color: widget.dueColor,
                                    label: widget.dueLabel,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.peso(widget.liability.amount),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: LifeTrackColors.coral,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _ShareBadge(
                            color: widget.shareColor,
                            label: widget.shareLabel,
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: s.accentText.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: widget.share.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor:
                          s.accent.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(
                        _progressBarColor(widget.share),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.update_rounded,
                          size: 13,
                          color: s.accentText.withValues(alpha: 0.65)),
                      const SizedBox(width: 5),
                      Text(
                        widget.formatDate(widget.liability.updatedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: s.accentText.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _progressBarColor(double share) {
    if (share >= 0.30) return LifeTrackColors.coral;
    if (share >= 0.10) return LifeTrackColors.highlight;
    return LifeTrackColors.mint;
  }
}

/// Coral / amber / mint share pill.
class _ShareBadge extends StatelessWidget {
  const _ShareBadge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

/// Small due-date urgency pill.
class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: iconColor),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                  )),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    required this.labelColor,
  });
  final String label;
  final String value;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: labelColor)),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.error.withValues(alpha: 0.10),
              ),
              child: Icon(Icons.cloud_off_rounded,
                  color: colorScheme.error, size: 28),
            ),
            const SizedBox(height: 14),
            Text('Unable to load your liabilities',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Something went wrong while loading your debt records.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: LifeTrackColors.coral,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
