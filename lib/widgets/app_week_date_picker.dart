import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

DateTime normalizeCalendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime currentWeekStart({DateTime? referenceDate}) {
  final today = normalizeCalendarDate(referenceDate ?? DateTime.now());
  return today.subtract(Duration(days: today.weekday - 1));
}

DateTime currentWeekDateForDayNumber(int dayNumber, {DateTime? referenceDate}) {
  final weekStart = currentWeekStart(referenceDate: referenceDate);
  final normalizedDayNumber = dayNumber < 1
      ? 1
      : dayNumber > 7
      ? 7
      : dayNumber;

  // Plan data uses Monday=1..Sunday=7 and the strip follows the same order.
  return weekStart.add(Duration(days: normalizedDayNumber - 1));
}

class AppWeekDatePicker extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onDateSelected;
  final EdgeInsetsGeometry padding;
  final DateTime? referenceDate;

  const AppWeekDatePicker({
    super.key,
    required this.selected,
    required this.onDateSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    this.referenceDate,
  });

  @override
  Widget build(BuildContext context) {
    final today = normalizeCalendarDate(referenceDate ?? DateTime.now());
    final selectedDate = normalizeCalendarDate(selected);
    final weekStart = currentWeekStart(referenceDate: today);
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final day = weekStart.add(Duration(days: index));
          final isToday = day == today;
          final isSelected = day == selectedDate;
          final isPast = day.isBefore(today);

          return Expanded(
            child: AppPressable(
              onPressed: () => onDateSelected(day),
              semanticsLabel: 'Select ${day.month}/${day.day}',
              selected: isSelected,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabels[index],
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? context.colors.primary.withValues(alpha: 0.18)
                          : AppTheme.transparent,
                      border: isToday && !isSelected
                          ? Border.all(
                              color: context.colors.primary,
                              width: 1.5,
                            )
                          : isPast && !isSelected
                          ? Border.all(
                              color: context.colors.border,
                              width: 1,
                              strokeAlign: BorderSide.strokeAlignCenter,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected
                            ? context.colors.primary
                            : isToday
                            ? context.colors.primary
                            : context.colors.textMuted,
                        fontSize: 13,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
