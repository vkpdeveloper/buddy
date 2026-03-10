import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/gamification.dart';
import 'package:buddy/pages/login_page.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/services/notification_service.dart';
import 'package:buddy/services/profile_service.dart';
import 'package:buddy/widgets/app_snackbar.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? _profileData;
  bool _profileLoading = true;

  // Notification state
  bool _reminderEnabled = false;
  int _reminderLeadMinutes = 60;
  TimeOfDay _workoutTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNotificationSettings();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ProfileService.getProfile();
      if (mounted) {
        setState(() {
          _profileData = res['data'] as Map<String, dynamic>?;
          _profileLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final workoutRaw = prefs.getString('pre_workout_reminder_workout_time');
    if (!mounted) return;
    setState(() {
      _reminderEnabled = prefs.getBool('pre_workout_reminder_enabled') ?? false;
      _reminderLeadMinutes = prefs.getInt('pre_workout_reminder_lead') ?? 60;
      if (workoutRaw != null && workoutRaw.contains(':')) {
        final parts = workoutRaw.split(':');
        _workoutTime = TimeOfDay(
          hour: int.tryParse(parts.first) ?? 18,
          minute: int.tryParse(parts.last) ?? 0,
        );
      }
    });
  }

  Future<void> _updateReminder({
    bool? enabled,
    int? leadMinutes,
    TimeOfDay? workoutTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled != null) {
      _reminderEnabled = enabled;
      await prefs.setBool('pre_workout_reminder_enabled', enabled);
    }
    if (leadMinutes != null) {
      _reminderLeadMinutes = leadMinutes;
      await prefs.setInt('pre_workout_reminder_lead', leadMinutes);
    }
    if (workoutTime != null) {
      _workoutTime = workoutTime;
      final hh = workoutTime.hour.toString().padLeft(2, '0');
      final mm = workoutTime.minute.toString().padLeft(2, '0');
      await prefs.setString('pre_workout_reminder_workout_time', '$hh:$mm');
    }

    if (_reminderEnabled) {
      final granted = await NotificationService.requestPermission();
      if (!mounted) return;
      if (!granted) {
        _reminderEnabled = false;
        await SharedPreferences.getInstance().then(
          (p) => p.setBool('pre_workout_reminder_enabled', false),
        );
        AppSnackbar.error(context, 'Notification permission denied.');
        setState(() {});
        return;
      }
      try {
        await NotificationService.scheduleDailyPreWorkoutReminder(
          workoutTime: _workoutTime,
          leadMinutes: _reminderLeadMinutes,
        );
      } catch (e) {
        if (!mounted) return;
        AppSnackbar.error(context, 'Could not schedule reminder right now.');
      }
    } else {
      await NotificationService.cancelPreWorkoutReminder();
    }

    if (mounted) setState(() {});
  }

  Future<void> _openReminderSheet() async {
    var localEnabled = _reminderEnabled;
    var localLead = _reminderLeadMinutes;
    var localTime = _workoutTime;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REMINDER SETTINGS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pre-workout reminder',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: localEnabled,
                      activeThumbColor: AppTheme.primary,
                      onChanged: (v) async {
                        setS(() => localEnabled = v);
                        await _updateReminder(enabled: v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SettingRow(
                  title: 'Workout time',
                  value: localTime.format(ctx),
                  icon: LucideIcons.alarm_clock,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: localTime,
                    );
                    if (picked != null) {
                      setS(() => localTime = picked);
                      await _updateReminder(workoutTime: picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _SettingRow(
                  title: 'Reminder lead',
                  value: '$localLead min before',
                  icon: LucideIcons.clock_3,
                  onTap: () async {
                    final lead = await showModalBottomSheet<int>(
                      context: ctx,
                      backgroundColor: AppTheme.cardDark,
                      builder: (innerCtx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [30, 45, 60, 90]
                              .map(
                                (m) => ListTile(
                                  title: Text(
                                    '$m min before',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textCream,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: m == localLead
                                      ? const Icon(
                                          LucideIcons.check,
                                          color: AppTheme.primary,
                                          size: 16,
                                        )
                                      : null,
                                  onTap: () => Navigator.of(innerCtx).pop(m),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                    if (lead != null) {
                      setS(() => localLead = lead);
                      await _updateReminder(leadMinutes: lead);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.sora(
            color: AppTheme.textCream,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You\'ll need to sign in again to access your account.',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textSageMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final progress = ref.watch(progressProvider).asData?.value;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHero(context, user, progress, topPad),
            const SizedBox(height: 16),
            if (progress != null) ...[
              _buildXpCard(progress),
              const SizedBox(height: 12),
            ],
            _buildFitnessCard(),
            const SizedBox(height: 12),
            _buildGoalsCard(),
            const SizedBox(height: 12),
            _buildNotificationsCard(),
            const SizedBox(height: 12),
            _buildAccountCard(),
            const SizedBox(height: 24),
            _buildSignOutButton(),
            SizedBox(height: bottomPad + 32),
          ],
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero(
    BuildContext context,
    User? user,
    ProgressData? progress,
    double topPad,
  ) {
    final photoURL = user?.photoURL;
    final displayName = user?.displayName ?? 'Athlete';
    final email = user?.email ?? '';
    final creationTime = user?.metadata.creationTime;
    final memberSince = creationTime != null
        ? _formatMemberSince(creationTime)
        : null;
    final levelFraction = progress?.levelProgressFraction ?? 0.0;
    final level = progress?.currentLevel ?? 1;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 28),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primary.withValues(alpha: 0.08),
            AppTheme.oledBlack,
          ],
        ),
        border: const Border(bottom: BorderSide(color: AppTheme.borderDark)),
      ),
      child: Column(
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: const Icon(
                  LucideIcons.arrow_left,
                  color: AppTheme.textCream,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar with XP ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: CircularProgressIndicator(
                  value: levelFraction,
                  strokeWidth: 3.5,
                  backgroundColor: AppTheme.borderDark,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.xpGold),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardRaised,
                  border: Border.all(color: AppTheme.borderDark, width: 1.5),
                ),
                child: ClipOval(
                  child: photoURL != null && photoURL.isNotEmpty
                      ? Image.network(
                          photoURL,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => const Center(
                            child: Icon(
                              LucideIcons.user,
                              color: AppTheme.textSageMuted,
                              size: 42,
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            LucideIcons.user,
                            color: AppTheme.textSageMuted,
                            size: 42,
                          ),
                        ),
                ),
              ),
              // Level badge
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.oledBlack,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.xpGold.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    'LVL $level',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.xpGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            displayName,
            style: GoogleFonts.sora(
              color: AppTheme.textCream,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (memberSince != null) ...[
            const SizedBox(height: 6),
            Text(
              memberSince,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── XP / Level card ───────────────────────────────────────────────────────

  Widget _buildXpCard(ProgressData progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _StatPill(
                  icon: LucideIcons.flame,
                  iconColor: AppTheme.warning,
                  label: 'Streak',
                  value: '${progress.currentStreak}d',
                ),
                const SizedBox(width: 8),
                _StatPill(
                  icon: LucideIcons.shield,
                  iconColor: AppTheme.primary,
                  label: 'Level',
                  value: '${progress.currentLevel} · ${progress.levelLabel}',
                ),
                const SizedBox(width: 8),
                _StatPill(
                  icon: LucideIcons.zap,
                  iconColor: AppTheme.xpGold,
                  label: 'Total XP',
                  value: '${progress.totalXp}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress to ${_nextLevelLabel(progress.currentLevel)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(progress.levelProgressFraction * 100).toInt()}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.xpGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.levelProgressFraction,
                minHeight: 5,
                backgroundColor: AppTheme.borderDark,
                valueColor: const AlwaysStoppedAnimation(AppTheme.xpGold),
              ),
            ),
            if (progress.totalWorkoutsCompleted > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.trophy,
                    color: AppTheme.textSageMuted,
                    size: 12,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${progress.totalWorkoutsCompleted} total workouts completed',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Fitness Profile card ──────────────────────────────────────────────────

  Widget _buildFitnessCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _SectionCard(
        title: 'Fitness Profile',
        icon: LucideIcons.dumbbell,
        isLoading: _profileLoading,
        child: _profileData == null
            ? Text(
                'Complete your fitness profile to see details here.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 13,
                ),
              )
            : Column(
                children: [
                  _profileRow(
                    LucideIcons.target,
                    'Goal',
                    _goalLabel(_profileData!['goal']),
                  ),
                  _profileRow(
                    LucideIcons.trending_up,
                    'Experience',
                    _experienceLabel(_profileData!['experienceLevel']),
                  ),
                  _profileRow(
                    LucideIcons.activity,
                    'Activity Level',
                    _activityLabel(_profileData!['activityLevel']),
                  ),
                  _profileRow(
                    LucideIcons.ruler,
                    'Body Stats',
                    _bodyStats(_profileData),
                  ),
                  _profileRow(
                    LucideIcons.utensils,
                    'Diet',
                    _dietLabel(_profileData!['dietType']),
                  ),
                  _profileRow(
                    LucideIcons.calendar_days,
                    'Workout Days',
                    _workoutDays(_profileData),
                    isLast: _profileData!['equipment'] == null,
                  ),
                  if (_profileData!['equipment'] != null)
                    _profileRow(
                      LucideIcons.box,
                      'Equipment',
                      _equipmentLabel(_profileData!['equipment']),
                      isLast: true,
                    ),
                ],
              ),
      ),
    );
  }

  // ── Goals card ────────────────────────────────────────────────────────────

  Widget _buildGoalsCard() {
    if (_profileLoading || _profileData == null) return const SizedBox.shrink();

    final hasWeight = _profileData!['weightGoalKg'] != null;
    final hasBodyFat = _profileData!['bodyFatGoalPercent'] != null;
    final hasCurrent = _profileData!['currentBodyShape'] != null;
    final hasGoalShape = _profileData!['goalBodyShape'] != null;
    final hasWater = _profileData!['waterTargetMl'] != null;

    if (!hasWeight &&
        !hasBodyFat &&
        !hasCurrent &&
        !hasGoalShape &&
        !hasWater) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _SectionCard(
        title: 'Goals',
        icon: LucideIcons.flag,
        child: Column(
          children: [
            if (hasWeight)
              _profileRow(
                LucideIcons.scale,
                'Target Weight',
                '${(_profileData!['weightGoalKg'] as num).toStringAsFixed(1)} kg',
              ),
            if (hasBodyFat)
              _profileRow(
                LucideIcons.percent,
                'Body Fat Goal',
                '${(_profileData!['bodyFatGoalPercent'] as num).toStringAsFixed(1)}%',
              ),
            if (hasCurrent && hasGoalShape)
              _profileRow(
                LucideIcons.trending_up,
                'Body Shape',
                '${_shapeLabel(_profileData!['currentBodyShape'])} → ${_shapeLabel(_profileData!['goalBodyShape'])}',
              ),
            if (hasWater)
              _profileRow(
                LucideIcons.droplets,
                'Daily Water',
                '${_profileData!['waterTargetMl']} ml',
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }

  // ── Notifications card ────────────────────────────────────────────────────

  Widget _buildNotificationsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(
                    _reminderEnabled ? LucideIcons.bell_ring : LucideIcons.bell,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Workout Reminders',
                    style: GoogleFonts.sora(
                      color: AppTheme.textCream,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.borderDark, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily pre-workout reminder',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textCream,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _reminderEnabled
                              ? '${_workoutTime.format(context)} · $_reminderLeadMinutes min before'
                              : 'Tap to enable',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _reminderEnabled,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (v) => _updateReminder(enabled: v),
                  ),
                ],
              ),
            ),
            if (_reminderEnabled) ...[
              const Divider(
                color: AppTheme.borderDark,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              ListTile(
                dense: true,
                onTap: _openReminderSheet,
                leading: const Icon(
                  LucideIcons.settings_2,
                  color: AppTheme.primary,
                  size: 16,
                ),
                title: Text(
                  'Configure reminder time',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  LucideIcons.chevron_right,
                  color: AppTheme.textSageMuted,
                  size: 16,
                ),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ── Account card ──────────────────────────────────────────────────────────

  Widget _buildAccountCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.settings,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Account',
                    style: GoogleFonts.sora(
                      color: AppTheme.textCream,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.borderDark, height: 1),
            _accountRow(LucideIcons.shield, 'Privacy Policy', () {}),
            const Divider(
              color: AppTheme.borderDark,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            _accountRow(LucideIcons.message_circle, 'Send Feedback', () {}),
            const Divider(
              color: AppTheme.borderDark,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            ListTile(
              dense: true,
              leading: const Icon(
                LucideIcons.info,
                color: AppTheme.textSageMuted,
                size: 16,
              ),
              title: Text(
                'App Version',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 13,
                ),
              ),
              trailing: Text(
                '1.0.0',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountRow(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.primary, size: 16),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.textCream,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        LucideIcons.chevron_right,
        color: AppTheme.textSageMuted,
        size: 16,
      ),
    );
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(LucideIcons.log_out, size: 16),
          label: Text(
            'Sign Out',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _profileRow(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    if (value.isEmpty || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 14),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Formatters & Mappers ──────────────────────────────────────────────────

  String _formatMemberSince(DateTime dt) {
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
    return 'Member since ${months[dt.month - 1]} ${dt.year}';
  }

  String _nextLevelLabel(int currentLevel) {
    const names = [
      'Beginner',
      'Rookie',
      'Novice',
      'Apprentice',
      'Warrior',
      'Champion',
      'Elite',
      'Master',
      'Grand Master',
      'Legend',
    ];
    if (currentLevel >= names.length) return 'Max';
    return names[currentLevel];
  }

  static const _goalLabels = {
    'muscle_gain': 'Muscle Gain',
    'fat_loss': 'Fat Loss',
    'recomp': 'Body Recomp',
    'maintain': 'Maintain',
    'endurance': 'Endurance',
  };
  static const _activityLabels = {
    'sedentary': 'Sedentary',
    'lightly_active': 'Lightly Active',
    'moderately_active': 'Moderately Active',
    'very_active': 'Very Active',
    'athlete': 'Athlete',
  };
  static const _experienceLabels = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'advanced': 'Advanced',
  };
  static const _dietLabels = {
    'vegetarian': 'Vegetarian',
    'non_vegetarian': 'Non-Vegetarian',
    'vegan': 'Vegan',
  };
  static const _shapeLabels = {
    'skinny': 'Skinny',
    'lean': 'Lean',
    'fat': 'Overweight',
  };

  String _goalLabel(dynamic v) => _goalLabels[v] ?? (v?.toString() ?? '-');
  String _activityLabel(dynamic v) =>
      _activityLabels[v] ?? (v?.toString() ?? '-');
  String _experienceLabel(dynamic v) =>
      _experienceLabels[v] ?? (v?.toString() ?? '-');
  String _dietLabel(dynamic v) => _dietLabels[v] ?? (v?.toString() ?? '-');
  String _shapeLabel(dynamic v) => _shapeLabels[v] ?? (v?.toString() ?? '-');

  String _bodyStats(Map<String, dynamic>? d) {
    if (d == null) return '-';
    final parts = <String>[];
    if (d['age'] != null) parts.add('${d['age']} yrs');
    if (d['height'] != null) {
      parts.add('${(d['height'] as num).toStringAsFixed(0)} cm');
    }
    if (d['weight'] != null) {
      parts.add('${(d['weight'] as num).toStringAsFixed(1)} kg');
    }
    return parts.isEmpty ? '-' : parts.join(' · ');
  }

  String _workoutDays(Map<String, dynamic>? d) {
    if (d == null) return '-';
    final days = d['weeklyWorkoutDays'];
    final cycleLabel = const {
      'ppl': 'PPL',
      'upper_lower': 'Upper/Lower',
      'ppl_upper': 'PPL+Upper',
      'full_body': 'Full Body',
    }[d['workoutCycle']];
    if (days != null && cycleLabel != null)
      return '${days}x/week · $cycleLabel';
    if (days != null) return '${days}x/week';
    return '-';
  }

  String _equipmentLabel(dynamic v) {
    if (v == null) return '-';
    final list = v is List ? v : [v];
    return list
        .take(3)
        .map((e) {
          final s = e.toString().replaceAll('_', ' ');
          return s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '';
        })
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
}

// ── Supporting Widgets ─────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isLoading;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.sora(
                    color: AppTheme.textCream,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderDark, height: 1),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingRow({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $value',
      button: true,
      child: Material(
        color: AppTheme.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(icon, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
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
                        Text(
                          value,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevron_right,
                    color: AppTheme.textSageMuted,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
