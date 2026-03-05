# 005 - Growth Tab Progression System

## Goal
Turn Growth into the main progress and motivation hub.

## Includes
- Header typography consistency.
- Weight trend sparkline in stats strip.
- Delta badges on metric cards (since last and since start).
- Progress photo comparison slider (first photo vs latest photo).
- Achievements gallery with lock/unlock + unlock date + XP.
- Level and XP card in Growth + compact top indicator on Home app bar.
- Body composition chart (fat mass vs lean mass).
- Goal tracking (target weight/body fat and remaining-to-go).
- Milestone celebrations for body records.

## Frontend Plan
- Align title styling with app standard.
- Add mini trend chart and delta components.
- Add achievements grid with status states.
- Add before/now photo slider with secure image selection.
- Add Level/XP panel and Home micro-badge.
- Add composition chart when required metrics exist.
- Add goal setup/edit UI and progress components.
- Trigger celebration modal on new body milestones.

## Backend/Data Plan
- Add derived metric calculators for delta and composition splits.
- Add achievements query API for Growth tab use.
- Add progress-photo metadata linkage to timeline entries.
- Add goals model and progress computation endpoint.
- Add milestone detector and XP reward event handling.

## Dependencies
- Growth history quality and completeness.
- Existing XP and achievement systems.

## Acceptance Criteria
- Growth communicates trend, goals, and rewards in one place.
- Users can define goals and see remaining distance clearly.
