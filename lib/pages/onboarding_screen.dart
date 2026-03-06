import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/providers/health_provider.dart';
import 'package:buddy/pages/fitness_onboarding.dart';
import 'package:buddy/widgets/app_snackbar.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentPage = 0;
  late final PageController _pageController = PageController();

  // Connection state
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _heartRateSynced = false;
  bool _sleepSynced = false;
  bool _caloriesSynced = false;
  bool _weightSynced = false;
  bool _heightSynced = false;

  // Page 2 - Core Metrics
  double _height = 182;
  double _weight = 78.5;
  DateTime _birthDate = DateTime(1996, 3, 12);
  String _sex = 'Male';

  // Page 3 - Baseline
  double _stepGoal = 10000;
  double _sleepTarget = 7.5;
  double _waterTargetMl = 2500;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  Future<void> _connectHealthData() async {
    setState(() => _isConnecting = true);

    try {
      final granted = await requestHealthPermissions(ref);
      if (!granted) {
        if (mounted) {
          setState(() => _isConnecting = false);
          AppSnackbar.info(
            context,
            'Health Connect permissions denied. You can grant them later in Settings.',
          );
        }
        _nextPage();
        return;
      }

      if (mounted) setState(() => _heartRateSynced = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _sleepSynced = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _caloriesSynced = true);
      await Future.delayed(const Duration(milliseconds: 200));

      ref.invalidate(latestWeightProvider);
      ref.invalidate(latestHeightProvider);
      ref.invalidate(todayStepsProvider);

      final weightResult = await ref.read(latestWeightProvider.future);
      if (weightResult != null && mounted) {
        setState(() {
          _weight = weightResult;
          _weightSynced = true;
        });
      }

      final heightResult = await ref.read(latestHeightProvider.future);
      if (heightResult != null && mounted) {
        setState(() {
          _height = heightResult;
          _heightSynced = true;
        });
      }

      final steps = await ref.read(todayStepsProvider.future);
      if (steps > 0 && mounted) {
        final avgSteps = (steps / 1000).round() * 1000;
        if (avgSteps >= 2000) {
          setState(() => _stepGoal = avgSteps.toDouble().clamp(2000, 25000));
        }
      }

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
      }

      await Future.delayed(const Duration(milliseconds: 600));
      _nextPage();
    } catch (_) {
      if (mounted) setState(() => _isConnecting = false);
      _nextPage();
    }
  }

  Future<void> _finalizeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    // Mark health onboarding done, but NOT full onboarding_completed yet
    await prefs.setDouble('step_goal', _stepGoal);
    await prefs.setDouble('sleep_target', _sleepTarget);
    await prefs.setInt('water_target_ml', _waterTargetMl.toInt());
    await prefs.setDouble('user_height', _height);
    await prefs.setDouble('user_weight', _weight);
    await prefs.setString('user_sex', _sex);
    await prefs.setString('user_birth_date', _birthDate.toIso8601String());

    if (!mounted) return;
    // Navigate to fitness onboarding extension (activity, equipment, diet goal)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FitnessOnboardingExtension(
          totalSteps: _totalSteps,
          startStep: 3,
          onComplete: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboarding_completed', true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _currentPage > 0 ? _previousPage : null,
                  child: AnimatedOpacity(
                    opacity: _currentPage > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        LucideIcons.chevron_left,
                        color: AppTheme.textSageMuted,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildPageHeader(_currentPage)),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSyncPage(),
                _buildCoreMetricsPage(),
                _buildBaselinePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PAGE 1: Sync Biometrics ───────────────────────────

  Widget _buildSyncPage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'CONNECT YOUR',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'HEALTH DATA',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We\'ll pull your stats from Health Connect so you don\'t have to type them all in manually.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _buildHealthConnectCard(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: Column(
            children: [
              _buildPrivacyFooter(),
              const SizedBox(height: 16),
              _isConnected
                  ? _buildPrimaryButton(
                      label: 'CONNECTED',
                      onTap: _nextPage,
                      icon: LucideIcons.circle_check,
                    )
                  : _isConnecting
                  ? _buildLoadingButton()
                  : _buildPrimaryButton(
                      label: 'CONNECT HEALTH DATA',
                      onTap: _connectHealthData,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.backgroundDark,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'SYNCING...',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.backgroundDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isConnected
              ? AppTheme.primary.withValues(alpha: 0.4)
              : AppTheme.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: _isConnecting
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primary,
                    ),
                  )
                : Icon(
                    _isConnected
                        ? LucideIcons.circle_check
                        : LucideIcons.heart_pulse,
                    color: AppTheme.primary,
                    size: 36,
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            'Health Connect',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isConnected ? 'CONNECTED' : 'TAP TO CONNECT',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          _buildCheckRow('Heart Rate', _heartRateSynced),
          Divider(color: AppTheme.borderDark, height: 24),
          _buildCheckRow('Sleep Data', _sleepSynced),
          Divider(color: AppTheme.borderDark, height: 24),
          _buildCheckRow('Active Calories', _caloriesSynced),
          if (_weightSynced || _heightSynced) ...[
            Divider(color: AppTheme.borderDark, height: 24),
            if (_weightSynced)
              _buildCheckRow('Weight (${_weight.toStringAsFixed(1)} kg)', true),
            if (_weightSynced && _heightSynced)
              Divider(color: AppTheme.borderDark, height: 24),
            if (_heightSynced)
              _buildCheckRow('Height (${_height.toStringAsFixed(0)} cm)', true),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, bool synced) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: synced ? AppTheme.textCream : AppTheme.textSageMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: synced
                ? Container(
                    key: const ValueKey('checked'),
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.check,
                      color: AppTheme.backgroundDark,
                      size: 14,
                    ),
                  )
                : Container(
                    key: const ValueKey('unchecked'),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyFooter() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          LucideIcons.shield,
          color: AppTheme.textSageMuted.withValues(alpha: 0.6),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your data stays on your device. We only read what you allow, and never share it.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted.withValues(alpha: 0.6),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ─── PAGE 2: Core Metrics ─────────────────────────────

  Widget _buildCoreMetricsPage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  'ABOUT YOU',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what we pulled from Health Connect. Tap any value to correct it.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSyncBadge(),
                const SizedBox(height: 24),
                _buildMetricCard(
                  label: 'HEIGHT',
                  value: _height.toStringAsFixed(0),
                  unit: 'CM',
                  synced: _heightSynced,
                  onTap: () => _showNumberPicker(
                    title: 'Height (cm)',
                    initial: _height,
                    min: 100,
                    max: 250,
                    onChanged: (v) => setState(() => _height = v),
                  ),
                ),
                const SizedBox(height: 12),
                _buildMetricCard(
                  label: 'WEIGHT',
                  value: _weight.toStringAsFixed(1),
                  unit: 'KG',
                  synced: _weightSynced,
                  onTap: () => _showNumberPicker(
                    title: 'Weight (kg)',
                    initial: _weight,
                    min: 30,
                    max: 200,
                    decimals: true,
                    onChanged: (v) => setState(() => _weight = v),
                  ),
                ),
                const SizedBox(height: 12),
                _buildMetricCard(
                  label: 'BIRTH DATE',
                  value: _formatDate(_birthDate),
                  unit: '',
                  icon: LucideIcons.calendar,
                  onTap: _showBirthDatePicker,
                ),
                const SizedBox(height: 24),
                Text(
                  'BIOLOGICAL SEX',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSexButton('Male', _sex == 'Male')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSexButton('Female', _sex == 'Female'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildPrimaryButton(label: 'CONTINUE', onTap: _nextPage),
        ),
      ],
    );
  }

  Widget _buildSyncBadge() {
    final isSynced = _isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSynced
            ? AppTheme.primary.withValues(alpha: 0.1)
            : AppTheme.textSageMuted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSynced
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.borderDark,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? LucideIcons.shield_check : LucideIcons.refresh_cw_off,
            color: isSynced ? AppTheme.primary : AppTheme.textSageMuted,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isSynced ? 'HEALTH DATA SYNCED' : 'NOT CONNECTED',
            style: GoogleFonts.plusJakartaSans(
              color: isSynced ? AppTheme.primary : AppTheme.textSageMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String unit,
    IconData? icon,
    bool synced = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          unit,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (icon != null)
              Icon(icon, color: AppTheme.textSageMuted, size: 20)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: synced
                      ? AppTheme.primary
                      : AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.check,
                  color: synced ? AppTheme.backgroundDark : AppTheme.primary,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSexButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _sex = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? AppTheme.textCream : AppTheme.textSageMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── PAGE 3: Baseline ─────────────────────────────────

  Widget _buildBaselinePage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final burnTarget = (_weight * 30).toInt();

    // Step values
    final stepValues = List.generate(47, (i) => 2000 + i * 500);
    final stepIndex = stepValues.indexWhere((v) => v >= _stepGoal.toInt());
    final stepDisplay = _stepGoal.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    // Sleep values: 4.0 to 12.0 in 0.5 steps
    final sleepValues = List.generate(17, (i) => 4.0 + i * 0.5);
    final sleepIndex = sleepValues.indexWhere((v) => v >= _sleepTarget);

    // Water values: 1500 to 4000 in 250 ml steps
    final waterValues = List.generate(11, (i) => 1500 + i * 250);
    final waterIndex = waterValues.indexWhere(
      (v) => v >= _waterTargetMl.toInt(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text(
                  'SET YOUR',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'DAILY GOALS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These set your daily targets. Tap any card to adjust. You can change them later in settings.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),
                _buildPickerCard(
                  label: 'DAILY STEP GOAL',
                  badge: 'ACTIVE',
                  displayValue: stepDisplay,
                  unit: 'steps',
                  onTap: () => _showDrumPicker(
                    title: 'Daily Step Goal',
                    labels: stepValues
                        .map(
                          (v) => v.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (m) => '${m[1]},',
                          ),
                        )
                        .toList(),
                    initialIndex: stepIndex < 0 ? 16 : stepIndex,
                    onConfirm: (i) =>
                        setState(() => _stepGoal = stepValues[i].toDouble()),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPickerCard(
                  label: 'SLEEP TARGET',
                  badge: 'RECOVERY',
                  displayValue: _sleepTarget.toStringAsFixed(1),
                  unit: 'hours',
                  onTap: () => _showDrumPicker(
                    title: 'Sleep Target',
                    labels: sleepValues
                        .map((v) => '${v.toStringAsFixed(1)} hrs')
                        .toList(),
                    initialIndex: sleepIndex < 0 ? 7 : sleepIndex,
                    onConfirm: (i) =>
                        setState(() => _sleepTarget = sleepValues[i]),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPickerCard(
                  label: 'DAILY WATER TARGET',
                  badge: 'HYDRATION',
                  displayValue: (_waterTargetMl / 1000).toStringAsFixed(1),
                  unit: 'L',
                  onTap: () => _showDrumPicker(
                    title: 'Daily Water Target',
                    labels: waterValues
                        .map(
                          (v) => '${(v / 1000).toStringAsFixed(1)} L  ($v ml)',
                        )
                        .toList(),
                    initialIndex: waterIndex < 0 ? 4 : waterIndex,
                    onConfirm: (i) => setState(
                      () => _waterTargetMl = waterValues[i].toDouble(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSmallMetric(
                  icon: LucideIcons.flame,
                  label: 'DAILY BURN',
                  value: '$burnTarget',
                  unit: 'kcal',
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildPrimaryButton(
            label: 'LOOKS GOOD, LET\'S GO',
            onTap: _finalizeSetup,
          ),
        ),
      ],
    );
  }

  Widget _buildPickerCard({
    required String label,
    required String badge,
    required String displayValue,
    required String unit,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        displayValue,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        unit,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.chevrons_up_down,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallMetric({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared Components ────────────────────────────────

  static const int _totalSteps = 8;

  Widget _buildPageHeader(int activeIndex) {
    return Row(
      children: List.generate(_totalSteps, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: i <= activeIndex ? AppTheme.primary : AppTheme.borderDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    IconData icon = LucideIcons.arrow_right,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.backgroundDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: AppTheme.backgroundDark, size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showBirthDatePicker() {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final now = DateTime.now();
    final minYear = 1940;
    final maxYear = now.year - 5;

    int selMonth = _birthDate.month; // 1-12
    int selDay = _birthDate.day;
    int selYear = _birthDate.year;

    int daysInMonth(int month, int year) {
      return DateTime(year, month + 1, 0).day;
    }

    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    final monthController = FixedExtentScrollController(
      initialItem: selMonth - 1,
    );
    final dayController = FixedExtentScrollController(initialItem: selDay - 1);
    final yearController = FixedExtentScrollController(
      initialItem: years.indexOf(selYear),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final dayCount = daysInMonth(selMonth, selYear);

            // Clamp day if month/year changes make current day invalid
            if (selDay > dayCount) {
              selDay = dayCount;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dayController.hasClients) {
                  dayController.jumpToItem(selDay - 1);
                }
              });
            }

            Widget column({
              required FixedExtentScrollController controller,
              required List<String> items,
              required ValueChanged<int> onChanged,
              double fontSize = 20,
            }) {
              return Expanded(
                child: CupertinoPicker(
                  backgroundColor: AppTheme.transparent,
                  itemExtent: 52,
                  scrollController: controller,
                  selectionOverlay: const SizedBox.shrink(),
                  onSelectedItemChanged: (i) {
                    onChanged(i);
                    setSheetState(() {});
                  },
                  children: items
                      .map(
                        (label) => Center(
                          child: Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            }

            return SizedBox(
              height: 420,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date of Birth',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Selection highlight bar
                        Positioned(
                          left: 24,
                          right: 24,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              column(
                                controller: monthController,
                                items: monthNames,
                                fontSize: 17,
                                onChanged: (i) => selMonth = i + 1,
                              ),
                              column(
                                controller: dayController,
                                items: List.generate(
                                  dayCount,
                                  (i) => (i + 1).toString().padLeft(2, '0'),
                                ),
                                onChanged: (i) => selDay = i + 1,
                              ),
                              column(
                                controller: yearController,
                                items: years.map((y) => y.toString()).toList(),
                                onChanged: (i) => selYear = years[i],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: GestureDetector(
                      onTap: () {
                        final clamped = selDay.clamp(
                          1,
                          daysInMonth(selMonth, selYear),
                        );
                        setState(() {
                          _birthDate = DateTime(selYear, selMonth, clamped);
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'CONFIRM',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.backgroundDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNumberPicker({
    required String title,
    required double initial,
    required double min,
    required double max,
    bool decimals = false,
    required ValueChanged<double> onChanged,
  }) {
    final step = decimals ? 0.5 : 1.0;
    final count = ((max - min) / step).round() + 1;
    final values = List.generate(count, (i) => min + i * step);
    final initialIndex = values.indexWhere((v) => (v - initial).abs() < 0.01);

    _showDrumPicker(
      title: title,
      labels: values
          .map((v) => decimals ? v.toStringAsFixed(1) : v.toStringAsFixed(0))
          .toList(),
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      onConfirm: (i) => onChanged(values[i]),
    );
  }

  void _showDrumPicker({
    required String title,
    required List<String> labels,
    required int initialIndex,
    required ValueChanged<int> onConfirm,
  }) {
    int selectedIndex = initialIndex;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 380,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: AppTheme.transparent,
                  itemExtent: 52,
                  scrollController: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  selectionOverlay: Container(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  onSelectedItemChanged: (i) => selectedIndex = i,
                  children: labels
                      .map(
                        (l) => Center(
                          child: Text(
                            l,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: GestureDetector(
                  onTap: () {
                    onConfirm(selectedIndex);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'CONFIRM',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.backgroundDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
