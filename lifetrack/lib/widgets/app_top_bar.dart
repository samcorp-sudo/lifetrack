import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/notifications/notifications_screen.dart';
import '../screens/settings/profile/profile_screen.dart';
import '../services/notification_center.dart';
import '../theme/app_theme.dart';

/// Top row shared by screens: app name, notification bell with an unread
/// badge, and the profile avatar (initials from the signed-in user).
class AppTopBar extends StatefulWidget {
  const AppTopBar({super.key, this.title = 'LifeTrack'});

  final String title;

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    NotificationCenter.instance.refreshUnread();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    // The name may have changed on the profile screen.
    if (mounted) setState(() {});
  }

  // "Juan Mendoza" -> "JM", "Maria" -> "M", empty -> "?"
  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineMedium,
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
        const SizedBox(width: 4),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: _openProfile,
          child: CircleAvatar(
            backgroundColor: s.accent,
            radius: 20,
            child: Text(
              _initials(displayName),
              style: TextStyle(
                color: s.onAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
