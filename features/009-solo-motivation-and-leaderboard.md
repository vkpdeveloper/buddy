# 009 - Solo Motivation and Leaderboard Layer

## Goal
Increase engagement without requiring social graph infrastructure.

## Includes
- Personal "best week" leaderboard showing top 5 most active weeks.
- Phase 2 (deferred): daily challenges with small XP rewards.
- Phase 2 (deferred): streak protection tokens.

## Frontend Plan
- Add solo leaderboard section (likely Growth or Home extension).
- Show ranking metric (sessions, XP, or completion score) with quick context.

## Backend/Data Plan
- Build weekly aggregation job/query.
- Return top 5 historical weeks with comparable score model.

## Dependencies
- Reliable weekly activity metrics.

## Acceptance Criteria
- User can view their top active weeks and compare current week trajectory.
- Phase 2 is ready to be enabled without redesigning the core leaderboard model.
