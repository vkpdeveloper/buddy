# 001 - Home Dashboard Core Experience

## Goal
Make Home instantly useful and personalized instead of static.

## Includes
- Composite health score: steps (40%), sleep (30%), active energy (20%), resting HR (10%).
- Today’s Agenda card: today workout + exercise count, next meal, water consumed.
- Contextual greeting: name + level + streak.
- Dynamic quick-action subtitles with real values.
- Weekly completion ring: workouts done vs weekly plan.
- Hydration card tap-to-log (+250 ml) with animated fill.

## Frontend Plan
- Replace static hero score computation with weighted inputs.
- Add agenda card below quick actions.
- Update header component to show level/streak badges.
- Quick action subtitle renderer reads today’s plan data.
- Add compact weekly progress ring near header.
- Make hydration card interactive with optimistic UI and animation.

## Backend/Data Plan
- Add/confirm daily aggregate endpoint with: sleep, active energy, resting HR, steps, hydration, next meal, today workout summary.
- Add/update hydration logging endpoint for increment action.
- Add weekly workout completion summary endpoint.

## Dependencies
- Workout and meal day summary APIs.
- Hydration logging storage.

## Acceptance Criteria
- Home renders real-time contextual values, not static labels.
- Health score changes with non-step metrics.
- Hydration tap updates both UI and persisted data.
