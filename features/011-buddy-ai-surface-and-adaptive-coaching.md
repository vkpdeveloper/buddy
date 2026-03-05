# 011 - Buddy AI Surface and Adaptive Coaching

## Goal
Expose Buddy AI as a continuous coaching layer across workout and diet.

## Includes
- Buddy chat surface (dedicated screen or floating entry point).
- Daily AI tip card on Home.
- Weekly AI check-in summary every Sunday.
- Plan adjustment recommendations based on completion patterns.
- AI grocery list generation from weekly meal plan.

## Frontend Plan
- Implement chat UI entry using center icon.
- Add Home daily tip component with refresh cadence.
- Add weekly recap card/sheet with key metrics + one action.
- Add suggestion cards when skip/repeat behavior is detected.
- Add "Generate Grocery List" action in Diet weekly view.

## Backend/Data Plan
- Aggregate weekly metrics for recap generation.
- Build plan-adjustment trigger logic (e.g., skip exercise 3 weeks in a row).
- Add AI prompt orchestration layer for tips/check-ins/recommendations.
- Add grocery list generation endpoint with grouped quantities by category.

## Dependencies
- Session + nutrition + growth data quality.
- Stable AI integration contracts.

## Acceptance Criteria
- Users can ask Buddy questions in-app.
- Recaps and recommendations are tied to real user behavior.
