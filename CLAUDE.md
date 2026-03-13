# Buddy — Claude Code Guidelines

## Typography Rules (MUST follow on every UI change)

### Font Assignment

- **`GoogleFonts.sora`** — All large numeric displays (≥18px): calories, weight, XP, macros, steps, any number that is the "hero value" of a card. Also use for muted secondary numeric values (e.g. `/target`) for visual cohesion. Weight: `w600`.
- **`GoogleFonts.plusJakartaSans`** — Everything else: card titles, labels, body copy, captions, units, allcaps eyebrow text, empty states.

### Common mistakes to avoid

- Do NOT use `plusJakartaSans` for large numeric stats — use `sora`.
- Card titles should be **title-case** (e.g. "Weight Progress"), NOT allcaps. Allcaps is only for small 9–10px eyebrow labels.
- Units alongside numbers (kg, %, kcal) should be `plusJakartaSans`, smaller (10–12px), `textSageMuted` color.

### Typography Scale

| Role | Size | Font | Weight |
|---|---|---|---|
| Hero number (full-screen) | 48–52px | Sora | w600 |
| Primary stat in card | 26–30px | Sora | w600 |
| Secondary stat in card | 18–22px | Sora | w600 |
| Card title | 14px | Plus Jakarta Sans | w700 |
| Eyebrow label (allcaps) | 9–10px | Plus Jakarta Sans | w700, letterSpacing 1.4 |
| Body / description | 11–12px | Plus Jakarta Sans | w400–w500 |
| Caption / timestamp | 8–9px | Plus Jakarta Sans | w400–w500 |

---

## Card Shell Standard

All info cards use this decoration (do not deviate):

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
- Border radius: `20`
- Card title: `fontSize: 14`, `fontWeight: w700`, `color: AppTheme.textCream`, title-case

---

## Project

See `AGENTS.md` for full design context, brand personality, color tokens, and tech stack.
