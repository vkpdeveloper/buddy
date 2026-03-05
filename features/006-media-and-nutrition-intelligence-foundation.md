# 006 - Media and Nutrition Intelligence Foundation

## Goal
Support photo-based meal logging and future AI nutrition analysis safely.

## Includes
- Meal photo attachments for logs.
- Cloudflare R2 private storage setup for meal images.
- AI-assisted meal analysis from photo (ingredients/calories estimation).
- Data model redesign for immutable raw meal log entries (generated and user-added).

## Frontend Plan
- Add meal photo capture/upload flow in meal logging.
- Show attachment state in meal log detail.
- Add AI analysis review UI (editable before save).

## Backend/Data Plan
- Integrate signed upload/download flow with private ACL in R2.
- Store media metadata linked to meal log entries.
- Build nutrition analysis pipeline output schema (ingredients, macros, confidence).
- Store both AI-estimated and user-corrected values for auditability.

## Dependencies
- Feature 002 meal log redesign.
- Image storage credentials and signing utilities.

## Acceptance Criteria
- Photos are private by default.
- User can log meals with image-backed nutrition data.
- Raw meal entries remain queryable for future AI learning loops.
