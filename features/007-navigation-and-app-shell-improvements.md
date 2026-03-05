# 007 - Navigation and App Shell Improvements

## Goal
Improve cross-tab continuity and discoverability without overcomplicating nav.

## Includes
- Persist selected workout day index across tab switches.
- Add horizontal swipe gesture between main tabs.

## Frontend Plan
- Persist per-tab internal state (especially Workout day selection).
- Introduce `PageView` (or equivalent gesture layer) while preserving current nav behavior.
- Ensure gestures do not conflict with inner horizontal lists.

## Backend/Data Plan
- No backend changes required.

## Dependencies
- Existing bottom nav shell behavior.

## Acceptance Criteria
- Switching tabs no longer resets selected Workout day.
- Users can swipe across tabs consistently.
