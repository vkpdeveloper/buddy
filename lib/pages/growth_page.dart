import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/body_measurement.dart';
import 'package:buddy/providers/body_provider.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/services/api_client.dart';

// ─── Growth Page ─────────────────────────────────────────────────────────────

class GrowthPage extends ConsumerStatefulWidget {
  const GrowthPage({super.key});

  @override
  ConsumerState<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends ConsumerState<GrowthPage> {
  void _openLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _LogMeasurementSheet(
        onLogged: (result) {
          // Invalidate providers so charts refresh
          ref.invalidate(bodyHistoryProvider);
          ref.invalidate(latestBodyMeasurementProvider);
          ref.invalidate(progressProvider);
          // Show XP celebration
          _showXpCelebration(result);
        },
      ),
    );
  }

  void _showXpCelebration(BodyLogResult result) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _XpCelebrationDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _GrowthHeader(onLogTap: _openLogSheet),

            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                backgroundColor: AppTheme.cardDark,
                onRefresh: () async {
                  ref.invalidate(bodyHistoryProvider);
                  ref.invalidate(latestBodyMeasurementProvider);
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      const _StatsStrip(),
                      const SizedBox(height: 20),
                      _MetricsGrid(),
                      const SizedBox(height: 24),
                      const _HistoryTimeline(),
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

// ─── Header ───────────────────────────────────────────────────────────────────

class _GrowthHeader extends StatelessWidget {
  final VoidCallback onLogTap;
  const _GrowthHeader({required this.onLogTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GROWTH',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                Text(
                  'Body Progress',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLogTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                LucideIcons.plus,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Strip (latest entry quick stats) ───────────────────────────────────

class _StatsStrip extends ConsumerWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestBodyMeasurementProvider);
    final histAsync = ref.watch(bodyHistoryProvider);

    final totalLogs = histAsync.when(
      data: (h) => h.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return latestAsync.when(
      data: (latest) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            _StatChip(
              icon: LucideIcons.clipboard_list,
              label: 'LOGS',
              value: '$totalLogs',
            ),
            const SizedBox(width: 10),
            _StatChip(
              icon: LucideIcons.scale,
              label: 'WEIGHT',
              value: latest?.weightKg != null
                  ? '${latest!.weightKg!.toStringAsFixed(1)} kg'
                  : '—',
            ),
            const SizedBox(width: 10),
            _StatChip(
              icon: LucideIcons.calendar,
              label: 'LAST LOG',
              value: latest != null ? _formatDate(latest.date) : 'Never',
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  String _formatDate(String date) {
    try {
      final parts = date.split('-');
      if (parts.length < 3) return date;
      final months = [
        '',
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
      return '${parts[2]} ${months[int.parse(parts[1])]}';
    } catch (_) {
      return date;
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 12),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Metrics Grid (sparkline tiles) ──────────────────────────────────────────

class _MetricsGrid extends ConsumerWidget {
  final _metrics = const [
    _MetricConfig('Weight', 'kg', LucideIcons.scale, 'weightKg'),
    _MetricConfig('Chest', 'cm', LucideIcons.activity, 'chestCm'),
    _MetricConfig('Waist', 'cm', LucideIcons.minimize_2, 'waistCm'),
    _MetricConfig('Hips', 'cm', LucideIcons.circle, 'hipsCm'),
    _MetricConfig('Arms', 'cm', LucideIcons.dumbbell, 'armsCm'),
    _MetricConfig('Thighs', 'cm', LucideIcons.footprints, 'thighsCm'),
  ];

  _MetricsGrid();

  double? _getValue(BodyMeasurement m, String key) {
    switch (key) {
      case 'weightKg':
        return m.weightKg;
      case 'chestCm':
        return m.chestCm;
      case 'waistCm':
        return m.waistCm;
      case 'hipsCm':
        return m.hipsCm;
      case 'armsCm':
        return m.armsCm;
      case 'thighsCm':
        return m.thighsCm;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(bodyHistoryProvider);
    final history = histAsync.when(
      data: (h) => h,
      loading: () => <BodyMeasurement>[],
      error: (_, __) => <BodyMeasurement>[],
    );
    // history is newest-first, reverse for chart
    final chronological = history.reversed.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEASUREMENTS',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _metrics.length,
            itemBuilder: (_, i) {
              final metric = _metrics[i];
              final dataPoints = chronological
                  .map((m) => _getValue(m, metric.key))
                  .where((v) => v != null)
                  .cast<double>()
                  .toList();

              double? latest;
              double? previous;
              if (dataPoints.length >= 1) latest = dataPoints.last;
              if (dataPoints.length >= 2)
                previous = dataPoints[dataPoints.length - 2];

              double? delta;
              if (latest != null && previous != null) {
                delta = latest - previous;
              }

              return _MetricTile(
                config: metric,
                dataPoints: dataPoints,
                latest: latest,
                delta: delta,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricConfig {
  final String label;
  final String unit;
  final IconData icon;
  final String key;

  const _MetricConfig(this.label, this.unit, this.icon, this.key);
}

class _MetricTile extends StatelessWidget {
  final _MetricConfig config;
  final List<double> dataPoints;
  final double? latest;
  final double? delta;

  const _MetricTile({
    required this.config,
    required this.dataPoints,
    this.latest,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = latest != null;
    Color? deltaColor;
    String? deltaText;
    if (delta != null) {
      // For weight, loss = good (green). For measurements, gain = good.
      final isWeight = config.key == 'weightKg';
      final isPositive = delta! > 0;
      deltaColor = isWeight
          ? (isPositive ? const Color(0xFFE57373) : const Color(0xFF81C784))
          : (isPositive ? AppTheme.primary : const Color(0xFFE57373));
      final sign = isPositive ? '+' : '';
      deltaText = '$sign${delta!.toStringAsFixed(1)} ${config.unit}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasData
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config.icon, color: AppTheme.primary, size: 12),
              const SizedBox(width: 4),
              Text(
                config.label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primary,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (deltaText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: deltaColor!.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    deltaText,
                    style: GoogleFonts.plusJakartaSans(
                      color: deltaColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (hasData)
            Text(
              '${latest!.toStringAsFixed(1)} ${config.unit}',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              '—',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          if (dataPoints.length >= 2)
            SizedBox(
              height: 28,
              child: CustomPaint(
                painter: _SparklinePainter(dataPoints),
                size: Size.infinite,
              ),
            )
          else
            Text(
              dataPoints.isEmpty ? 'No data yet' : 'Log more to see trend',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Sparkline Painter ────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> data;

  _SparklinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = maxV - minV == 0 ? 1.0 : maxV - minV;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minV) / range) * size.height;
      points.add(Offset(x, y));
    }

    // Draw gradient fill
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i - 1].dy,
      );
      final cp2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.primary.withValues(alpha: 0.25),
          AppTheme.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Dot at end
    canvas.drawCircle(points.last, 3, Paint()..color = AppTheme.primary);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.data != data;
}

// ─── History Timeline ─────────────────────────────────────────────────────────

class _HistoryTimeline extends ConsumerWidget {
  const _HistoryTimeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(bodyHistoryProvider);

    return histAsync.when(
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();
        final recent = history.take(10).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECENT LOGS',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              ...recent.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                final isLast = idx == recent.length - 1;
                return _TimelineRow(measurement: m, isLast: isLast);
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final BodyMeasurement measurement;
  final bool isLast;

  const _TimelineRow({required this.measurement, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (measurement.weightKg != null)
      parts.add('${measurement.weightKg!.toStringAsFixed(1)} kg');
    if (measurement.chestCm != null)
      parts.add('Chest ${measurement.chestCm!.toStringAsFixed(0)}');
    if (measurement.waistCm != null)
      parts.add('Waist ${measurement.waistCm!.toStringAsFixed(0)}');
    if (measurement.hipsCm != null)
      parts.add('Hips ${measurement.hipsCm!.toStringAsFixed(0)}');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: AppTheme.borderDark),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          measurement.date,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.xpGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${measurement.xpEarned} XP',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.xpGold,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (parts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: parts
                            .map(
                              (p) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundDark,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textCream,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (measurement.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        measurement.notes,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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

// ─── Log Measurement Sheet (step form) ───────────────────────────────────────

class _LogMeasurementSheet extends StatefulWidget {
  final void Function(BodyLogResult) onLogged;

  const _LogMeasurementSheet({required this.onLogged});

  @override
  State<_LogMeasurementSheet> createState() => _LogMeasurementSheetState();
}

class _LogMeasurementSheetState extends State<_LogMeasurementSheet> {
  final _steps = const [
    _StepConfig(
      'Weight',
      'kg',
      LucideIcons.scale,
      'weightKg',
      'Step on the scale and enter your current weight',
      40,
      200,
    ),
    _StepConfig(
      'Chest',
      'cm',
      LucideIcons.activity,
      'chestCm',
      'Measure around the fullest part of your chest',
      50,
      200,
    ),
    _StepConfig(
      'Waist',
      'cm',
      LucideIcons.minimize_2,
      'waistCm',
      'Measure at your natural waistline, above the navel',
      40,
      200,
    ),
    _StepConfig(
      'Hips',
      'cm',
      LucideIcons.circle,
      'hipsCm',
      'Measure around the widest part of your hips',
      50,
      200,
    ),
    _StepConfig(
      'Arms',
      'cm',
      LucideIcons.dumbbell,
      'armsCm',
      'Average of both upper arms, flexed or relaxed',
      20,
      80,
    ),
    _StepConfig(
      'Thighs',
      'cm',
      LucideIcons.footprints,
      'thighsCm',
      'Average of both thighs at the widest point',
      30,
      100,
    ),
  ];

  int _currentStep = 0;
  final Map<String, double?> _values = {};
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance({bool skip = false}) {
    // Parse current value
    if (!skip) {
      final raw = _controller.text.trim();
      final v = double.tryParse(raw);
      _values[_steps[_currentStep].key] = v;
    } else {
      _values[_steps[_currentStep].key] = null;
    }

    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _controller.clear();
      });
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final payload = <String, dynamic>{'date': today};
      _values.forEach((key, value) {
        if (value != null) payload[key] = value;
      });

      final res = await ApiClient.logBodyMeasurement(payload);
      final result = BodyLogResult.fromJson(
        res['data'] as Map<String, dynamic>,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onLogged(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.cardDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;
    final progress = (_currentStep + 1) / _steps.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (_, __) => Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.borderDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'LOG MEASUREMENTS',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_currentStep + 1} / ${_steps.length}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.borderDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderDark),

          // Step content — AnimatedSwitcher gives fade + lift per step
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                // Incoming: fade in + rise from 24 px below
                // Outgoing: fade out + drift 16 px upward
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: Padding(
                // Key drives the switch when the step index changes
                key: ValueKey<int>(_currentStep),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + label
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            step.icon,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.label,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textCream,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'in ${step.unit}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textSageMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Text(
                      step.hint,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Input field
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              autofocus: true,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textCream,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: '0.0',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textSageMuted,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Text(
                              step.unit,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Actions
                    Row(
                      children: [
                        // Skip
                        GestureDetector(
                          onTap: () => _advance(skip: true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundDark,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderDark),
                            ),
                            child: Text(
                              'SKIP',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textSageMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Next / Submit
                        Expanded(
                          child: GestureDetector(
                            onTap: _submitting ? null : () => _advance(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: _submitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        isLast ? 'SUBMIT' : 'NEXT →',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppTheme.backgroundDark,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
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
          ),
        ],
      ),
    );
  }
}

class _StepConfig {
  final String label;
  final String unit;
  final IconData icon;
  final String key;
  final String hint;
  final double min;
  final double max;

  const _StepConfig(
    this.label,
    this.unit,
    this.icon,
    this.key,
    this.hint,
    this.min,
    this.max,
  );
}

// ─── XP Celebration Dialog ────────────────────────────────────────────────────

class _XpCelebrationDialog extends StatefulWidget {
  final BodyLogResult result;

  const _XpCelebrationDialog({required this.result});

  @override
  State<_XpCelebrationDialog> createState() => _XpCelebrationDialogState();
}

class _XpCelebrationDialogState extends State<_XpCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _xpCountAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _xpCountAnim =
        Tween<double>(begin: 0, end: widget.result.xpEarned.toDouble()).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(scale: _scaleAnim, child: child),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.trending_up,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Check-In Logged!',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep tracking your progress',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // XP earned
              AnimatedBuilder(
                animation: _xpCountAnim,
                builder: (_, _) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.xpGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.xpGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.zap,
                        color: AppTheme.xpGold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${_xpCountAnim.value.toInt()} XP',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.xpGold,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Level up badge
              if (widget.result.didLevelUp) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.levelArc],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '⬆ LEVEL UP → ${widget.result.levelLabel.toUpperCase()}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],

              // Achievement badges
              if (widget.result.newAchievements.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...widget.result.newAchievements.map(
                  (a) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.trophy,
                          color: AppTheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          a['name'] as String? ?? 'Achievement',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+${a['xpReward']} XP',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.xpGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'AWESOME!',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.backgroundDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
