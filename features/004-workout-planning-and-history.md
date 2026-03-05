# 004 - Workout Planning and Session History

## Goal
Make planning clearer and give full visibility into past training.

## Includes
- Muscle-group color coding on exercise cards.
- Estimated workout duration badge.
- Swipe-to-swap exercise with AI replacement rules.
- Workout Sessions page with history list + charts.
- Rest day tips become interactive (stretch timer, hydration quick-log).

## Frontend Plan
- Add muscle color token mapping and card accents.
- Show duration badge beside daily exercise count.
- Add swipe action UI and replacement confirmation.
- Build Sessions screen with filters, day summaries, and charts.
- Upgrade rest day card to micro-actions with timers.

## Backend/Data Plan
- Duration estimation service using sets/reps/rest model.
- Replacement API input must include day context, muscle group, and current exercise list to avoid duplicates.
- Session history endpoint with chart-ready time series (volume, duration, consistency).

## Dependencies
- Active workout logging (Feature 003).
- AI replacement service contract.

## Acceptance Criteria
- Users can inspect full workout history with trend charts.
- Exercise replacement avoids same-exercise suggestions.
- Rest days include actionable mini flows.
