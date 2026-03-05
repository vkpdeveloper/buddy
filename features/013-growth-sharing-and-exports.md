# 013 - Growth Sharing and Exports

## Goal
Let users export progress snapshots for social or personal tracking.

## Includes
- Shareable progress image export (weight trend + achievements + streak).

## Frontend Plan
- Add export action in Growth.
- Provide template styles and preview before share/save.

## Backend/Data Plan
- Support deterministic image payload generation from current user stats.
- Optional server-side rendering path if client-side image composition is insufficient.

## Dependencies
- Growth metrics and achievements availability.

## Acceptance Criteria
- User can generate and share a clear progress summary image.
