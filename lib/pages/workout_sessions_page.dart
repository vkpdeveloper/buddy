import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/services/workout_service.dart';

class WorkoutSessionsPage extends StatefulWidget {
  const WorkoutSessionsPage({super.key});

  @override
  State<WorkoutSessionsPage> createState() => _WorkoutSessionsPageState();
}

class _WorkoutSessionsPageState extends State<WorkoutSessionsPage> {
  String _range = '30d';
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await WorkoutService.getWorkoutSessionHistory(range: _range);
      if (!mounted) return;
      setState(() => _history = res['data'] as Map<String, dynamic>?);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final rem = seconds % 60;
    if (mins < 60) return rem == 0 ? '${mins}m' : '${mins}m ${rem}s';
    final hours = mins ~/ 60;
    final minsOnly = mins % 60;
    return minsOnly == 0 ? '${hours}h' : '${hours}h ${minsOnly}m';
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
    final weekday = weekdays[parsed.weekday - 1];
    final month = months[parsed.month - 1];
    return '$weekday, ${parsed.day} $month';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _error != null
                ? _buildError()
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 16,
        24,
        16,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Go back',
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: const Icon(
                  LucideIcons.chevron_left,
                  color: AppTheme.textCream,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Workout Sessions',
              style: GoogleFonts.sora(
                color: AppTheme.textCream,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circle_alert, color: AppTheme.textSageMuted),
            const SizedBox(height: 10),
            Text(
              'Could not load session history',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadHistory, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _history ?? <String, dynamic>{};
    final summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final series = (data['series'] as Map?)?.cast<String, dynamic>() ?? {};
    final sessions = (data['sessions'] as List?)?.cast<Map>() ?? const [];

    final totalSessions = (summary['totalSessions'] as num?)?.toInt() ?? 0;
    final avgDuration = (summary['avgDurationSeconds'] as num?)?.toInt() ?? 0;
    final totalVolume = (summary['totalVolume'] as num?)?.toInt() ?? 0;
    final consistency = (summary['consistencyScore'] as num?)?.toDouble() ?? 0;

    final volumePoints = _toChartPoints(series['volume']);
    final durationPoints = _toChartPoints(series['duration']);
    final consistencyPoints = _toChartPoints(series['consistency']);

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.cardDark,
      onRefresh: _loadHistory,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Wrap(
                spacing: 8,
                children: [
                  _RangeChip(
                    label: '30D',
                    value: '30d',
                    selected: _range == '30d',
                    onTap: () {
                      setState(() => _range = '30d');
                      _loadHistory();
                    },
                  ),
                  _RangeChip(
                    label: '90D',
                    value: '90d',
                    selected: _range == '90d',
                    onTap: () {
                      setState(() => _range = '90d');
                      _loadHistory();
                    },
                  ),
                  _RangeChip(
                    label: 'ALL',
                    value: 'all',
                    selected: _range == 'all',
                    onTap: () {
                      setState(() => _range = 'all');
                      _loadHistory();
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Sessions',
                      value: '$totalSessions',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'Avg Time',
                      value: _formatDuration(avgDuration),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Volume',
                      value: totalVolume.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: 'Consistency',
                      value: '${(consistency * 100).round()}%',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _ChartCard(
                title: 'Volume trend',
                color: AppTheme.primary,
                points: volumePoints,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: _ChartCard(
                title: 'Duration trend',
                color: AppTheme.chartDuration,
                points: durationPoints,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: _ChartCard(
                title: 'Consistency trend',
                color: AppTheme.xpGold,
                points: consistencyPoints,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Text(
                'History',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (sessions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.paddingOf(context).bottom + 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Text(
                    'No completed sessions in this range yet.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.paddingOf(context).bottom + 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final raw = sessions[index];
                  final item = raw.cast<String, dynamic>();
                  final duration =
                      (item['totalDurationSeconds'] as num?)?.toInt() ?? 0;
                  final volume = (item['totalVolume'] as num?)?.toInt() ?? 0;
                  final completed =
                      (item['completedExercises'] as num?)?.toInt() ?? 0;
                  final total = (item['totalExercises'] as num?)?.toInt() ?? 0;
                  final xp = (item['xpEarned'] as num?)?.toInt() ?? 0;
                  final label = (item['dayLabel'] ?? 'Workout').toString();
                  final dateStr = _formatDate((item['date'] ?? '').toString());
                  return Semantics(
                    label: '$label, $dateStr. Duration ${_formatDuration(duration)}, $completed of $total exercises, volume $volume, +$xp XP.',
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: ExcludeSemantics(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (item['dayLabel'] ?? 'Workout').toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textCream,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              _formatDate((item['date'] ?? '').toString()),
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textSageMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SessionTag(
                              icon: LucideIcons.clock_3,
                              text: _formatDuration(duration),
                            ),
                            _SessionTag(
                              icon: LucideIcons.dumbbell,
                              text: '$completed/$total exercises',
                            ),
                            _SessionTag(
                              icon: LucideIcons.chart_column,
                              text: 'Volume $volume',
                            ),
                            _SessionTag(
                              icon: LucideIcons.sparkles,
                              text: '+$xp XP',
                            ),
                          ],
                        ),
                      ],
                    )),
                    ),
                  );
                }, childCount: sessions.length),
              ),
            ),
        ],
      ),
    );
  }

  List<double> _toChartPoints(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => (entry['value'] as num?)?.toDouble() ?? 0)
        .toList();
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label range filter',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.borderDark,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: selected ? AppTheme.backgroundDark : AppTheme.textSageMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    )),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<double> points;

  const _ChartCard({
    required this.title,
    required this.color,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title chart',
      child: ExcludeSemantics(child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: points.length < 2
                ? Center(
                    child: Text(
                      'Not enough data',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 11,
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: _LineChartPainter(points: points, color: color),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    )),
    );
  }
}

class _SessionTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SessionTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSageMuted, size: 12),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _LineChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final minY = points.reduce((a, b) => a < b ? a : b);
    final maxY = points.reduce((a, b) => a > b ? a : b);
    final spread = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final normalized = (points[i] - minY) / spread;
      final y = size.height - (normalized * (size.height - 6)) - 3;
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
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
