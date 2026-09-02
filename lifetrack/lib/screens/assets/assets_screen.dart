// ============================================================================
// Assets Screen
// ============================================================================
//
// WHAT THIS SCREEN DOES
// ----------------------------------------------------------------------------
// Tracks everything the user owns: cash, savings, investments, crypto,
// property, vehicles, electronics, other. The user can:
//   • Add a new asset
//   • Tap one to see full details, edit, or delete
//   • Sort by value / name
//   • Filter to assets with a note, or all
//   • See at-a-glance: total assets, largest holding, share badge per row
//
// SELF-CONTAINED
// ----------------------------------------------------------------------------
// This file imports no app widgets. Everything the screen renders is
// declared right here:
//   _InlineCard       — local card surface (replaces LifeTrackCard)
//   _AssetCard        — row card with press-scale
//   _ShareBadge       — amber / mint / season share pill
//   _SummaryStat      — small label + value row
//   _DetailItem       — label + value inside the details sheet
//   _EmptyState       — empty state card
//   _ErrorState       — error retry view
//   _SortBar, _SortPill — sort switcher
// Only external imports: MoneyService, Asset model, CurrencyController,
// AppTheme (for season + metrics).
//
// SEASON COLORS — WHAT FOLLOWS THE SEASON AND WHAT DOESN'T
// ----------------------------------------------------------------------------
// Semantic (always the same, ignores season):
//   • Asset values → default text color (assets are neutral, not positive
//     in the "green = income" sense; they're just holdings)
//   • Share badge: mint (dominant) / amber (medium) / muted season (small)
//     Note: mint = "this one is your biggest asset", opposite of debt.
//
// Seasonal (reads context.season):
//   • Back button chip, add-button tint, empty-state circle, sheet field
//     backgrounds, calendar rows (none here), list-row dividers, secondary
//     text on card surfaces, detail labels, progress-bar backgrounds,
//     row icon chip background, "Largest" stat icon.
//   • In Tag-ulan, all of that turns teal. In Amihan, violet.
//
// SHARE BADGE THRESHOLDS
// ----------------------------------------------------------------------------
//   ≥ 30%  → mint    "this dominates your portfolio"
//   10–30% → amber   "significant holding"
//   < 10%  → muted season accent  "small position"
// Opposite intent from the liabilities screen: a big asset is good news.
//
// ANIMATIONS
// ----------------------------------------------------------------------------
//   • Rows stagger-fade in on load, after add/edit/delete.
//   • Press-scale on every tappable row.
//   • Add/Edit and Details sheets use showDragHandle: true.
//   • Sort pills animate color + weight.
//
// WHAT NOT TO DO
// ----------------------------------------------------------------------------
//   • Do not use coral for asset values — coral means "money going out".
//     Assets are neutral or positive; use the default text color for the
//     amount and mint for a dominant-holding badge.
//   • Do not call a repository directly. MoneyService is the entry point.
// ============================================================================

import 'package:flutter/material.dart';

import '../../app/currency_controller.dart';
import '../../models/asset.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

// -----------------------------------------------------------------------------
// Sort modes
// -----------------------------------------------------------------------------

enum _SortMode { value, name }

extension _SortModeX on _SortMode {
  String get label => switch (this) {
        _SortMode.value => 'Value',
        _SortMode.name => 'Name',
      };
}

class _AssetsScreenState extends State<AssetsScreen>
    with TickerProviderStateMixin {
  final MoneyService _service = MoneyService();

  List<Asset>? _assets;
  bool _loading = true;
  Object? _error;

  _SortMode _sort = _SortMode.value;
  bool _withNotesOnly = false;

  final Map<int, AnimationController> _rowAnims = {};

  static const List<String> _assetTypes = [
    'Cash & Wallet',
    'Bank & Savings',
    'Investments',
    'Crypto',
    'Property',
    'Vehicles',
    'Electronics',
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
    if (mounted) setState(() => _loading = _assets == null);
    try {
      final items = await _service.getAssets();
      if (!mounted) return;
      setState(() {
        _assets = items;
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
      final items = await _service.getAssets();
      if (!mounted) return;
      setState(() {
        _assets = items;
        _error = null;
      });
    } catch (_) {}
  }

  void _reload() => _load();

  // ---------------------------------------------------------------------------
  // Filtering + sorting
  // ---------------------------------------------------------------------------

  List<Asset> _visible(List<Asset> items) {
    var list = [...items];
    if (_withNotesOnly) {
      list = list
          .where((a) => a.note != null && a.note!.trim().isNotEmpty)
          .toList();
    }
    list.sort((a, b) {
      switch (_sort) {
        case _SortMode.value:
          return b.value.compareTo(a.value);
        case _SortMode.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return list;
  }

  int _withNoteCount(List<Asset> items) => items
      .where((a) => a.note != null && a.note!.trim().isNotEmpty)
      .length;

  void _setSort(_SortMode m) {
    if (m == _sort) return;
    setState(() {
      _sort = m;
      _rowAnims.clear();
    });
  }

  void _toggleWithNotes() {
    setState(() {
      _withNotesOnly = !_withNotesOnly;
      _rowAnims.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _peso(double value) => CurrencyController.format(value);

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
      case 'Cash & Wallet':
        return Icons.account_balance_wallet_rounded;
      case 'Bank & Savings':
        return Icons.account_balance_rounded;
      case 'Investments':
        return Icons.trending_up_rounded;
      case 'Crypto':
        return Icons.currency_bitcoin_rounded;
      case 'Property':
        return Icons.home_rounded;
      case 'Vehicles':
        return Icons.directions_car_rounded;
      case 'Electronics':
        return Icons.devices_rounded;
      default:
        return Icons.savings_rounded;
    }
  }

  /// For assets, "dominant" is GOOD news — mint. Amber is "significant".
  /// Small assets fade to the season accent (informational, not warning).
  Color _shareBadgeColor(BuildContext context, double share) {
    if (share >= 0.30) return LifeTrackColors.mint;
    if (share >= 0.10) return LifeTrackColors.highlight;
    return context.season.accentText;
  }

  String _shareBadgeLabel(double share) =>
      '${(share * 100).toStringAsFixed(0)}%';

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
                : _buildBody(context, _assets ?? const []),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Asset> items) {
    final visible = _visible(items);
    final total = items.fold<double>(0, (sum, a) => sum + a.value);
    final largest = visible.isEmpty ? null : visible.first;
    final notes = _withNoteCount(items);

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
          _summaryCard(context, total, items.length, largest),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            _distributionCard(context, visible, total),
            const SizedBox(height: 20),
            _SortBar(
              sort: _sort,
              withNotesOnly: _withNotesOnly,
              withNoteCount: notes,
              onSortChanged: _setSort,
              onNotesToggle: _toggleWithNotes,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _withNotesOnly ? 'ASSETS WITH NOTES' : 'YOUR ASSETS',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              if (visible.isNotEmpty)
                Text(
                  '${visible.length} shown',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            _emptyState(context)
          else
            _assetsList(context, visible, total),
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
              Text('Assets',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Everything you own',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Add asset',
          onPressed: _openAddAssetSheet,
          style: IconButton.styleFrom(
            backgroundColor:
                LifeTrackColors.mint.withValues(alpha: 0.14),
          ),
          icon: const Icon(Icons.add_rounded,
              color: LifeTrackColors.mint),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Summary — soft mint-cream gradient, not aggressive
  // ---------------------------------------------------------------------------

  Widget _summaryCard(
    BuildContext context,
    double total,
    int count,
    Asset? largest,
  ) {
    final theme = Theme.of(context);
    final s = context.season;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LifeTrackColors.mint.withValues(alpha: 0.12),
            LifeTrackColors.mint.withValues(alpha: 0.03),
            s.accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LifeTrackColors.mint.withValues(alpha: 0.14),
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
                  color: LifeTrackColors.mint.withValues(alpha: 0.16),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    size: 20, color: LifeTrackColors.mint),
              ),
              const SizedBox(width: 10),
              Text('TOTAL ASSETS', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _peso(total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
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
                      '$count ${count == 1 ? 'asset' : 'assets'}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.star_rounded,
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
    List<Asset> assets,
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
                'Asset distribution',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...assets.take(5).map((asset) {
            final share = total <= 0 ? 0.0 : asset.value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          asset.name,
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
                          LifeTrackColors.mint),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (assets.length > 5)
            Text(
              '+ ${assets.length - 5} more assets',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rows
  // ---------------------------------------------------------------------------

  Widget _assetsList(
    BuildContext context,
    List<Asset> visible,
    double total,
  ) {
    _rowAnims.removeWhere((index, c) {
      if (index >= visible.length) {
        c.dispose();
        return true;
      }
      return false;
    });
    for (var i = 0; i < visible.length; i++) {
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
        for (int i = 0; i < visible.length; i++)
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
              child: _AssetCard(
                asset: visible[i],
                icon: _iconForType(visible[i].type),
                share: total <= 0 ? 0 : visible[i].value / total,
                peso: _peso,
                formatDate: _formatDate,
                shareColor: _shareBadgeColor(
                  context,
                  total <= 0 ? 0 : visible[i].value / total,
                ),
                shareLabel: _shareBadgeLabel(
                  total <= 0 ? 0 : visible[i].value / total,
                ),
                onTap: () => _showAssetDetails(visible[i], total),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Add / Edit sheet
  // ---------------------------------------------------------------------------

  Future<void> _openAddAssetSheet() => _openAssetEditor();

  Future<void> _openEditAsset(Asset a) => _openAssetEditor(asset: a);

  Future<void> _openAssetEditor({Asset? asset}) async {
    final isEditing = asset != null;
    final s = context.season;

    final nameController =
        TextEditingController(text: asset?.name ?? '');
    final valueController = TextEditingController(
        text: asset != null ? _displayAmount(asset.value) : '');
    final noteController =
        TextEditingController(text: asset?.note ?? '');

    String selectedType = asset?.type ?? 'Other';
    String? nameError;
    String? valueError;
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
            final rawValue = valueController.text
                .trim()
                .replaceAll(',', '')
                .replaceAll(CurrencyController.symbol, '')
                .trim();
            final value = double.tryParse(rawValue);

            setSheetState(() {
              nameError = name.isEmpty ? 'Enter an asset name' : null;
              valueError = value == null || value < 0
                  ? 'Enter a valid amount'
                  : null;
            });
            
            if (nameError != null || valueError != null) return;

            setSheetState(() => saving = true);

            try {
              final updated = Asset(
                id: asset?.id,
                name: name,
                type: selectedType,
                value: CurrencyController.toPhp(value!),
                note: noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
                updatedAt: DateTime.now().toIso8601String(),
              );

              if (isEditing) {
                if (asset.id == null) {
                  throw Exception('Asset ID is missing.');
                }
                await _service.updateAsset(updated);
              } else {
                await _service.createAsset(updated);
              }

              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              if (!mounted) return;
              await _quietReload();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEditing
                      ? 'Asset updated successfully'
                      : 'Asset added successfully'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } catch (_) {
              if (!sheetContext.mounted) return;
              setSheetState(() {
                saving = false;
                nameError = 'Unable to save asset';
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
                          color: LifeTrackColors.mint
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isEditing
                              ? Icons.edit_rounded
                              : Icons.savings_rounded,
                          color: LifeTrackColors.mint,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit asset' : 'Add asset',
                              style: sheetTheme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEditing
                                  ? 'Update the details of this asset.'
                                  : 'Track something you own.',
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

                  _fieldLabel(sheetContext, 'ASSET NAME'),
                  const SizedBox(height: 8),
                  _textField(
                    context,
                    controller: nameController,
                    enabled: !saving,
                    autofocus: !isEditing,
                    hint: 'e.g. Emergency Fund, Laptop, Car',
                    capWords: true,
                    errorText: nameError,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel(sheetContext, 'CATEGORY'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: _inputDecoration(context),
                    items: _assetTypes
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

                  _fieldLabel(sheetContext, 'CURRENT VALUE'),
                  const SizedBox(height: 8),
                  _textField(
                    context,
                    controller: valueController,
                    enabled: !saving,
                    hint: '0.00',
                    prefix: '${CurrencyController.symbol} ',
                    keyboard: const TextInputType.numberWithOptions(
                        decimal: true),
                    errorText: valueError,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel(sheetContext, 'NOTE'),
                  const SizedBox(height: 8),
                  _textField(
                    context,
                    controller: noteController,
                    enabled: !saving,
                    hint: 'Optional note about this asset',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: saving ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: LifeTrackColors.mint,
                        foregroundColor: LifeTrackColors.ink,
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
                                  color: LifeTrackColors.ink),
                            )
                          : Text(
                              isEditing
                                  ? 'Save changes'
                                  : 'Add asset',
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
                                final ok = await _confirmDelete(asset);
                                if (!ok ||
                                    !sheetContext.mounted) {
                                  return;
                                }
                                setSheetState(() => saving = true);
                                try {
                                  if (asset.id == null) {
                                    throw Exception(
                                        'Asset ID is missing.');
                                  }
                                  await _service
                                      .deleteAsset(asset.id!);
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
                                          Text('Asset deleted'),
                                      behavior: SnackBarBehavior
                                          .floating,
                                    ),
                                  );
                                } catch (_) {
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Unable to delete asset'),
                                      behavior: SnackBarBehavior
                                          .floating,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(
                            Icons.delete_outline_rounded),
                        label: const Text('Delete asset'),
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
    valueController.dispose();
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

  Future<bool> _confirmDelete(Asset asset) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded,
            size: 32, color: LifeTrackColors.coral),
        title: const Text('Delete asset?'),
        content: Text(
          'Are you sure you want to delete "${asset.name}"? '
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

  Future<void> _showAssetDetails(Asset asset, double total) async {
    final share = total <= 0 ? 0.0 : asset.value / total;
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
                      color: LifeTrackColors.mint
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_iconForType(asset.type),
                        color: LifeTrackColors.mint, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(asset.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(asset.type,
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
                  color: LifeTrackColors.mint.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('CURRENT VALUE',
                              style: theme.textTheme.labelSmall),
                        ),
                        _ShareBadge(
                          color: _shareBadgeColor(context, share),
                          label: _shareBadgeLabel(share),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _peso(asset.value),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailItem(
                            label: 'Portfolio share',
                            value:
                                '${(share * 100).toStringAsFixed(1)}%',
                            labelColor: s.accentText,
                          ),
                        ),
                        Expanded(
                          child: _DetailItem(
                            label: 'Last updated',
                            value: _formatShortDate(asset.updatedAt),
                            labelColor: s.accentText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (asset.note != null &&
                  asset.note!.trim().isNotEmpty) ...[
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
                      Row(
                        children: [
                          Icon(Icons.notes_rounded,
                              size: 16, color: s.accentText),
                          const SizedBox(width: 6),
                          Text('NOTE',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: s.accentText)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(asset.note!,
                          style: theme.textTheme.bodyMedium),
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
                        _openEditAsset(asset);
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
                        final ok = await _confirmDelete(asset);
                        if (!ok) return;
                        try {
                          if (asset.id == null) {
                            throw Exception('Asset ID is missing.');
                          }
                          await _service.deleteAsset(asset.id!);
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                          if (!mounted) return;
                          await _quietReload();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Asset deleted'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to delete asset'),
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
              child: Icon(Icons.savings_outlined,
                  size: 30, color: s.accentText),
            ),
            const SizedBox(height: 14),
            Text(
              _withNotesOnly
                  ? 'No assets with notes'
                  : 'Start tracking what you own',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _withNotesOnly
                  ? 'No assets have a note yet. Add one from any asset\'s editor.'
                  : 'Add your savings, investments, property, vehicles, and other valuable assets.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            if (!_withNotesOnly) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openAddAssetSheet,
                style: FilledButton.styleFrom(
                  backgroundColor: LifeTrackColors.mint,
                  foregroundColor: LifeTrackColors.ink,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add your first asset'),
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

/// Sort bar — animated pill switcher + "with notes only" toggle.
class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sort,
    required this.withNotesOnly,
    required this.withNoteCount,
    required this.onSortChanged,
    required this.onNotesToggle,
  });

  final _SortMode sort;
  final bool withNotesOnly;
  final int withNoteCount;
  final ValueChanged<_SortMode> onSortChanged;
  final VoidCallback onNotesToggle;

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
              onTap: onNotesToggle,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: withNotesOnly
                      ? s.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                      LifeTrackMetrics.chipRadius - 4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 14,
                      color: withNotesOnly ? s.onAccent : s.accentText,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        withNoteCount > 0
                            ? 'Notes ($withNoteCount)'
                            : 'Notes',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color:
                              withNotesOnly ? s.onAccent : s.accentText,
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

/// Row card with press-scale + share badge.
class _AssetCard extends StatefulWidget {
  const _AssetCard({
    required this.asset,
    required this.icon,
    required this.share,
    required this.peso,
    required this.formatDate,
    required this.shareColor,
    required this.shareLabel,
    required this.onTap,
  });

  final Asset asset;
  final IconData icon;
  final double share;
  final String Function(double) peso;
  final String Function(String) formatDate;
  final Color shareColor;
  final String shareLabel;
  final VoidCallback onTap;

  @override
  State<_AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<_AssetCard>
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
    final hasNote =
        widget.asset.note != null && widget.asset.note!.trim().isNotEmpty;

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
                          color: LifeTrackColors.mint,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.asset.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.asset.type,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: s.accentText),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.peso(widget.asset.value),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
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
                        _barColor(context, widget.share),
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
                        widget.formatDate(widget.asset.updatedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: s.accentText.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      if (hasNote)
                        Icon(Icons.notes_rounded,
                            size: 14,
                            color: s.accentText.withValues(alpha: 0.6)),
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

  Color _barColor(BuildContext context, double share) {
    if (share >= 0.30) return LifeTrackColors.mint;
    if (share >= 0.10) return LifeTrackColors.highlight;
    return context.season.accentText;
  }
}

/// Share pill — mint / amber / season accent.
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
            Text('Unable to load your assets',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Something went wrong while loading your asset records.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: LifeTrackColors.mint,
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
