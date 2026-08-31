import 'package:flutter/material.dart';

import '../../models/liability.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';
import '../../widgets/lifetrack_card.dart';

class LiabilitiesScreen extends StatefulWidget {
  const LiabilitiesScreen({super.key});

  @override
  State<LiabilitiesScreen> createState() => _LiabilitiesScreenState();
}

class _LiabilitiesScreenState extends State<LiabilitiesScreen> {
  final MoneyService _service = MoneyService();

  late Future<List<Liability>> _future;

  static const List<String> _liabilityTypes = [
    'Credit Card',
    'Personal Loan',
    'Car Loan',
    'Mortgage',
    'Student Loan',
    'Medical Debt',
    'Other',
  ];

  static const _palette = [
    LifeTrackColors.coral,
    LifeTrackColors.highlight,
    LifeTrackColors.mint,
  ];

  @override
  void initState() {
    super.initState();
    _loadLiabilities();
  }

  void _loadLiabilities() {
    _future = _service.getLiabilities();
  }

  void _reload() {
    setState(() {
      _loadLiabilities();
    });
  }

  String _peso(double value) {
    return CurrencyController.format(value);
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

  String _displayAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  Future<void> _openAddLiability() async {
    await _openLiabilityEditor();
  }

  Future<void> _openEditLiability(Liability liability) async {
    await _openLiabilityEditor(
      liability: liability,
    );
  }

  Future<void> _openLiabilityEditor({
    Liability? liability,
  }) async {
    final isEditing = liability != null;

    final nameController = TextEditingController(
      text: liability?.name ?? '',
    );

    final amountController = TextEditingController(
      text: liability != null
          ? _displayAmount(liability.amount)
          : '',
    );

    // Separate controller for each Add/Edit sheet.
    final noteController = TextEditingController(
      text: liability?.note ?? '',
    );

    // Load existing due date when editing.
    DateTime? selectedDueDate;

    if (liability?.dueDate != null) {
      selectedDueDate = DateTime.tryParse(
        liability!.dueDate!,
      );
    }

    String selectedType = liability?.type ?? 'Other';

    String? nameError;
    String? amountError;
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

              final rawAmount = amountController.text
                  .trim()
                  .replaceAll(',', '')
                  .replaceAll(
                    CurrencyController.symbol,
                    '',
                  )
                  .trim();

              final amount = double.tryParse(rawAmount);

              setSheetState(() {
                nameError = name.isEmpty
                    ? 'Enter a liability name'
                    : null;

                amountError =
                    amount == null || amount < 0
                        ? 'Enter a valid amount'
                        : null;
              });

              if (nameError != null || amountError != null) {
                return;
              }

              setSheetState(() {
                saving = true;
              });

              try {
                final updatedLiability = Liability(
                  id: liability?.id,
                  name: name,
                  type: selectedType,

                  // Convert entered amount to PHP.
                  amount: CurrencyController.toPhp(amount!),

                  // Store the selected due date as an ISO string.
                  dueDate: selectedDueDate?.toIso8601String(),

                  // Store note as null when empty.
                  note: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),

                  // Always update this when the record is saved.
                  updatedAt: DateTime.now().toIso8601String(),
                );

                if (isEditing) {
                  if (liability.id == null) {
                    throw Exception(
                      'Liability ID is missing.',
                    );
                  }

                  await _service.updateLiability(
                    updatedLiability,
                  );
                } else {
                  await _service.createLiability(
                    updatedLiability,
                  );
                }

                if (!sheetContext.mounted) return;

                Navigator.of(sheetContext).pop();

                if (!mounted) return;

                _reload();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'Liability updated successfully'
                          : 'Liability added successfully',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!sheetContext.mounted) return;

                setSheetState(() {
                  saving = false;
                  nameError = 'Unable to save liability';
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
                      // -----------------------------------------------------
                      // Handle
                      // -----------------------------------------------------

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

                      // -----------------------------------------------------
                      // Header
                      // -----------------------------------------------------

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: LifeTrackColors.coral
                                  .withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.edit_rounded
                                  : Icons.receipt_long_rounded,
                              color: LifeTrackColors.coral,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Edit liability'
                                  : 'Add liability',
                              style:
                                  theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed: saving
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                  },
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // -----------------------------------------------------
                      // Liability Name
                      // -----------------------------------------------------

                      Text(
                        'LIABILITY NAME',
                        style: theme.textTheme.labelSmall,
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: nameController,
                        enabled: !saving,
                        autofocus: !isEditing,
                        textCapitalization:
                            TextCapitalization.words,
                        textInputAction:
                            TextInputAction.next,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Credit Card, Car Loan, Mortgage',
                          errorText: nameError,
                          prefixIcon: const Icon(
                            Icons.label_outline_rounded,
                          ),
                          filled: true,
                          fillColor: colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // -----------------------------------------------------
                      // Category
                      // -----------------------------------------------------

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
                          fillColor: colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _liabilityTypes.map((type) {
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

                      // -----------------------------------------------------
                      // Amount
                      // -----------------------------------------------------

                      Text(
                        'OUTSTANDING AMOUNT',
                        style: theme.textTheme.labelSmall,
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: amountController,
                        enabled: !saving,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction:
                            TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText:
                              '${CurrencyController.symbol} ',
                          errorText: amountError,
                          prefixIcon: const Icon(
                            Icons.payments_outlined,
                          ),
                          filled: true,
                          fillColor: colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // -----------------------------------------------------
                      // Due Date
                      // -----------------------------------------------------

                      Text(
                        'DUE DATE',
                        style: theme.textTheme.labelSmall,
                      ),

                      const SizedBox(height: 8),

                      InkWell(
                        onTap: saving
                            ? null
                            : () async {
                                final picked =
                                    await showDatePicker(
                                  context: context,
                                  initialDate:
                                      selectedDueDate ??
                                          DateTime.now(),
                                  firstDate:
                                      DateTime(2000),
                                  lastDate:
                                      DateTime(2100),
                                );

                                if (picked == null) {
                                  return;
                                }

                                setSheetState(() {
                                  selectedDueDate = picked;
                                });
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.06),
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  selectedDueDate == null
                                      ? 'Select due date'
                                      : _formatShortDate(
                                          selectedDueDate!
                                              .toIso8601String(),
                                        ),
                                  style: theme
                                      .textTheme.bodyMedium
                                      ?.copyWith(
                                    color:
                                        selectedDueDate == null
                                            ? colorScheme
                                                .onSurfaceVariant
                                            : null,
                                  ),
                                ),
                              ),

                              if (selectedDueDate != null)
                                IconButton(
                                  onPressed: saving
                                      ? null
                                      : () {
                                          setSheetState(() {
                                            selectedDueDate =
                                                null;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 20,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // -----------------------------------------------------
                      // Note
                      // -----------------------------------------------------

                      Text(
                        'NOTE',
                        style: theme.textTheme.labelSmall,
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: noteController,
                        enabled: !saving,
                        textCapitalization:
                            TextCapitalization.sentences,
                        maxLines: 3,
                        textInputAction:
                            TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText:
                              'Add a note about this liability...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(
                              left: 12,
                              right: 8,
                              bottom: 40,
                            ),
                            child: Icon(
                              Icons.notes_rounded,
                            ),
                          ),
                          filled: true,
                          fillColor: colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.06),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.all(16),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // -----------------------------------------------------
                      // Save Button
                      // -----------------------------------------------------

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: saving ? null : submit,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                LifeTrackColors.coral,
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
                                      : 'Add liability',
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      // -----------------------------------------------------
                      // Delete Button
                      // -----------------------------------------------------

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
                                        await _confirmDelete(
                                      liability,
                                    );

                                    if (!confirmed ||
                                        !context.mounted) {
                                      return;
                                    }

                                    setSheetState(() {
                                      saving = true;
                                    });

                                    try {
                                      if (liability.id == null) {
                                        throw Exception(
                                          'Liability ID is missing.',
                                        );
                                      }

                                      await _service
                                          .deleteLiability(
                                        liability.id!,
                                      );

                                      if (!sheetContext
                                          .mounted) {
                                        return;
                                      }

                                      Navigator.of(
                                        sheetContext,
                                      ).pop();

                                      if (!mounted) return;

                                      _reload();

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Liability deleted',
                                          ),
                                          behavior:
                                              SnackBarBehavior
                                                  .floating,
                                        ),
                                      );
                                    } catch (_) {
                                      if (!sheetContext
                                          .mounted) {
                                        return;
                                      }

                                      setSheetState(() {
                                        saving = false;
                                      });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to delete liability',
                                          ),
                                          behavior:
                                              SnackBarBehavior
                                                  .floating,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                            ),
                            label: const Text(
                              'Delete liability',
                            ),
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

    // Dispose controllers after the bottom sheet closes.
    nameController.dispose();
    amountController.dispose();
    noteController.dispose();
  }

  // ---------------------------------------------------------------------------
  // Confirm Delete
  // ---------------------------------------------------------------------------

  Future<bool> _confirmDelete(
    Liability liability,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: const Text(
            'Delete liability?',
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${liability.name}"? '
            'This action cannot be undone.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    theme.colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Liability Details
  // ---------------------------------------------------------------------------

  Future<void> _showLiabilityDetails(
    Liability liability,
    double total,
  ) async {
    final share = total <= 0
        ? 0.0
        : liability.amount / total;

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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                24,
                14,
                24,
                28,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.25),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LifeTrackColors.coral
                              .withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          _iconForType(
                            liability.type,
                          ),
                          color:
                              LifeTrackColors.coral,
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
                              liability.name,
                              style: theme
                                  .textTheme.titleLarge
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              liability.type,
                              style: theme
                                  .textTheme.bodySmall
                                  ?.copyWith(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.of(
                            sheetContext,
                          ).pop();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Amount
                  LifeTrackCard(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OUTSTANDING BALANCE',
                          style:
                              theme.textTheme.labelSmall,
                        ),

                        const SizedBox(height: 6),

                        Text(
                          _peso(liability.amount),
                          style: theme
                              .textTheme.headlineMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                            color:
                                LifeTrackColors.coral,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _DetailItem(
                                label: 'Debt share',
                                value:
                                    '${(share * 100).toStringAsFixed(1)}%',
                              ),
                            ),

                            Expanded(
                              child: _DetailItem(
                                label: 'Last updated',
                                value:
                                    _formatShortDate(
                                  liability.updatedAt,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Due date and note
                  if (liability.dueDate != null ||
                      liability.note != null) ...[
                    const SizedBox(height: 18),

                    LifeTrackCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (liability.dueDate != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .calendar_today_rounded,
                                  size: 18,
                                  color:
                                      LifeTrackColors.coral,
                                ),

                                const SizedBox(width: 8),

                                Text(
                                  'Due date',
                                  style: theme
                                      .textTheme.bodySmall
                                      ?.copyWith(
                                    color: colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),

                                const Spacer(),

                                Text(
                                  _formatShortDate(
                                    liability.dueDate!,
                                  ),
                                  style: theme
                                      .textTheme.bodyMedium
                                      ?.copyWith(
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),

                          if (liability.dueDate != null &&
                              liability.note != null)
                            const SizedBox(height: 16),

                          if (liability.note != null) ...[
                            Text(
                              'Note',
                              style: theme
                                  .textTheme.bodySmall
                                  ?.copyWith(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              liability.note!,
                              style:
                                  theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(
                              sheetContext,
                            ).pop();

                            _openEditLiability(
                              liability,
                            );
                          },
                          icon: const Icon(
                            Icons.edit_rounded,
                          ),
                          label: const Text('Edit'),
                          style:
                              OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape:
                                RoundedRectangleBorder(
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
                                await _confirmDelete(
                              liability,
                            );

                            if (!confirmed || !mounted) {
                              return;
                            }

                            try {
                              if (liability.id == null) {
                                throw Exception(
                                  'Liability ID is missing.',
                                );
                              }

                              await _service
                                  .deleteLiability(
                                liability.id!,
                              );

                              if (!sheetContext.mounted) {
                                return;
                              }

                              Navigator.of(
                                sheetContext,
                              ).pop();

                              if (!mounted) return;

                              _reload();

                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Liability deleted',
                                  ),
                                  behavior:
                                      SnackBarBehavior
                                          .floating,
                                ),
                              );
                            } catch (_) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to delete liability',
                                  ),
                                  behavior:
                                      SnackBarBehavior
                                          .floating,
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
                                const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape:
                                RoundedRectangleBorder(
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
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Liability>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              onRetry: _reload,
            );
          }

          final liabilities =
              snapshot.data ?? <Liability>[];

          final sortedLiabilities = [...liabilities]
            ..sort(
              (a, b) => b.amount.compareTo(a.amount),
            );

          final total = liabilities.fold<double>(
            0,
            (sum, liability) =>
                sum + liability.amount,
          );

          final largest = sortedLiabilities.isEmpty
              ? null
              : sortedLiabilities.first;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(
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
                  liabilities.length,
                  largest,
                ),

                if (liabilities.isNotEmpty) ...[
                  const SizedBox(height: 16),

                  _buildDistributionCard(
                    context,
                    sortedLiabilities,
                    total,
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'YOUR LIABILITIES',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall,
                      ),
                    ),

                    if (liabilities.isNotEmpty)
                      Text(
                        '${liabilities.length} total',
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

                if (liabilities.isEmpty)
                  _EmptyState(
                    onAdd: _openAddLiability,
                  )
                else
                  ...[
                    for (int i = 0;
                        i < sortedLiabilities.length;
                        i++)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: _LiabilityCard(
                          liability:
                              sortedLiabilities[i],
                          color:
                              _colorForIndex(i),
                          icon: _iconForType(
                            sortedLiabilities[i]
                                .type,
                          ),
                          share: total <= 0
                              ? 0
                              : sortedLiabilities[i]
                                      .amount /
                                  total,
                          peso: _peso,
                          formatDate:
                              _formatDate,
                          onTap: () =>
                              _showLiabilityDetails(
                            sortedLiabilities[i],
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

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        InkWell(
          onTap: () =>
              Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme
                  .onSurfaceVariant
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Liabilities',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                'What you currently owe',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Add liability',
          onPressed: _openAddLiability,
          style: IconButton.styleFrom(
            backgroundColor:
                LifeTrackColors.coral.withValues(
              alpha: 0.12,
            ),
          ),
          icon: const Icon(
            Icons.add_rounded,
            color: LifeTrackColors.coral,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Summary Card
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCard(
    BuildContext context,
    double total,
    int count,
    Liability? largest,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LifeTrackColors.coral.withValues(
              alpha: 0.16,
            ),
            LifeTrackColors.coral.withValues(
              alpha: 0.05,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LifeTrackColors.coral.withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LifeTrackColors.coral
                      .withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: LifeTrackColors.coral,
                ),
              ),

              const SizedBox(width: 10),

              Text(
                'TOTAL DEBT',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            _peso(total),
            style: theme
                .textTheme
                .headlineMedium
                ?.copyWith(
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
                  label: 'Tracked',
                  value:
                      '$count ${count == 1 ? 'liability' : 'liabilities'}',
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _SummaryStat(
                  icon:
                      Icons.warning_amber_rounded,
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

  // ---------------------------------------------------------------------------
  // Distribution Card
  // ---------------------------------------------------------------------------

  Widget _buildDistributionCard(
    BuildContext context,
    List<Liability> liabilities,
    double total,
  ) {
    final theme = Theme.of(context);

    return LifeTrackCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart_outline_rounded,
                size: 20,
                color: LifeTrackColors.coral,
              ),

              const SizedBox(width: 8),

              Text(
                'Debt distribution',
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ...liabilities.take(5).map(
            (liability) {
              final share = total <= 0
                  ? 0.0
                  : liability.amount / total;

              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            liability.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Text(
                          '${(share * 100).toStringAsFixed(1)}%',
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(10),
                      child:
                          LinearProgressIndicator(
                        value:
                            share.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor:
                            theme
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(
                                  alpha: 0.08,
                                ),
                        valueColor:
                            const AlwaysStoppedAnimation(
                          LifeTrackColors.coral,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (liabilities.length > 5)
            Text(
              '+ ${liabilities.length - 5} more liabilities',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// LIABILITY CARD
// =============================================================================

class _LiabilityCard extends StatelessWidget {
  const _LiabilityCard({
    required this.liability,
    required this.color,
    required this.icon,
    required this.share,
    required this.peso,
    required this.formatDate,
    required this.onTap,
  });

  final Liability liability;
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
        borderRadius:
            BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(
                        alpha: 0.12,
                      ),
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
                          liability.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          liability.type,
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
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
                        peso(liability.amount),
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                          color:
                              LifeTrackColors.coral,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        '${(share * 100).toStringAsFixed(1)}%',
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 4),

                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(
                    color,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    Icons.update_rounded,
                    size: 13,
                    color: colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.65),
                  ),

                  const SizedBox(width: 5),

                  Text(
                    formatDate(
                      liability.updatedAt,
                    ),
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      fontSize: 11,
                      color: colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.7),
                    ),
                  ),

                  const Spacer(),

                  Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.45),
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

// =============================================================================
// SUMMARY STAT
// =============================================================================

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
          color: LifeTrackColors.coral,
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DETAIL ITEM
// =============================================================================

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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme
              .textTheme
              .bodySmall
              ?.copyWith(
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: theme
              .textTheme
              .bodyMedium
              ?.copyWith(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

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
        padding:
            const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 34,
        ),
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LifeTrackColors.coral
                    .withValues(alpha: 0.10),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 30,
                color: LifeTrackColors.coral,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'No debts tracked',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'You currently have no liabilities recorded. '
              'If you owe money, add it here to keep your '
              'net worth accurate.',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Add liability',
              ),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    LifeTrackColors.coral,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ERROR STATE
// =============================================================================

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
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.error
                    .withValues(alpha: 0.10),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color:
                    colorScheme.error,
                size: 28,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Unable to load your liabilities',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Something went wrong while loading '
              'your debt records.',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 14),

            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try again',
              ),
              style:
                  TextButton.styleFrom(
                foregroundColor:
                    LifeTrackColors.coral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}