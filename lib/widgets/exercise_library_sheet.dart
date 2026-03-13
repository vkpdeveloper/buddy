import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/exercise_catalog.dart';
import 'package:buddy/services/workout_service.dart';
import 'package:buddy/widgets/app_buttons.dart';
import 'package:buddy/widgets/app_card.dart';
import 'package:buddy/widgets/app_snackbar.dart';

const _muscleGroups = [
  'All',
  'Chest',
  'Back',
  'Legs',
  'Shoulders',
  'Arms',
  'Core',
];

Future<void> showExerciseLibrarySheet(
  BuildContext context, {
  required int dayId,
  required VoidCallback onAdded,
  int? replaceExerciseId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.cardDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ExerciseLibrarySheet(
      dayId: dayId,
      onAdded: onAdded,
      replaceExerciseId: replaceExerciseId,
    ),
  );
}

class _ExerciseLibrarySheet extends StatefulWidget {
  final int dayId;
  final VoidCallback onAdded;
  final int? replaceExerciseId;

  const _ExerciseLibrarySheet({
    required this.dayId,
    required this.onAdded,
    this.replaceExerciseId,
  });

  @override
  State<_ExerciseLibrarySheet> createState() => _ExerciseLibrarySheetState();
}

class _ExerciseLibrarySheetState extends State<_ExerciseLibrarySheet> {
  String _selectedGroup = 'All';
  List<ExerciseCatalogItem> _exercises = [];
  bool _isLoading = true;
  bool _isAdding = false;
  int? _pendingExerciseId;
  String? _loadError;
  int _catalogRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final requestId = ++_catalogRequestId;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final items = await WorkoutService.getExerciseCatalog(
        muscleGroup: _selectedGroup == 'All' ? null : _selectedGroup,
      );
      if (!mounted || requestId != _catalogRequestId) return;
      setState(() {
        _exercises = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _catalogRequestId) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load the exercise library.';
      });
    }
  }

  Future<void> _selectExercise(ExerciseCatalogItem item) async {
    if (_isAdding) return;
    setState(() {
      _isAdding = true;
      _pendingExerciseId = item.id;
    });
    try {
      if (widget.replaceExerciseId != null) {
        await WorkoutService.updateExercise(widget.replaceExerciseId!, {
          'name': item.name,
          'muscleGroup': item.muscleGroup,
          'notes': item.notes ?? '',
        });
      } else {
        await WorkoutService.addExerciseToDay(widget.dayId, item);
      }
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          widget.replaceExerciseId != null
              ? 'Could not swap exercise.'
              : 'Could not add exercise.',
        );
      }
    }
    if (mounted) {
      setState(() {
        _isAdding = false;
        _pendingExerciseId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final filterRailHeight =
        (AppTheme.minimumTouchTarget + ((textScale - 1) * 6))
            .clamp(44.0, 50.0)
            .toDouble();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Text(
                    widget.replaceExerciseId != null
                        ? 'Swap Exercise'
                        : 'Exercise Library',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AppBackButton(
                    icon: LucideIcons.x,
                    onPressed: () => Navigator.pop(context),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            // Muscle group filter chips
            SizedBox(
              height: filterRailHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _muscleGroups.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final group = _muscleGroups[i];
                  final isSelected = _selectedGroup == group;
                  return AppPressable(
                    onPressed: () {
                      if (_selectedGroup == group) return;
                      setState(() => _selectedGroup = group);
                      _loadExercises();
                    },
                    semanticsLabel: '$group muscle group filter',
                    selected: isSelected,
                    minHeight: AppTheme.minimumTouchTarget,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.backgroundDark,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.borderDark,
                        ),
                      ),
                      child: Text(
                        group,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected
                              ? AppTheme.oledBlack
                              : AppTheme.textSageMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody(scrollCtrl, bottomPad)),
          ],
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollCtrl, double bottomPad) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_loadError != null) {
      return _buildStateMessage(
        title: _loadError!,
        body: 'Check your connection and try again.',
        actionLabel: 'Try again',
        onPressed: _loadExercises,
      );
    }

    if (_exercises.isEmpty) {
      return _buildStateMessage(
        title: 'No exercises match this filter.',
        body: 'Try another muscle group.',
      );
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
      itemCount: _exercises.length,
      itemBuilder: (_, i) {
        final item = _exercises[i];
        final isPending = _pendingExerciseId == item.id;
        return Semantics(
          container: true,
          label: _exerciseSummary(item),
          child: AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textCream,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chip(
                              item.muscleGroup,
                              foregroundColor: AppTheme.textMain,
                              emphasis: true,
                            ),
                            _chip(
                              item.equipment,
                              foregroundColor: AppTheme.textSageMuted,
                            ),
                            _chip(
                              item.category,
                              foregroundColor: AppTheme.textMain,
                            ),
                          ],
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textMain,
                              fontSize: 11,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.videoLink != null) ...[
                        _actionButton(
                          label: 'Copy video link for ${item.name}',
                          icon: LucideIcons.youtube,
                          foregroundColor: AppTheme.textMain,
                          onPressed: () => _copyVideoLink(item),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _actionButton(
                        label: widget.replaceExerciseId != null
                            ? 'Swap with ${item.name}'
                            : 'Add ${item.name}',
                        icon: widget.replaceExerciseId != null
                            ? LucideIcons.refresh_cw
                            : LucideIcons.plus,
                        foregroundColor: AppTheme.textSageMuted,
                        onPressed: _isAdding
                            ? null
                            : () => _selectExercise(item),
                        isLoading: isPending,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyVideoLink(ExerciseCatalogItem item) async {
    if (item.videoLink == null) return;
    await Clipboard.setData(ClipboardData(text: item.videoLink!));
    if (!mounted) return;
    AppSnackbar.success(context, 'Video link copied');
  }

  Widget _buildStateMessage({
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 16),
              AppPressable(
                onPressed: onPressed,
                semanticsLabel: actionLabel,
                minHeight: AppTheme.minimumTouchTarget,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppTheme.cardRaised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color foregroundColor,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: label,
      child: AppPressable(
        onPressed: isLoading ? null : onPressed,
        semanticsLabel: label,
        minHeight: AppTheme.minimumTouchTarget,
        minWidth: AppTheme.minimumTouchTarget,
        borderRadius: BorderRadius.circular(AppTheme.minimumTouchTarget),
        decoration: BoxDecoration(
          color: AppTheme.oledBlack.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppTheme.minimumTouchTarget),
          border: Border.all(
            color: AppTheme.borderDark.withValues(alpha: 0.95),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : Icon(icon, color: foregroundColor, size: 18),
      ),
    );
  }

  String _exerciseSummary(ExerciseCatalogItem item) {
    final parts = [
      item.name,
      item.muscleGroup,
      item.equipment,
      item.category,
      if (item.description.isNotEmpty) item.description,
    ];
    return parts.join('. ');
  }

  Widget _chip(
    String label, {
    required Color foregroundColor,
    bool emphasis = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasis
            ? AppTheme.primary.withValues(alpha: 0.1)
            : AppTheme.oledBlack.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: emphasis
              ? AppTheme.primary.withValues(alpha: 0.22)
              : AppTheme.borderDark.withValues(alpha: 0.9),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: foregroundColor,
            fontSize: 9.5,
            fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
