# 002 - Diet Tracking V1 (Macros, Timing, Logging)

## Goal
Turn Diet from checklist-only to measurable and flexible nutrition tracking.

## Includes
- Sticky daily macro progress bar (consumed vs target with macro segments).
- Meal timing timeline with explicit times.
- Drag-to-reorder meals (same day).
- "Log Actual" flow (instead of only mark done).
- Hydration tie-in validation with Home card.
- Pre-workout nutrition local notification (60 min before workout).

## Frontend Plan
- Add persistent top macro component under day tabs.
- Add horizontal day timeline with meal slots and selected state.
- Enable meal card reordering interactions.
- Add secondary action on meal card: "Log Actual".
- Add pre-workout nudge settings UI (on/off + lead time).

## Backend/Data Plan
- Support meal order updates (stable ordering field).
- Add meal log model for generated meals and user-modified actual intake.
- Store raw structured meal log payloads for future AI analysis.
- Sync hydration totals so Diet + Home remain consistent.
- Store notification preferences locally; schedule via Flutter local notifications.

## Dependencies
- Workout schedule time source.
- New meal log schema supporting flexible entries.

## Acceptance Criteria
- Users can see progress against daily macro targets clearly.
- Reordered meals persist after refresh.
- Users can log what they actually ate without replacing the plan.
