import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A list of season choices (Auto, Tag-init, Tag-ulan, Amihan, Classic).
/// Drop it into Settings > Appearance:   const SeasonPicker()
/// Tapping a row changes the whole app's colors immediately and remembers it.
class SeasonPicker extends StatelessWidget {
  const SeasonPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SeasonMode>(
      valueListenable: SeasonController.mode,
      builder: (context, current, _) {
        return Column(
          children: [
            for (final mode in SeasonMode.values)
              ListTile(
                leading: _ColorDot(
                  color: SeasonController.paletteFor(mode).accent,
                ),
                title: Text(mode.label),
                subtitle: Text(mode.subtitle),
                trailing: mode == current
                    ? Icon(Icons.check_rounded, color: context.season.accentText)
                    : null,
                onTap: () => SeasonController.setMode(mode),
              ),
          ],
        );
      },
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }
}
