import 'package:buddy/app_theme.dart';
import 'package:buddy/models/workout_session_history.dart';
import 'package:buddy/services/workout_service.dart';
import 'package:buddy/widgets/app_buttons.dart';
import 'package:buddy/widgets/app_card.dart';
import 'package:buddy/widgets/app_empty_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkoutSessionsPage extends StatefulWidget {
  const WorkoutSessionsPage({super.key});

  @override
  State<WorkoutSessionsPage> createState() => _WorkoutSessionsPageState();
}

class _WorkoutSessionsPageState extends State<WorkoutSessionsPage> {
  static const List<_RangeOption> _rangeOptions = [
    _RangeOption(value: '30d', label: '30D', title: 'Last 30 days'),
    _RangeOption(value: '90d', label: '90D', title: 'Last 90 days'),
    _RangeOption(value: 'all', label: 'ALL', title: 'All time'),
  ];

  String _range = '30d';
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  WorkoutSessionHistoryData? _history;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({String? range}) async {
    final nextRange = range ?? _range;
    final hasExistingData = _history != null;
    final requestToken = ++_requestToken;

    if (mounted) {
      setState(() {
        _range = nextRange;
        _error = null;
        if (hasExistingData) {
          _isRefreshing = true;
        } else {
          _isLoading = true;
        }
      });
    }

    try {
      final history = await WorkoutService.getWorkoutSessionHistory(
        range: nextRange,
      );
      if (!mounted || requestToken != _requestToken) return;
      setState(() {
        _history = history;
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
      });
    } catch (err) {
      if (!mounted || requestToken != _requestToken) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _error = _cleanError(err.toString());
      });
    }
  }

  void _onSelectRange(String value) {
    if ((_isLoading || _isRefreshing) && value == _range) return;
    if (value == _range && _history != null) return;
    _loadHistory(range: value);
  }

  String _cleanError(String raw) {
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return remainingSeconds == 0
          ? '${minutes}m'
          : '${minutes}m ${remainingSeconds}s';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
  }

  String _formatCompactNumber(num value) {
    if (value.abs() >= 1000000) {
      final compact = value / 1000000;
      return compact % 1 == 0
          ? '${compact.toStringAsFixed(0)}M'
          : '${compact.toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      final compact = value / 1000;
      return compact % 1 == 0
          ? '${compact.toStringAsFixed(0)}k'
          : '${compact.toStringAsFixed(1)}k';
    }
    return value.round().toString();
  }

  String _formatSessionsPerWeek(double value) {
    if (value == 0) return '0';
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  String _formatPercent(double fraction) {
    return '${(fraction * 100).round()}%';
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${weekdays[parsed.weekday - 1]}, ${parsed.day} ${months[parsed.month - 1]}';
  }

  Color _sessionAccentColor(String dayLabel) {
    final key = dayLabel.toLowerCase();
    if (key.contains('push') || key.contains('chest')) {
      return AppTheme.muscleChest;
    }
    if (key.contains('pull') || key.contains('back')) {
      return AppTheme.muscleBack;
    }
    if (key.contains('legs') || key.contains('lower')) {
      return AppTheme.muscleLegs;
    }
    if (key.contains('shoulder')) {
      return AppTheme.muscleShoulders;
    }
    if (key.contains('arms') ||
        key.contains('bicep') ||
        key.contains('tricep')) {
      return AppTheme.muscleArms;
    }
    if (key.contains('core') || key.contains('full')) {
      return AppTheme.xpGold;
    }
    return AppTheme.primary;
  }

  WorkoutSessionHistoryPoint? _peakPoint(
    List<WorkoutSessionHistoryPoint> points,
  ) {
    if (points.isEmpty) return null;
    var peak = points.first;
    for (final point in points.skip(1)) {
      if (point.value > peak.value) peak = point;
    }
    return peak;
  }

  String _rangeTitle(String range) {
    return _rangeOptions
        .firstWhere(
          (option) => option.value == range,
          orElse: () => _rangeOptions.first,
        )
        .title;
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _history != null;

    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading && !hasData
                  ? _buildLoadingState()
                  : !hasData && _error != null
                  ? _buildErrorState()
                  : _buildContent(_history!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBackButton(onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workout Sessions',
                      style: AppTheme.displayStyle(fontSize: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _isRefreshing
                    ? const SizedBox(
                        key: ValueKey('refreshing'),
                        width: AppTheme.minimumTouchTarget,
                        height: AppTheme.minimumTouchTarget,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('idle'),
                        width: AppTheme.minimumTouchTarget,
                        height: AppTheme.minimumTouchTarget,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _rangeOptions.length; i++) ...[
                  _RangeChip(
                    label: _rangeOptions[i].label,
                    selected: _range == _rangeOptions[i].value,
                    onPressed: () => _onSelectRange(_rangeOptions[i].value),
                  ),
                  if (i != _rangeOptions.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppCard(
            borderColor: AppTheme.error.withValues(alpha: 0.28),
            colors: const [
              Color(0xFF191214),
              Color(0xFF141417),
              AppTheme.cardDark,
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.circle_alert,
                  color: AppTheme.error,
                  size: 24,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not load session history',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Unknown error',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                AppPrimaryButton(
                  label: 'Retry',
                  onPressed: () => _loadHistory(),
                  icon: LucideIcons.refresh_cw,
                  minHeight: 50,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(WorkoutSessionHistoryData history) {
    final hasSessions = history.summary.totalSessions > 0;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 24;

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.cardDark,
      onRefresh: () => _loadHistory(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: _InlineErrorBanner(
                  message: _error!,
                  onRetry: () => _loadHistory(),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: _OverviewCard(
                rangeTitle: _rangeTitle(history.range),
                summary: history.summary,
                formatDuration: _formatDuration,
                formatCompactNumber: _formatCompactNumber,
                formatPercent: _formatPercent,
                formatSessionsPerWeek: _formatSessionsPerWeek,
              ),
            ),
          ),
          if (hasSessions)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: _buildCharts(history),
              ),
            ),
          if (!hasSessions)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset),
                child: SizedBox(
                  height: 280,
                  child: AppCard(
                    child: const AppEmptyState(
                      icon: LucideIcons.dumbbell,
                      title: 'No completed sessions yet',
                      subtitle:
                          'Complete a workout and Buddy will chart your load, time, and cadence here.',
                    ),
                  ),
                ),
              ),
            ),
          if (hasSessions)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                child: _SectionHeader(
                  title: 'Session log',
                  subtitle:
                      history.summary.totalSessions > history.sessions.length
                      ? 'Showing the latest ${history.sessions.length} of ${history.summary.totalSessions} sessions'
                      : '${history.sessions.length} completed sessions',
                ),
              ),
            ),
          if (hasSessions)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final session = history.sessions[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == history.sessions.length - 1 ? 0 : 12,
                    ),
                    child: _SessionHistoryCard(
                      session: session,
                      accentColor: _sessionAccentColor(session.dayLabel),
                      formatDate: _formatDate,
                      formatDuration: _formatDuration,
                      formatCompactNumber: _formatCompactNumber,
                    ),
                  );
                }, childCount: history.sessions.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharts(WorkoutSessionHistoryData history) {
    final volumePeak = _peakPoint(history.series.volume);
    final durationPeak = _peakPoint(history.series.duration);
    final frequencyPeak = _peakPoint(history.series.frequency);
    final bucketLabel = history.meta.bucketLabel.toLowerCase();

    final cards = [
      _TrendCard(
        title: 'Training load',
        eyebrow: history.meta.bucketLabel,
        value: _formatCompactNumber(history.summary.totalVolume),
        detail: volumePeak == null
            ? 'Load increases as you complete more work.'
            : 'Peak ${_formatCompactNumber(volumePeak.value)} on ${volumePeak.label}',
        accentColor: AppTheme.warning,
        points: history.series.volume,
        emptyMessage: 'Complete a couple of sessions to unlock this trend.',
      ),
      _TrendCard(
        title: 'Time spent',
        eyebrow: 'Session duration',
        value: _formatDuration(history.summary.totalDurationSeconds),
        detail: durationPeak == null
            ? 'Average ${_formatDuration(history.summary.avgDurationSeconds)} per session'
            : 'Average ${_formatDuration(history.summary.avgDurationSeconds)} per session. Peak ${_formatDuration(durationPeak.value.round())} on ${durationPeak.label}',
        accentColor: AppTheme.info,
        points: history.series.duration,
        emptyMessage: 'Buddy will plot your completed workout time here.',
      ),
      _TrendCard(
        title: 'Workout cadence',
        eyebrow: 'Consistency',
        value:
            '${_formatSessionsPerWeek(history.summary.avgSessionsPerWeek)}/wk',
        detail: frequencyPeak == null
            ? '${_formatPercent(history.summary.consistencyScore)} of days included a session'
            : '${_formatPercent(history.summary.consistencyScore)} of days included a session. Best $bucketLabel: ${frequencyPeak.value.round()} sessions',
        accentColor: AppTheme.success,
        points: history.series.frequency,
        emptyMessage: 'Cadence appears after you log more than one session.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              cards[2],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _RangeOption {
  final String value;
  final String label;
  final String title;

  const _RangeOption({
    required this.value,
    required this.label,
    required this.title,
  });
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);

    return AppPressable(
      onPressed: onPressed,
      selected: selected,
      semanticsLabel: '$label range filter',
      minHeight: AppTheme.minimumTouchTarget,
      borderRadius: borderRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.actionSurface : AppTheme.cardDark,
        borderRadius: borderRadius,
        border: Border.all(
          color: selected
              ? AppTheme.textMain.withValues(alpha: 0.35)
              : AppTheme.borderDark,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: selected ? AppTheme.actionForeground : AppTheme.textSageMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String rangeTitle;
  final WorkoutSessionHistorySummary summary;
  final String Function(int seconds) formatDuration;
  final String Function(num value) formatCompactNumber;
  final String Function(double fraction) formatPercent;
  final String Function(double value) formatSessionsPerWeek;

  const _OverviewCard({
    required this.rangeTitle,
    required this.summary,
    required this.formatDuration,
    required this.formatCompactNumber,
    required this.formatPercent,
    required this.formatSessionsPerWeek,
  });

  @override
  Widget build(BuildContext context) {
    final hasSessions = summary.totalSessions > 0;
    final subtitle = !hasSessions
        ? 'Complete a workout and Buddy will start tracking your training rhythm here.'
        : summary.longestStreak > 0
        ? 'You averaged ${formatDuration(summary.avgDurationSeconds)} per workout and logged ${formatSessionsPerWeek(summary.avgSessionsPerWeek)} sessions a week. Best streak: ${summary.longestStreak} days.'
        : 'You averaged ${formatDuration(summary.avgDurationSeconds)} per workout and logged ${formatSessionsPerWeek(summary.avgSessionsPerWeek)} sessions a week.';

    return Semantics(
      container: true,
      label: hasSessions
          ? '$rangeTitle. ${summary.totalSessions} sessions logged. ${formatPercent(summary.consistencyScore)} consistency. ${summary.currentStreak} day streak.'
          : '$rangeTitle. No completed sessions yet.',
      child: AppCard(
        borderColor: AppTheme.warning.withValues(alpha: 0.24),
        colors: const [Color(0xFF201813), Color(0xFF16171A), AppTheme.cardDark],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rangeTitle.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.warning,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Text(
                        hasSessions ? '${summary.totalSessions}' : '0',
                        style: GoogleFonts.sora(
                          color: AppTheme.textCream,
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          hasSessions ? 'sessions' : 'sessions logged',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _StreakBadge(value: summary.currentStreak, label: 'day streak'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textMain,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720 ? 4 : 2;
                const gap = 12.0;
                final itemWidth =
                    (constraints.maxWidth - (gap * (columns - 1))) / columns;

                final stats = [
                  _OverviewStat(
                    label: 'Avg time',
                    value: formatDuration(summary.avgDurationSeconds),
                  ),
                  _OverviewStat(
                    label: 'Consistency',
                    value: formatPercent(summary.consistencyScore),
                  ),
                  _OverviewStat(
                    label: 'Volume',
                    value: formatCompactNumber(summary.totalVolume),
                  ),
                  _OverviewStat(
                    label: 'XP earned',
                    value: '+${formatCompactNumber(summary.totalXpEarned)}',
                  ),
                ];

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final stat in stats)
                      SizedBox(width: itemWidth, child: stat),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;

  const _OverviewStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.sora(
            color: AppTheme.textCream,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int value;
  final String label;

  const _StreakBadge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.oledBlack.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: GoogleFonts.sora(
              color: AppTheme.textCream,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Session history refresh failed. $message',
      child: AppPressable(
        onPressed: onRetry,
        semanticsLabel: 'Retry session history',
        borderRadius: borderRadius,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.errorBg.withValues(alpha: 0.18),
          borderRadius: borderRadius,
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.circle_alert,
              color: AppTheme.error,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMain,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'RETRY',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textCream,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final String eyebrow;
  final String value;
  final String detail;
  final Color accentColor;
  final List<WorkoutSessionHistoryPoint> points;
  final String emptyMessage;

  const _TrendCard({
    required this.title,
    required this.eyebrow,
    required this.value,
    required this.detail,
    required this.accentColor,
    required this.points,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $value. $detail',
      child: AppCard(
        borderColor: accentColor.withValues(alpha: 0.24),
        colors: const [Color(0xFF1A151B), Color(0xFF14161A), AppTheme.cardDark],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: accentColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.sora(
                color: AppTheme.textCream,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            if (points.length < 2)
              SizedBox(
                height: 124,
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Column(
                children: [
                  RepaintBoundary(
                    child: SizedBox(
                      height: 112,
                      child: CustomPaint(
                        painter: _TrendChartPainter(
                          points: points.map((point) => point.value).toList(),
                          color: accentColor,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          points.first.label,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        points.last.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionHistoryCard extends StatelessWidget {
  final WorkoutSessionHistoryItem session;
  final Color accentColor;
  final String Function(String raw) formatDate;
  final String Function(int seconds) formatDuration;
  final String Function(num value) formatCompactNumber;

  const _SessionHistoryCard({
    required this.session,
    required this.accentColor,
    required this.formatDate,
    required this.formatDuration,
    required this.formatCompactNumber,
  });

  @override
  Widget build(BuildContext context) {
    final detailSpecs = [
      (
        icon: LucideIcons.clock_3,
        label: 'Duration',
        value: formatDuration(session.totalDurationSeconds),
      ),
      (
        icon: LucideIcons.dumbbell,
        label: 'Exercises',
        value: '${session.completedExercises}/${session.totalExercises}',
      ),
      (
        icon: LucideIcons.chart_column,
        label: 'Volume',
        value: formatCompactNumber(session.totalVolume),
      ),
      (
        icon: LucideIcons.sparkles,
        label: 'XP',
        value: '+${formatCompactNumber(session.xpEarned)}',
      ),
    ];

    return Semantics(
      container: true,
      label:
          '${session.dayLabel}, ${formatDate(session.date)}. ${formatDuration(session.totalDurationSeconds)}. ${session.completedExercises} of ${session.totalExercises} exercises. Volume ${session.totalVolume}. ${session.xpEarned} XP earned.',
      child: AppCard(
        borderColor: accentColor.withValues(alpha: 0.22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          session.dayLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatDate(session.date),
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.oledBlack.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.xpGold.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '+${formatCompactNumber(session.xpEarned)} XP',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.xpGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 620
                    ? 4
                    : constraints.maxWidth >= 360
                    ? 2
                    : 1;
                const gap = 10.0;
                final itemWidth =
                    (constraints.maxWidth - (gap * (columns - 1))) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final spec in detailSpecs)
                      SizedBox(
                        width: itemWidth,
                        child: _SessionMetric(
                          icon: spec.icon,
                          label: spec.label,
                          value: spec.value,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SessionMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSageMuted, size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _TrendChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minY = points.reduce((a, b) => a < b ? a : b);
    final maxY = points.reduce((a, b) => a > b ? a : b);
    final spread = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY);
    const horizontalInset = 4.0;

    final guidePaint = Paint()
      ..color = AppTheme.borderDark.withValues(alpha: 0.95)
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x =
          horizontalInset +
          (i / (points.length - 1)) * (size.width - (horizontalInset * 2));
      final normalized = (points[i] - minY) / spread;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.04)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final lastIndex = points.length - 1;
    final lastX =
        horizontalInset +
        (lastIndex / (points.length - 1)) *
            (size.width - (horizontalInset * 2));
    final lastNormalized = (points[lastIndex] - minY) / spread;
    final lastY = size.height - (lastNormalized * (size.height - 8)) - 4;

    final outerDotPaint = Paint()..color = color;
    final innerDotPaint = Paint()..color = AppTheme.cardRaised;

    canvas.drawCircle(Offset(lastX, lastY), 5, outerDotPaint);
    canvas.drawCircle(Offset(lastX, lastY), 2.4, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.color != color ||
        !listEquals(oldDelegate.points, points);
  }
}
