# Buddy — Project Guidelines

## Design Context

### Users

Everyday health-conscious people who want to feel better, stay consistent, and build healthy habits. They are not obsessed with metrics but are motivated by visible progress. When they open Buddy, they are in a check-in mindset — they want a quick read on how they're doing, a clear action to take, and to feel like they're on track. They don't want to think hard; they want confidence that the app is handling the complexity for them.

### Brand Personality

**Focused coach** — Direct, warm, and results-oriented. Buddy speaks clearly, never hypes, never lectures. It respects the user's time and intelligence. When it gives feedback, it feels like a trusted coach who knows your history — not a notification, not a cheerleader.

Three words: **Grounded. Precise. Warm.**

Emotional goals: confidence (I know where I stand), momentum (I can take action now), and quiet pride (this is working).

### Aesthetic Direction

**Dark & warm** — Deep near-black surfaces (#0A0B0D, #000000) with organic warmth from earthy accent tones (amber, sage, muted terracotta). Typography-led hierarchy using Sora for display and Plus Jakarta Sans for body. Whitespace is intentional — density is earned, not defaulted to.

Reference feeling: a well-designed journal meets a professional tool. Calm authority, not clinical coldness.

**Anti-references:**

- Not generic health app: no pastel gradients, rounded blobs, or stock-photo softness
- Not gamified to the point of feeling childish: XP and streaks exist but are subtle rewards, not the visual identity
- Not hype-marketing energy: no large motivational banners, no "LET'S GO" copy, no athlete lifestyle photography aesthetic

### Design Principles

1. **Clarity over completeness** — Show the most important thing first. Secondary data earns its place through hierarchy, not by being present. If it doesn't help the user decide or act, move it down or remove it.

2. **Warmth through restraint** — The warmth of the app comes from considered typography, breathing room, and subtle earthy tones — not from illustrations, mascots, or enthusiastic copy. Less decoration, more intention.

3. **Earned density** — Information density is allowed only where the user has context to interpret it (e.g., a chart in the Growth tab). In quick-glance contexts (Home dashboard), prefer summary over detail.

4. **Actions are never buried** — The primary action on any screen should be immediately visible and feel satisfying to tap. CTAs use high-contrast surfaces (`textMain` on `oledBlack`), never feel like an afterthought.

5. **Gamification is a reward, not a motif** — XP, levels, and streaks are meaningful feedback signals. They should feel like a quiet acknowledgment, not a visual centerpiece. The app is about health outcomes, not point accumulation.

---

## Tech Stack

- **Framework**: Flutter (Dart 3.10.8+)
- **State management**: Riverpod (hooks_riverpod)
- **Backend/auth**: Firebase (Auth, Firestore)
- **Fonts**: Sora (display/headings), Plus Jakarta Sans (body)
- **Icons**: flutter_lucide
- **Health data**: health package (HealthKit / Google Fit)
- **Theme file**: `lib/app_theme.dart`

## Typography Rules

These rules are enforced across all pages and must be followed when adding or editing any UI text.

### Font Assignment

| Use case | Font | Weight | Notes |
|---|---|---|---|
| Large numeric stats (≥18px) | `GoogleFonts.sora` | w600 | Calories, weight, XP, macros, any number that is the "hero" of a card |
| Card/section titles | `GoogleFonts.plusJakartaSans` | w700 | Title-case, not allcaps. e.g. "Weight Progress", not "WEIGHT PROGRESS" |
| Label/eyebrow text (small allcaps) | `GoogleFonts.plusJakartaSans` | w700 | Only used sparingly for category labels, letterSpacing 1.2–1.5 |
| Body / descriptive text | `GoogleFonts.plusJakartaSans` | w400–w500 | Captions, empty states, helper text |
| Units alongside numbers | `GoogleFonts.plusJakartaSans` | w600 | Smaller than number (10–12px), `textSageMuted` color |
| Muted secondary values (e.g. `/target`) | `GoogleFonts.sora` | w400 | Same family as the main number for visual cohesion |

### Card Shell Standard

All info cards use this decoration pattern (established by `_BmiCard`, now applied everywhere):

```dart
BoxDecoration(
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppTheme.borderDark.withValues(alpha: 0.95)),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A151B), Color(0xFF14161A), AppTheme.cardDark],
  ),
  boxShadow: [
    BoxShadow(
      color: AppTheme.shadowSoft.withValues(alpha: 0.28),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ],
)
```

- Padding: `EdgeInsets.fromLTRB(16, 16, 16, 14)`
- Card title: `fontSize: 14`, `fontWeight: w700`, `color: AppTheme.textCream`, title-case

### Typography Scale

| Role | Size | Font |
|---|---|---|
| Hero number (full-screen stat) | 48–52px | Sora w600 |
| Primary stat in card | 26–30px | Sora w600 |
| Secondary stat in card | 18–22px | Sora w600 |
| Card title | 14px | Plus Jakarta Sans w700 |
| Section label (allcaps eyebrow) | 9–10px | Plus Jakarta Sans w700, letterSpacing 1.4 |
| Body / descriptive | 11–12px | Plus Jakarta Sans w400–w500 |
| Captions / timestamps | 8–9px | Plus Jakarta Sans w400–w500 |

## Key Color Tokens

| Token            | Hex     | Use                   |
| ---------------- | ------- | --------------------- |
| `oledBlack`      | #000000 | Primary background    |
| `backgroundDark` | #0A0B0D | Fallback surface      |
| `cardDark`       | #0F1012 | Base card             |
| `cardRaised`     | #15171A | Elevated card         |
| `textCream`      | #E3E6EA | Primary text (AAA)    |
| `textMain`       | #C9CED5 | Body text (AAA)       |
| `textSageMuted`  | #939DAA | Muted/secondary (AAA) |
| `xpGold`         | #D4A853 | XP / rewards (AAA)    |
| `success`        | #6D927A | Positive feedback     |
| `warning`        | #B08F58 | Caution               |
| `error`          | #B36A6A | Errors                |
