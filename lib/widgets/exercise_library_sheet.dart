import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/exercise_catalog.dart';
import 'package:buddy/services/workout_service.dart';
import 'package:buddy/widgets/app_snackbar.dart';

const _muscleGroups = ['All', 'Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];

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

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    try {
      final items = await WorkoutService.getExerciseCatalog(
        muscleGroup: _selectedGroup == 'All' ? null : _selectedGroup,
      );
      if (mounted) setState(() => _exercises = items);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _selectExercise(ExerciseCatalogItem item) async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
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
    if (mounted) setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
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
                    widget.replaceExerciseId != null ? 'Swap Exercise' : 'Exercise Library',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Close',
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(LucideIcons.x, color: AppTheme.textSageMuted, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            // Muscle group filter chips
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _muscleGroups.length,
                itemBuilder: (_, i) {
                  final group = _muscleGroups[i];
                  final isSelected = _selectedGroup == group;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '$group muscle group filter',
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedGroup = group);
                        _loadExercises();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : AppTheme.backgroundDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.borderDark,
                          ),
                        ),
                        child: Text(
                          group,
                          style: GoogleFonts.plusJakartaSans(
                            color: isSelected ? AppTheme.oledBlack : AppTheme.textSageMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _exercises.isEmpty
                  ? Center(
                      child: Text(
                        'No exercises found.',
                        style: GoogleFonts.plusJakartaSans(color: AppTheme.textSageMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 16),
                      itemCount: _exercises.length,
                      itemBuilder: (_, i) {
                        final item = _exercises[i];
                        return Semantics(
                          label: '${item.name}, ${item.muscleGroup}, ${item.equipment}. Double tap to add.',
                          child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                            title: Text(
                              item.name,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textCream,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _chip(item.muscleGroup, AppTheme.primary),
                                    const SizedBox(width: 6),
                                    _chip(item.equipment, AppTheme.accent),
                                    const SizedBox(width: 6),
                                    _chip(item.category, AppTheme.textSageMuted),
                                  ],
                                ),
                                if (item.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.description,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textSageMuted,
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.videoLink != null) ...[
                                  Tooltip(
                                    message: 'Copy video link for ${item.name}',
                                    child: Semantics(
                                      button: true,
                                      label: 'Copy video link for ${item.name}',
                                      child: GestureDetector(
                                        onTap: () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: item.videoLink!),
                                          );
                                          if (context.mounted) {
                                            AppSnackbar.success(
                                              context,
                                              'Video link copied',
                                            );
                                          }
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.accent.withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: const Icon(
                                            LucideIcons.youtube,
                                            color: AppTheme.accent,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Tooltip(
                                  message: widget.replaceExerciseId != null
                                      ? 'Swap with ${item.name}'
                                      : 'Add ${item.name}',
                                  child: Semantics(
                                    button: true,
                                    enabled: !_isAdding,
                                    label: widget.replaceExerciseId != null
                                        ? 'Swap with ${item.name}'
                                        : 'Add ${item.name}',
                                    child: GestureDetector(
                                      onTap: _isAdding ? null : () => _selectExercise(item),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.primary.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: const Icon(LucideIcons.plus, color: AppTheme.primary, size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
