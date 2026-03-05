# 012 - Advanced Training System (Supersets, Library, Regeneration)

## Goal
Support advanced program design and adaptive planning controls.

## Includes
- Supersets/circuits support in plan model and active workout flow.
- Onboarding question for supersets with plain-language explanation.
- Exercise library and custom exercise insertion.
- Plan regeneration with user constraints (e.g., injury-aware updates).
- PR system built from set-level data.

## Frontend Plan
- Extend onboarding with simple supersets preference capture.
- Add superset grouping visuals and controls in workout plan + active flow.
- Build exercise library browser/search and add-to-day interaction.
- Add regenerate-plan action with constraint input UX.
- Surface PR badges and PR history on exercise cards/pages.

## Backend/Data Plan
- Extend workout schema for grouped set structures.
- Add exercise catalog and user-defined exercise entities.
- Build regeneration endpoint with constraint-driven AI planning.
- Add PR computation jobs/queries using logged set loads.

## Dependencies
- Feature 003 logging foundation.
- AI planning pipeline updates.

## Acceptance Criteria
- Advanced users can train with supersets and customized exercise pools.
- Plan regeneration is accessible and constraint-aware.
- PRs are tracked automatically from session data.
