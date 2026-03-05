# 008 - UX Polish, Motion, and Theme Quality

## Goal
Add high-impact polish that improves feel without heavy feature cost.

## Includes
- Haptic feedback for set completion and achievements.
- Count-up micro-animations for Home stats.
- Consistent empty-state treatment across Workout, Diet, Growth.
- OLED optimization: targeted pure-black surfaces while preserving theme quality.

## Frontend Plan
- Trigger `lightImpact` and `mediumImpact` at key events.
- Add bounded number tween animations for dashboard stats.
- Build reusable empty-state component style and apply across tabs.
- Audit dark surfaces and selectively apply `#000000` where appropriate.

## Backend/Data Plan
- No backend changes required.

## Dependencies
- Existing event hooks (completion, achievement unlock).

## Acceptance Criteria
- Key interactions feel tactile and responsive.
- Empty states look intentional and consistent.
- Dark mode remains visually strong with improved OLED behavior.
