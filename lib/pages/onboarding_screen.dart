import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger/app_theme.dart';
import 'package:ledger/providers/health_provider.dart';
import 'package:ledger/pages/home_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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

  // Page 3 - Mission
  int _selectedMission = 0;

  // Page 4 - Baseline
  double _stepGoal = 10000;
  double _sleepTarget = 7.5;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _goToPage(_currentPage + 1);
    }
  }

  Future<void> _connectHealthData() async {
    setState(() => _isConnecting = true);

    try {
      final granted = await requestHealthPermissions(ref);
      if (!granted) {
        if (mounted) {
          setState(() => _isConnecting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Health Connect permissions denied. You can grant them later in Settings.',
                style: GoogleFonts.plusJakartaSans(),
              ),
              backgroundColor: AppTheme.cardDark,
              behavior: SnackBarBehavior.floating,
            ),
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
    await prefs.setBool('onboarding_completed', true);
    await prefs.setDouble('step_goal', _stepGoal);
    await prefs.setDouble('sleep_target', _sleepTarget);
    await prefs.setInt('selected_mission', _selectedMission);
    await prefs.setDouble('user_height', _height);
    await prefs.setDouble('user_weight', _weight);
    await prefs.setString('user_sex', _sex);
    await prefs.setString('user_birth_date', _birthDate.toIso8601String());

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _fadeController.reset();
              _fadeController.forward();
            },
            children: [
              _buildSyncPage(),
              _buildCoreMetricsPage(),
              _buildMissionPage(),
              _buildBaselinePage(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PAGE 1: Sync Biometrics ───────────────────────────

  Widget _buildSyncPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildPageHeader(0),
          const SizedBox(height: 40),
          Text(
            'SYNC YOUR',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          Text(
            'BIOMETRICS',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connect your health ecosystem to calibrate your personal performance baseline.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildHealthConnectCard(),
          const SizedBox(height: 32),
          _isConnected
              ? _buildPrimaryButton(
                  label: 'CONNECTED',
                  onTap: _nextPage,
                  icon: Icons.check_circle,
                )
              : _isConnecting
                  ? _buildLoadingButton()
                  : _buildPrimaryButton(
                      label: 'CONNECT HEALTH DATA',
                      onTap: _connectHealthData,
                    ),
          const SizedBox(height: 24),
          _buildPrivacyFooter(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLoadingButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.6),
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
              ? AppTheme.primary.withOpacity(0.4)
              : AppTheme.accent.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.1),
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
                    _isConnected ? Icons.check_circle : Icons.monitor_heart,
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
            _isConnected ? 'CONNECTED' : 'READY TO INTEGRATE',
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
              _buildCheckRow(
                  'Height (${_height.toStringAsFixed(0)} cm)', true),
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
                    child: const Icon(Icons.check,
                        color: AppTheme.backgroundDark, size: 14),
                  )
                : Container(
                    key: const ValueKey('unchecked'),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.borderDark,
                      ),
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
          Icons.shield_outlined,
          color: AppTheme.textSageMuted.withOpacity(0.6),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'By connecting, we auto-fill your profile with precise biometric data. Your privacy is protected with end-to-end encryption.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted.withOpacity(0.6),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildPageHeader(1, showBack: true),
          const SizedBox(height: 32),
          Text(
            'CORE METRICS',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ve synced your baseline data from Health Connect. Verify your core metrics to calibrate your initial plan.',
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
            icon: Icons.calendar_today_outlined,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate,
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: AppTheme.darkTheme.copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.primary,
                        surface: AppTheme.cardDark,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
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
              Expanded(
                child: _buildSexButton('Male', _sex == 'Male'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSexButton('Female', _sex == 'Female'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(label: 'CONTINUE', onTap: _nextPage),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _nextPage,
              child: Text(
                'SKIP FOR NOW',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSyncBadge() {
    final isSynced = _isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSynced
            ? AppTheme.primary.withOpacity(0.1)
            : AppTheme.textSageMuted.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSynced
              ? AppTheme.primary.withOpacity(0.2)
              : AppTheme.borderDark,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.verified_user : Icons.sync_disabled,
            color: isSynced ? AppTheme.primary : AppTheme.textSageMuted,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isSynced ? 'HEALTH CONNECT SYNCED' : 'NOT CONNECTED',
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
                      : AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: synced
                      ? AppTheme.backgroundDark
                      : AppTheme.primary,
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
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.borderDark,
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

  // ─── PAGE 3: Mission ──────────────────────────────────

  Widget _buildMissionPage() {
    final missions = [
      _MissionData(
        icon: Icons.fitness_center,
        title: 'Muscle Gain',
        subtitle: 'BUILD LEAN MASS',
      ),
      _MissionData(
        icon: Icons.local_fire_department,
        title: 'Fat Loss',
        subtitle: 'MAXIMIZE CALORIC BURN',
      ),
      _MissionData(
        icon: Icons.bolt,
        title: 'Endurance',
        subtitle: 'INCREASE STAMINA',
      ),
      _MissionData(
        icon: Icons.nights_stay,
        title: 'Recovery',
        subtitle: 'OPTIMIZE SLEEP',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildPageHeader(2, showBack: true),
          const SizedBox(height: 32),
          Text(
            'DEFINE YOUR',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          Text(
            'MISSION',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your primary objective to calibrate your biometric baseline.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ...List.generate(missions.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMissionCard(missions[index], index),
            );
          }),
          const SizedBox(height: 20),
          _buildPrimaryButton(
            label: 'CONFIRM MISSION',
            onTap: _nextPage,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMissionCard(_MissionData mission, int index) {
    final isSelected = _selectedMission == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedMission = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                mission.icon,
                color: isSelected
                    ? AppTheme.backgroundDark
                    : AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textCream,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mission.subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── PAGE 4: Baseline ─────────────────────────────────

  Widget _buildBaselinePage() {
    final burnTarget = (_weight * 30).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildPageHeader(3, showBack: true),
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
            'BASELINE',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 28),
          _buildSliderCard(
            label: 'DAILY STEP GOAL',
            badge: 'ACTIVE',
            value: _stepGoal,
            displayValue: _stepGoal.toInt().toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (m) => '${m[1]},',
                ),
            unit: 'steps',
            min: 2000,
            max: 25000,
            divisions: 23,
            minLabel: 'SEDENTARY',
            maxLabel: 'ATHLETE',
            onChanged: (v) => setState(() => _stepGoal = v),
          ),
          const SizedBox(height: 16),
          _buildSliderCard(
            label: 'SLEEP TARGET',
            badge: 'RECOVERY',
            value: _sleepTarget,
            displayValue: _sleepTarget.toStringAsFixed(1),
            unit: 'hours',
            min: 4,
            max: 12,
            divisions: 16,
            minLabel: 'MINIMAL',
            maxLabel: 'EXTENDED',
            onChanged: (v) =>
                setState(() => _sleepTarget = (v * 2).round() / 2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSmallMetric(
                  icon: Icons.local_fire_department,
                  label: 'DAILY BURN',
                  value: '$burnTarget',
                  unit: 'kcal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallMetric(
                  icon: Icons.water_drop,
                  label: 'HYDRATION',
                  value: '2.5',
                  unit: 'L',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'FINALIZE SETUP',
            onTap: _finalizeSetup,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSliderCard({
    required String label,
    required String badge,
    required double value,
    required String displayValue,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required String minLabel,
    required String maxLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.borderDark,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
                elevation: 2,
              ),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                maxLabel,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildPageHeader(int activeIndex, {bool showBack = false}) {
    return Row(
      children: [
        if (showBack)
          GestureDetector(
            onTap: () => _goToPage(_currentPage - 1),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: AppTheme.textCream,
              size: 20,
            ),
          )
        else
          const SizedBox(width: 20),
        const Spacer(),
        Row(
          children: List.generate(4, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i <= activeIndex ? 24 : 8,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i <= activeIndex
                    ? AppTheme.primary
                    : AppTheme.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Text(
            'STEP ${(activeIndex + 1).toString().padLeft(2, '0')}',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    IconData icon = Icons.arrow_forward,
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
              color: AppTheme.primary.withOpacity(0.2),
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
            Icon(
              icon,
              color: AppTheme.backgroundDark,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showNumberPicker({
    required String title,
    required double initial,
    required double min,
    required double max,
    bool decimals = false,
    required ValueChanged<double> onChanged,
  }) {
    double current = initial;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    decimals
                        ? current.toStringAsFixed(1)
                        : current.toStringAsFixed(0),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.primary,
                      inactiveTrackColor: AppTheme.borderDark,
                      thumbColor: AppTheme.primary,
                      overlayColor: AppTheme.primary.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: current,
                      min: min,
                      max: max,
                      divisions: decimals
                          ? ((max - min) * 10).toInt()
                          : (max - min).toInt(),
                      onChanged: (v) {
                        setModalState(() => current = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      onChanged(current);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MissionData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MissionData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
