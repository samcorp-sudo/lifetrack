// ============================================================================
// Notifications Screen
// ============================================================================
//
// WHAT THIS SCREEN DOES
// ----------------------------------------------------------------------------
// Shows the list of notifications the app has generated (task reminders,
// bill reminders, goal progress, etc.). Users can:
//   • Tap a notification to mark it read.
//   • Swipe left, or tap the X, to delete one notification.
//   • Use the top-right menu to "Mark all as read" or "Clear all".
//
// Notifications are grouped into two sections:
//   • NEW     — unread notifications (shown first)
//   • EARLIER — already-read notifications
// If there is nothing to show, an empty-state card appears instead.
//
// LOADING LOGGING (temporary)
// ----------------------------------------------------------------------------
// `_load()` now prints diagnostics to the console:
//     NOTIF _load: start
//     NOTIF _load: got N items        (success)
//     NOTIF _load: TIMEOUT            (repository hung)
//     NOTIF _load: ERROR <e>          (threw)
// It also wraps the repository call in `.timeout(5s)` so a broken or
// un-opened DB can't leave the spinner up forever.
//
// Remove the debugPrint lines once the loading problem is fixed — they're
// noisy. Keep the `.timeout(...)` — it's cheap insurance.
//
// THE FLUTTER SEMANTICS BUG — READ THIS BEFORE EDITING
// ----------------------------------------------------------------------------
// This file works around a bug in the Flutter framework (Flutter 3.41+)
// where the following assertion fires, often every frame, when a widget's
// child count or child type changes between builds:
//
//     'package:flutter/src/rendering/object.dart':
//     Failed assertion: line ~5724 pos 14:
//     '!semantics.parentDataDirty': is not true.
//
// The fix is to keep the widget tree STRUCTURALLY IDENTICAL between builds
// — same number of children, same child types, same order. You change the
// CONTENT of each slot, never the shape of the tree.
//
// What that means here:
//
//   1. The scroll view is a SingleChildScrollView with exactly ONE child:
//        a Column.
//
//   2. That Column always contains `_slotCeiling` children. The ceiling
//      only GROWS, never shrinks — even after delete, the removed slot is
//      reused as SizedBox.shrink() so the tree shape is unchanged.
//
//   3. Each slot is either a header ("NEW" / "EARLIER") or a notification
//      tile — but the SLOT is always present.
//
//   4. Do NOT refactor this into ListView.builder with a changing
//      `itemCount`, or a Column with `if (unread.isNotEmpty)...[ ]`, or
//      any loop whose length depends on data. All of those reintroduce
//      the assertion.
//
//   5. If you upgrade to a Flutter version where the assertion is patched,
//      delete the fixed-slot workaround and write the obvious loop:
//        for (final n in _notifications) _NotificationCard(...)
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../repositories/notification_repository.dart';
import '../../services/notification_center.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------
  final _repository = NotificationRepository();

  List<AppNotification> _notifications = const [];
  bool _loading = true;
  Object? _error;

  /// Only grows — see file header, point 2.
  int _slotCeiling = 0;

  final Map<int, AnimationController> _tileAnims = {};

  @override
  void initState() {
    super.initState();
    debugPrint('NOTIF initState');
    _load();
  }

  @override
  void dispose() {
    for (final c in _tileAnims.values) {
      c.dispose();
    }
    _tileAnims.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    debugPrint('NOTIF _load: start');
    if (_notifications.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      // `.timeout(...)` prevents an infinite spinner if the repository
      // hangs (e.g. DB not opened, missing table, awaiting forever).
      final all = await _repository
          .getNotifications()
          .timeout(const Duration(seconds: 5));
      debugPrint('NOTIF _load: got ${all.length} items');
      if (!mounted) return;
      setState(() {
        _notifications = all;
        _loading = false;
        _error = null;
      });
    } on TimeoutException catch (e) {
      debugPrint('NOTIF _load: TIMEOUT $e');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('NOTIF _load: ERROR $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _reloadNotifications() async {
    for (final c in _tileAnims.values) {
      c.dispose();
    }
    _tileAnims.clear();
    await _load();
    if (mounted) NotificationCenter.instance.refreshUnread();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> _markAsRead(AppNotification n) async {
    if (n.id == null || n.isRead) return;
    await _repository.markAsRead(n.id!);
    await _reloadNotifications();
  }

  Future<void> _deleteNotification(AppNotification n) async {
    if (n.id == null) return;
    await _repository.deleteNotification(n.id!);
    await _reloadNotifications();
  }

  Future<void> _markAllAsRead() async {
    await _repository.markAllAsRead();
    await _reloadNotifications();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmClearAllDialog(),
    );
    if (confirmed != true) return;
    await _repository.clearAll();
    await _reloadNotifications();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notifications'),
        actions: [_menu(context, s)],
      ),
      body: _buildBody(context),
    );
  }

  Widget _menu(BuildContext context, SeasonColors s) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: s.accentText),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onSelected: (value) {
        if (value == 'mark_all_read') _markAllAsRead();
        if (value == 'clear_all') _clearAll();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'mark_all_read',
          child: Row(
            children: [
              Icon(Icons.mark_email_read_outlined,
                  size: 18, color: s.accentText),
              const SizedBox(width: 10),
              const Text('Mark all as read'),
            ],
          ),
        ),
       const PopupMenuItem(
          value: 'clear_all',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18, color: LifeTrackColors.coral),
               SizedBox(width: 10),
               Text('Clear all'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(onRetry: _load);
    }
    if (_notifications.isEmpty) {
      return const _EmptyState();
    }

    final unread = _notifications.where((n) => !n.isRead).toList();
    final read = _notifications.where((n) => n.isRead).toList();

    final rows = <_Row>[
      if (unread.isNotEmpty) _Row.header('NEW', unread.length),
      for (final n in unread) _Row.notification(n),
      if (read.isNotEmpty) _Row.header('EARLIER', read.length),
      for (final n in read) _Row.notification(n),
    ];

    _slotCeiling = math.max(_slotCeiling, rows.length);

    for (int i = 0; i < _slotCeiling; i++) {
      _tileAnims.putIfAbsent(
        i,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 380),
        )..forward(),
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadNotifications,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _slotCeiling; i++)
              if (i < rows.length)
                _buildRow(context, i, rows[i])
              else
                const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index, _Row row) {
    if (row.isHeader) {
      return _staggerWrap(
        index,
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: _SectionLabel(label: row.label!, count: row.count),
        ),
      );
    }

    final n = row.notification!;
    return _staggerWrap(
      index,
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Dismissible(
          key: ValueKey(n.id ?? n.timestamp.toIso8601String()),
          direction: DismissDirection.endToStart,
          background: const _DeleteBackground(),
          onDismissed: (_) => _deleteNotification(n),
          child: _NotificationCard(
            notification: n,
            onTap: () => _markAsRead(n),
            onDelete: () => _deleteNotification(n),
          ),
        ),
      ),
    );
  }

  Widget _staggerWrap(int index, Widget child) {
    final c = _tileAnims[index];
    if (c == null) return child;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

// ============================================================================
// Data model for one fixed-slot row
// ============================================================================

class _Row {
  const _Row._({
    required this.isHeader,
    this.label,
    this.count,
    this.notification,
  });

  factory _Row.header(String label, int count) =>
      _Row._(isHeader: true, label: label, count: count);

  factory _Row.notification(AppNotification n) =>
      _Row._(isHeader: false, notification: n);

  final bool isHeader;
  final String? label;
  final int? count;
  final AppNotification? notification;
}

// ============================================================================
// Section label ("NEW 3" / "EARLIER 5")
// ============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.count});
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: s.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: s.accentText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// Delete background shown behind a Dismissible row
// ============================================================================

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: LifeTrackColors.coral.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.delete_outline_rounded,
          color: LifeTrackColors.coral, size: 22),
    );
  }
}

// ============================================================================
// Notification card — self-contained, press-scale, unread highlight
// ============================================================================

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
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
    final n = widget.notification;
    final unread = !n.isRead;

    return ScaleTransition(
      scale: _tap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: unread
                  ? s.accent.withValues(alpha: 0.06)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: unread
                    ? s.accent.withValues(alpha: 0.25)
                    : theme.dividerColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: unread ? 3 : 0,
                    color: s.accent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _IconChip(icon: n.type.icon),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TitleRow(
                                  title: n.title,
                                  unread: unread,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  n.body,
                                  style: theme.textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatRelative(n.timestamp),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _DismissButton(onTap: widget.onDelete),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.month}/${t.day}';
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: s.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: s.accentText),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title, required this.unread});
  final String title;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (unread) ...[
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: s.accent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close_rounded,
          size: 16,
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

// ============================================================================
// Empty / error states
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_off_rounded,
                  size: 34, color: s.accentText),
            ),
            const SizedBox(height: 18),
            Text(
              'You\u2019re all caught up',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Reminders about your tasks, bills and schedule will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 16),
            Text('Unable to load notifications',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Confirm clear-all
// ============================================================================

class _ConfirmClearAllDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded,
          size: 32, color: LifeTrackColors.coral),
      title: const Text('Clear all notifications?'),
      content: const Text(
        'Every notification will be removed. This cannot be undone.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: LifeTrackColors.coral,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear all'),
        ),
      ],
    );
  }
}
