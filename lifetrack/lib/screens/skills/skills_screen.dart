// ============================================================================
// Skills Screen — fully self-contained, delete fully wired.
// ----------------------------------------------------------------------------
// Delete flow:
//   Detail sheet → "Delete skill" → confirm dialog → card animates out →
//   _goalService.deleteSkill(id) → list reloads → snackbar.
//
// Requires GoalService.deleteSkill(int id) to exist (one-line wrapper
// around the repo's existing delete):
//
//   Future<void> deleteSkill(int id) => _skillRepo.delete(id);
//
// Everything else — add, save progress, animated progress bar, shimmer,
// stagger — is already wired.
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/skill.dart';
import '../../services/goal_service.dart';
import '../../theme/app_theme.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen>
    with TickerProviderStateMixin {
  final _goalService = GoalService();

  List<Skill>? _skills;
  bool _loading = true;
  Object? _error;

  final Map<int, AnimationController> _cardAnims = {};
  AnimationController? _listReveal;

  @override
  void initState() {
    super.initState();
    _listReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _load();
  }

  @override
  void dispose() {
    for (final c in _cardAnims.values) {
      c.dispose();
    }
    _cardAnims.clear();
    _listReveal?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = _skills == null);
    try {
      final skills = await _goalService.getSkills();
      if (!mounted) return;
      setState(() {
        _skills = skills;
        _loading = false;
        _error = null;
      });
      _listReveal?.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _quietReload() async {
    try {
      final skills = await _goalService.getSkills();
      if (!mounted) return;
      setState(() {
        _skills = skills;
        _error = null;
      });
      _listReveal?.forward(from: 0);
    } catch (_) {}
  }

  // ==========================================================================
  // Add
  // ==========================================================================

  Future<void> _openAddSkillSheet() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _AddSkillSheet(),
    );
    if (name == null || !mounted) return;

    try {
      await _goalService.createSkill(name);
      if (!mounted) return;
      await _quietReload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" added to your skills.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save skill.')),
      );
    }
  }

  // ==========================================================================
  // Save progress — newProgress is in Skill's native 0..target space.
  // ==========================================================================

  Future<void> _saveProgress(Skill skill, double newProgress) async {
    try {
      await _goalService.updateSkillProgress(skill, newProgress);
      if (!mounted) return;
      await _quietReload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update progress.')),
      );
    }
  }

  // ==========================================================================
  // Delete — full flow wired to GoalService.deleteSkill.
  // ==========================================================================

  Future<void> _deleteSkillAt(int index, Skill skill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(skillName: skill.name),
    );
    if (ok != true || !mounted) return;

    // Play the card's exit animation first.
    final c = _cardAnims[index];
    if (c != null) await c.reverse();
    if (!mounted) return;

    final id = skill.id;
    if (id == null) {
      _cardAnims[index]?.forward();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: skill has no id.')),
      );
      return;
    }

    try {
      await _goalService.deleteSkill(id);
      if (!mounted) return;
      await _quietReload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${skill.name}" deleted.')),
      );
    } catch (_) {
      // Delete failed — bring the card back so the list stays in sync.
      _cardAnims[index]?.forward();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete skill.')),
      );
    }
  }

  // ==========================================================================
  // Build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
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
                      Text('Skills',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Track what you\u2019re learning.',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Material(
                  color: s.accent,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _openAddSkillSheet,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 18, color: s.onAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Add',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: s.onAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('MY SKILLS', style: theme.textTheme.labelSmall),
            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorCard(context)
            else if ((_skills ?? const []).isEmpty)
              _emptyCard(context)
            else
              _skillsList(context, _skills!),
          ],
        ),
      ),
    );
  }

  Widget _skillsList(BuildContext context, List<Skill> skills) {
    _cardAnims.removeWhere((index, c) {
      if (index >= skills.length) {
        c.dispose();
        return true;
      }
      return false;
    });
    for (var i = 0; i < skills.length; i++) {
      _cardAnims.putIfAbsent(
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
        for (int i = 0; i < skills.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedBuilder(
              animation: _cardAnims[i]!,
              builder: (context, child) {
                final t = _cardAnims[i]!.value;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 16),
                    child: child,
                  ),
                );
              },
              child: _SkillCard(
                skill: skills[i],
                color: _cardColor(context, i),
                onTap: () => _openDetail(
                  i,
                  skills[i],
                  _cardColor(context, i),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openDetail(int index, Skill skill, Color color) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SkillDetailSheet(
        skill: skill,
        color: color,
        onSave: (p) => _saveProgress(skill, p),
        onDelete: () => _deleteSkillAt(index, skill),
      ),
    );
  }

  Color _cardColor(BuildContext context, int index) {
    final s = context.season;
    final palette = <Color>[
      s.accent,
      LifeTrackColors.mint,
      LifeTrackColors.coral,
    ];
    return palette[index % palette.length];
  }

  Widget _emptyCard(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return _InlineCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Center(
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
                child: Icon(Icons.school_outlined,
                    size: 30, color: s.accentText),
              ),
              const SizedBox(height: 16),
              Text(
                'No skills tracked yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a skill to start tracking your progress.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _openAddSkillSheet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add your first skill'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    final theme = Theme.of(context);

    return _InlineCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded,
                  color: theme.textTheme.bodyMedium?.color, size: 32),
              const SizedBox(height: 8),
              Text('Unable to load skills.',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Local card surface
// ============================================================================

class _InlineCard extends StatelessWidget {
  const _InlineCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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

// ============================================================================
// Animated progress bar with shimmer
// ============================================================================

class _SkillProgressBar extends StatelessWidget {
  const _SkillProgressBar({
    required this.value,
    required this.color,
    this.height = 8,
    this.showShimmer = true,
  });

  /// 0.0 to 1.0.
  final double value;
  final Color color;
  final double height;
  final bool showShimmer;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(
            children: [
              Container(
                height: height,
                width: double.infinity,
                color: color.withValues(alpha: 0.14),
              ),
              FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.85),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
              if (showShimmer && v > 0 && v < 1)
                Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: v,
                    alignment: Alignment.centerLeft,
                    child: _ShimmerOverlay(height: height),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerOverlay extends StatefulWidget {
  const _ShimmerOverlay({required this.height});
  final double height;

  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (rect) {
            final shimmerX = _c.value * rect.width * 1.5;
            return LinearGradient(
              colors: const [
                Colors.transparent,
                Colors.white,
                Colors.transparent,
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlideGradient(shimmerX),
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.height),
            ),
          ),
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

// ============================================================================
// Skill card
// ============================================================================

class _SkillCard extends StatefulWidget {
  const _SkillCard({
    required this.skill,
    required this.color,
    required this.onTap,
  });
  final Skill skill;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<_SkillCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
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
    final percent = (widget.skill.percent * 100).round();

    return ScaleTransition(
      scale: _tap,
      child: _InlineCard(
        child: InkWell(
          borderRadius:
              BorderRadius.circular(LifeTrackMetrics.cardRadius - 4),
          onTap: _handleTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.school_rounded,
                        size: 20, color: widget.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.skill.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$percent% complete',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 12),
              _SkillProgressBar(
                value: widget.skill.percent,
                color: widget.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Add skill sheet
// ============================================================================

class _AddSkillSheet extends StatefulWidget {
  const _AddSkillSheet();

  @override
  State<_AddSkillSheet> createState() => _AddSkillSheetState();
}

class _AddSkillSheetState extends State<_AddSkillSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a skill name');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
                      color: s.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.school_rounded,
                        size: 24, color: s.accentText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New skill',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text('What do you want to learn?',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('SKILL NAME', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Flutter, Spanish, Guitar',
                  errorText: _error,
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Add skill'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Skill detail sheet — works in Skill.progress's native 0..target space
// ============================================================================

class _SkillDetailSheet extends StatefulWidget {
  const _SkillDetailSheet({
    required this.skill,
    required this.color,
    required this.onSave,
    required this.onDelete,
  });

  final Skill skill;
  final Color color;
  final Future<void> Function(double) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_SkillDetailSheet> createState() => _SkillDetailSheetState();
}

class _SkillDetailSheetState extends State<_SkillDetailSheet> {
  late double _draft;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.skill.progress;
  }

  Future<void> _save() async {
    if (_busy) return;
    if ((_draft - widget.skill.progress).abs() < 0.001) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    await widget.onSave(_draft);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    Navigator.of(context).pop();
    await widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);
    final color = widget.color;
    final target = widget.skill.target <= 0 ? 100.0 : widget.skill.target;
    final fraction = (_draft / target).clamp(0.0, 1.0);
    final changed = (_draft - widget.skill.progress).abs() >= 0.001;

    return SafeArea(
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
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.school_rounded, size: 24, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.skill.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(widget.skill.percent * 100).round()}% complete',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                      Expanded(
                        child: Text('Progress',
                            style: theme.textTheme.labelSmall),
                      ),
                      Text(
                        '${_draft.round()} / ${target.round()}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SkillProgressBar(
                    value: fraction,
                    color: color,
                    height: 10,
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: color,
                      thumbColor: color,
                      overlayColor: color.withValues(alpha: 0.15),
                      inactiveTrackColor: color.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: _draft.clamp(0.0, target),
                      min: 0,
                      max: target,
                      divisions: (target / 5).round().clamp(1, 100),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _draft = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0', style: theme.textTheme.labelSmall),
                      Text(target.round().toString(),
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || !changed ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_busy ? 'Saving…' : 'Save progress'),
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: LifeTrackColors.coral.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _busy ? null : _delete,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: LifeTrackColors.coral
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 18, color: LifeTrackColors.coral),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Delete skill',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: LifeTrackColors.coral),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: LifeTrackColors.coral
                              .withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Confirm dialog
// ============================================================================

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.skillName});
  final String skillName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.delete_outline_rounded,
          size: 32, color: LifeTrackColors.coral),
      title: const Text('Delete skill?'),
      content: Text(
        'This will remove "$skillName" from your skills list. '
        'This cannot be undone.',
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
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
