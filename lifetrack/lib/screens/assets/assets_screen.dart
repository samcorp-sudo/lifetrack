import 'package:flutter/material.dart';

import '../../models/asset.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';
import '../../widgets/lifetrack_card.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final MoneyService _service = MoneyService();

  late Future<List<Asset>> _future;

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

  static const _palette = [
    LifeTrackColors.highlight,
    LifeTrackColors.mint,
    LifeTrackColors.coral,
  ];

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  void _loadAssets() {
    _future = _service.getAssets();
  }

  void _reload() {
    setState(() {
      _loadAssets();
    });
  }

  String _peso(double value) {
    return CurrencyController.format(value);
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

  Color _colorForIndex(int index) {
    return _palette[index % _palette.length];
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return 'Updated today';
      }

      if (dateOnly == today.subtract(const Duration(days: 1))) {
        return 'Updated yesterday';
      }

      const months = [
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

      return 'Updated ${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return 'Recently updated';
    }
  }

  Future<void> _openAddAssetSheet() async {
    await _openAssetEditor();
  }

  Future<void> _openEditAsset(Asset asset) async {
    await _openAssetEditor(asset: asset);
  }

  Future<void> _openAssetEditor({Asset? asset}) async {
    final isEditing = asset != null;

    final nameController = TextEditingController(
      text: asset?.name ?? '',
    );

    final valueController = TextEditingController(
      text: asset != null ? _displayAmount(asset.value) : '',
    );

    final noteController = TextEditingController(
      text: asset?.note ?? '',
    );

    String selectedType = asset?.type ?? 'Other';

    String? nameError;
    String? valueError;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

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
                nameError =
                    name.isEmpty ? 'Enter an asset name' : null;

                valueError = value == null || value < 0
                    ? 'Enter a valid amount'
                    : null;
              });

              if (nameError != null || valueError != null) {
                return;
              }

              setSheetState(() {
                saving = true;
              });

              try {
                final now = DateTime.now().toIso8601String();

                final updatedAsset = Asset(
                  id: asset?.id,
                  name: name,
                  type: selectedType,
                  value: CurrencyController.toPhp(value!),
                  note: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                  updatedAt: now,
                );

                if (isEditing) {
                  if (asset.id == null) {
                    throw Exception('Asset ID is missing.');
                  }

                  await _service.updateAsset(updatedAsset);
                } else {
                  await _service.createAsset(updatedAsset);
                }

                if (!sheetContext.mounted) return;

                Navigator.of(sheetContext).pop();

                if (!mounted) return;

                _reload();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'Asset updated successfully'
                          : 'Asset added successfully',
                    ),
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
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: LifeTrackColors.highlight
                                  .withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.edit_rounded
                                  : Icons.savings_rounded,
                              color: LifeTrackColors.highlight,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Edit asset'
                                  : 'Add asset',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'ASSET NAME',
                        style: theme.textTheme.labelSmall,
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: nameController,
                        enabled: !saving,
                        autofocus: !isEditing,
                        textCapitalization:
                            TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Emergency Fund, Laptop, Car',
                          errorText: nameError,
                          prefixIcon: const Icon(
                            Icons.label_outline_rounded,
                          ),
                          filled: true,
                          fillColor: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'CATEGORY',
                        style: theme.textTheme.labelSmall,
                      ),

                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            _iconForType(selectedType),
                          ),
                          filled: true,
                          fillColor: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _assetTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;

                                setSheetState(() {
                                  selectedType = value;
                                });
                              },
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'CURRENT VALUE',
                        style: theme.textTheme.labelSmall,
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: valueController,
                        enabled: !saving,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText:
                              '${CurrencyController.symbol} ',
                          errorText: valueError,
                          prefixIcon: const Icon(
                            Icons.payments_outlined,
                          ),
                          filled: true,
                          fillColor: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'NOTE',
                        style: theme.textTheme.labelSmall,
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: noteController,
                        enabled: !saving,
                        maxLines: 3,
                        textCapitalization:
                            TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText:
                              'Optional note about this asset',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 42),
                            child: Icon(
                              Icons.notes_rounded,
                            ),
                          ),
                          filled: true,
                          fillColor: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: saving ? null : submit,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                LifeTrackColors.highlight,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEditing
                                      ? 'Save changes'
                                      : 'Add asset',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      if (isEditing) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: TextButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    final confirmed =
                                        await _confirmDelete(asset);

                                    if (!confirmed ||
                                        !context.mounted) {
                                      return;
                                    }

                                    setSheetState(() {
                                      saving = true;
                                    });

                                    try {
                                      await _service.deleteAsset(
                                        asset.id!,
                                      );

                                      if (!sheetContext.mounted) {
                                        return;
                                      }

                                      Navigator.of(sheetContext).pop();

                                      if (!mounted) return;

                                      _reload();

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Asset deleted',
                                          ),
                                          behavior:
                                              SnackBarBehavior.floating,
                                        ),
                                      );
                                    } catch (_) {
                                      if (!sheetContext.mounted) {
                                        return;
                                      }

                                      setSheetState(() {
                                        saving = false;
                                      });

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to delete asset',
                                          ),
                                          behavior:
                                              SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                            ),
                            label: const Text('Delete asset'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    valueController.dispose();
    noteController.dispose();
  }

  Future<bool> _confirmDelete(Asset asset) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: const Text('Delete asset?'),
          content: Text(
            'Are you sure you want to delete "${asset.name}"? '
            'This action cannot be undone.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  String _displayAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  Future<void> _showAssetDetails(
    Asset asset,
    double total,
  ) async {
    final share = total <= 0 ? 0.0 : asset.value / total;

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LifeTrackColors.highlight
                            .withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        _iconForType(asset.type),
                        color: LifeTrackColors.highlight,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.name,
                            style:
                                theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            asset.type,
                            style:
                                theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                LifeTrackCard(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT VALUE',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _peso(asset.value),
                        style:
                            theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _DetailItem(
                              label: 'Portfolio share',
                              value:
                                  '${(share * 100).toStringAsFixed(1)}%',
                            ),
                          ),
                          Expanded(
                            child: _DetailItem(
                              label: 'Last updated',
                              value:
                                  _formatShortDate(asset.updatedAt),
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
                  LifeTrackCard(
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NOTE',
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                asset.note!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
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
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final confirmed =
                              await _confirmDelete(asset);

                          if (!confirmed || !mounted) return;

                          try {
                            await _service.deleteAsset(asset.id!);

                            if (!sheetContext.mounted) return;

                            Navigator.of(sheetContext).pop();

                            if (!mounted) return;

                            _reload();

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text('Asset deleted'),
                                behavior:
                                    SnackBarBehavior.floating,
                              ),
                            );
                          } catch (_) {
                            if (!mounted) return;

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to delete asset',
                                ),
                                behavior:
                                    SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                        ),
                        label: const Text('Delete'),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              colorScheme.error,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatShortDate(String value) {
    try {
      final date = DateTime.parse(value);

      const months = [
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

      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Asset>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _reload);
          }

          final assets = snapshot.data ?? <Asset>[];

          final sortedAssets = [...assets]
            ..sort((a, b) => b.value.compareTo(a.value));

          final total = assets.fold<double>(
            0,
            (sum, asset) => sum + asset.value,
          );

          final largest =
              sortedAssets.isEmpty ? null : sortedAssets.first;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
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
                _buildHeader(context),

                const SizedBox(height: 20),

                _buildSummaryCard(
                  context,
                  total,
                  assets.length,
                  largest,
                ),

                if (assets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDistributionCard(
                    context,
                    sortedAssets,
                    total,
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'YOUR ASSETS',
                        style:
                            Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    if (assets.isNotEmpty)
                      Text(
                        '${assets.length} total',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                if (assets.isEmpty)
                  _EmptyState(
                    onAdd: _openAddAssetSheet,
                  )
                else
                  ...[
                    for (int i = 0;
                        i < sortedAssets.length;
                        i++)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 12),
                        child: _AssetCard(
                          asset: sortedAssets[i],
                          color: _colorForIndex(i),
                          icon: _iconForType(
                            sortedAssets[i].type,
                          ),
                          share: total <= 0
                              ? 0
                              : sortedAssets[i].value / total,
                          peso: _peso,
                          formatDate: _formatDate,
                          onTap: () => _showAssetDetails(
                            sortedAssets[i],
                            total,
                          ),
                        ),
                      ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.08),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assets',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Everything you own',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Add asset',
          onPressed: _openAddAssetSheet,
          style: IconButton.styleFrom(
            backgroundColor:
                LifeTrackColors.highlight.withValues(alpha: 0.12),
          ),
          icon: const Icon(
            Icons.add_rounded,
            color: LifeTrackColors.highlight,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    double total,
    int count,
    Asset? largest,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LifeTrackColors.highlight.withValues(alpha: 0.16),
            LifeTrackColors.highlight.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LifeTrackColors.highlight
              .withValues(alpha: 0.14),
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
                  color: LifeTrackColors.highlight
                      .withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: LifeTrackColors.highlight,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'TOTAL ASSETS',
                style: theme.textTheme.labelSmall,
              ),
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
                  label: 'Tracked',
                  value:
                      '$count ${count == 1 ? 'asset' : 'assets'}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.star_rounded,
                  label: 'Largest',
                  value: largest == null
                      ? '—'
                      : largest.name,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(
    BuildContext context,
    List<Asset> assets,
    double total,
  ) {
    final theme = Theme.of(context);

    return LifeTrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart_outline_rounded,
                size: 20,
                color: LifeTrackColors.highlight,
              ),
              const SizedBox(width: 8),
              Text(
                'Asset distribution',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ...assets.take(5).map((asset) {
            final share =
                total <= 0 ? 0.0 : asset.value / total;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),

          if (assets.length > 5)
            Text(
              '+ ${assets.length - 5} more assets',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.color,
    required this.icon,
    required this.share,
    required this.peso,
    required this.formatDate,
    required this.onTap,
  });

  final Asset asset;
  final Color color;
  final IconData icon;
  final double share;
  final String Function(double) peso;
  final String Function(String) formatDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LifeTrackCard(
      child: InkWell(
        onTap: onTap,
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
                      color: color.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: color,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          asset.type,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(
                            color:
                                colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text(
                        peso(asset.value),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(share * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
                          color:
                              colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 4),

                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    Icons.update_rounded,
                    size: 13,
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    formatDate(asset.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  if (asset.note != null &&
                      asset.note!.trim().isNotEmpty)
                    Icon(
                      Icons.notes_rounded,
                      size: 15,
                      color: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: LifeTrackColors.highlight,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAdd,
  });

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LifeTrackCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 34,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LifeTrackColors.highlight
                    .withValues(alpha: 0.10),
              ),
              child: const Icon(
                Icons.savings_rounded,
                size: 30,
                color: LifeTrackColors.highlight,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Start tracking what you own',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Add your savings, investments, property, '
              'vehicles, and other valuable assets.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first asset'),
              style: FilledButton.styleFrom(
                backgroundColor: LifeTrackColors.highlight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.onRetry,
  });

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
              child: Icon(
                Icons.cloud_off_rounded,
                color: colorScheme.error,
                size: 28,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Unable to load your assets',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Something went wrong while loading your asset records.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 14),

            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: TextButton.styleFrom(
                foregroundColor: LifeTrackColors.highlight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

