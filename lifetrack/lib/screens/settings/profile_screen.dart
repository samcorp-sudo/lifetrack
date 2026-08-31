// ============================================================================
// Profile Screen
// ----------------------------------------------------------------------------
// CHANGES IN THIS VERSION:
// - Redesigned header: larger avatar with a soft ring, name + email grouped
//   together, and a tappable PLAN BADGE ("Free" / "Basic" / "Pro" etc.)
//   sitting right under the name — matches the tinted-chip visual language
//   used on the Schedule/Settings/Money screens.
// - Tapping the plan badge opens a bottom sheet with plan details: current
//   tier, renewal/expiry info, feature list, and an upgrade/manage action.
// - Info rows restyled as tinted icon-chip list items (consistent with the
//   rest of the app) instead of default Card/ListTile styling.
// - Edit name and sign out actions kept, restyled slightly.
//
// TODO(backend): Account plan/subscription data is NOT wired to a real
// source yet. This screen currently uses a local placeholder
// (`_PlanInfo.placeholder`) so the UI is fully functional to design/demo
// against. To connect it for real:
//   1. Add a method on ProfileService (or a new SubscriptionService) that
//      returns the user's current plan, e.g.
//      `Future<PlanInfo> getCurrentPlan()` — sourced from wherever your
//      billing lives (Firestore custom field, RevenueCat, Stripe customer
//      portal, Play Billing / App Store subscription status, etc).
//   2. Replace `_planFuture = Future.value(_PlanInfo.placeholder(...))`
//      in initState() with the real call.
//   3. Replace `_PlanInfo` below with your actual plan model, or map your
//      model into this shape (tier, priceLabel, renewsOn, features,
//      isActive).
//   4. Wire `_onManagePlan()` to whatever your upgrade/manage flow is
//      (e.g. push a paywall screen, open RevenueCat's manageSubscriptions,
//      or launch the platform's subscription-management URL).
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _avatarRadius = 40;
  static const double _sectionGap = 24;
  static const double _rowGap = 10;
  static const double _iconChipSize = 40;

  final _service = ProfileService();
  late Future<User?> _profileFuture;

  // TODO(backend): replace with a real fetch — see file header note.
  late Future<_PlanInfo> _planFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _service.getCurrentProfile();
    // TODO(backend): swap this placeholder for e.g.
    // _planFuture = _subscriptionService.getCurrentPlan();
    _planFuture = Future.value(_PlanInfo.placeholder());
  }

  Future<void> _editDisplayName(User user) async {
    final controller = TextEditingController(text: user.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
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

  Future<void> _signOut() async {
    await _service.signOut();
    if (mounted) {
      Navigator.of(context).pop();
    }
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

  // TODO(backend): hook this up to your real upgrade/manage-subscription
  // flow (paywall screen, RevenueCat manageSubscriptions(), platform
  // subscription settings URL, etc). Currently just shows a placeholder
  // snackbar so the tap target is functional end-to-end.
  void _onManagePlan(_PlanInfo plan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(plan.tier == _PlanTier.pro
            ? 'TODO: open manage-subscription flow'
            : 'TODO: open upgrade/paywall flow'),
      ),
    );
  }

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
          if (user == null) {
            return const Center(child: Text('No signed-in user.'));
          }
          return ListView(
            padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
            children: [
              _profileHeader(context, user),
              const SizedBox(height: _sectionGap),
              Text('Account', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: _rowGap),
              _infoRow(context, 'Email', user.email ?? 'Not available',
                  Icons.email_outlined),
              _infoRow(context, 'User ID', user.uid, Icons.fingerprint_rounded),
              _infoRow(
                  context,
                  'Provider',
                  user.providerData
                      .map((provider) => provider.providerId)
                      .join(', '),
                  Icons.verified_user_outlined),
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
              const SizedBox(height: _sectionGap),
              FilledButton.icon(
                  onPressed: () => _editDisplayName(user),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit name')),
              const SizedBox(height: 12),
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

  Widget _profileHeader(BuildContext context, User user) {
    return Column(
      children: [
        CircleAvatar(
          radius: _avatarRadius,
          backgroundColor: LifeTrackColors.highlight.withValues(alpha: 0.16),
          child: Text(_initials(user),
              style: Theme.of(context).textTheme.headlineMedium),
        ),
        const SizedBox(height: 14),
        Text(user.displayName ?? 'LifeTrack user',
            style: Theme.of(context).textTheme.titleLarge),
        if (user.email != null) ...[
          const SizedBox(height: 2),
          Text(user.email!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        FutureBuilder<_PlanInfo>(
          future: _planFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 28,
                width: 90,
                child: Center(
                  child: SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return _planBadge(context, snapshot.data!);
          },
        ),
      ],
    );
  }

  Widget _planBadge(BuildContext context, _PlanInfo plan) {
    final color = plan.badgeColor;
    return GestureDetector(
      onTap: () => _showPlanDetails(plan),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(plan.icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              plan.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, String label, String value, IconData icon) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: _rowGap),
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
// Plan details bottom sheet
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
            // TODO(backend): route this to a real upgrade/manage flow —
            // see `_onManagePlan()` in ProfileScreen.
            FilledButton.icon(
              onPressed: onManage,
              icon: Icon(plan.tier == _PlanTier.pro
                  ? Icons.settings_rounded
                  : Icons.upgrade_rounded),
              label: Text(plan.tier == _PlanTier.pro
                  ? 'Manage subscription'
                  : 'Upgrade plan'),
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
// Plan model (placeholder)
// ----------------------------------------------------------------------------
// TODO(backend): Replace this entire class with your real plan/subscription
// model once billing is wired up, or map your real model into this shape.
// ============================================================================
enum _PlanTier { free, basic, pro }

class _PlanInfo {
  const _PlanInfo({
    required this.tier,
    required this.label,
    required this.icon,
    required this.badgeColor,
    required this.isActive,
    this.priceLabel,
    // ignore: unused_element_parameter
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

  // TODO(backend): this placeholder always returns "Free". Replace with a
  // real fetch (see ProfileScreen.initState) that reflects the signed-in
  // user's actual subscription tier — e.g. read a Firestore field,
  // RevenueCat entitlement, or platform receipt status.
  factory _PlanInfo.placeholder() => const _PlanInfo(
        tier: _PlanTier.free,
        label: 'Free',
        icon: Icons.circle_outlined,
        badgeColor: LifeTrackColors.highlight,
        isActive: true,
        priceLabel: '\$0 / month',
        features: [
          'Basic schedule & task tracking',
          'Up to 1 active plan',
          'Community support',
        ],
      );
}
