# ZAR+ — DESIGN.md

Design system for the ZAR+ Flutter app (Material 3, Persian/RTL-first).
Extracted from `lib/features/theme/zar_theme.dart` (zar-tokens.css) — every
agent building or editing ZAR+ UI MUST follow this document. Source of truth
for code is `ZarTheme`/`ZarSemanticColors`; never hardcode values that exist
here.

## 1. Visual Theme & Atmosphere

Calm, trustworthy, gold-on-paper fintech for Iranian gold & FX shops. Warm
ivory paper in light mode, near-black warm charcoal in dark mode, one gold
accent reserved for primary actions and highlights. Persian-first: full RTL,
Vazirmatn everywhere, Persian digits in all user-facing numbers. Operational
(tool-like) density — not a marketing surface; decoration never competes with
legibility.

## 2. Color Palette & Roles

| Role | Light | Dark | Usage |
|---|---|---|---|
| Accent / primary | `#C08A3D` | `#D9A355` | Primary buttons, FAB, focus, highlights |
| On-accent | `#1F1300` | `#241600` | Text on accent |
| Primary container | `#F7E4C6` | `#5E4000` | Selected chips, tonal highlights |
| Scaffold | `#FBFAF8` | `#151515` | App background |
| Card / surface | `#FFFFFF` | `#1D1D1D` | Cards, sheets, dialogs |
| On-surface | `#1E1B16` | `#ECE7E0` | Primary text |
| On-surface-variant | `#605A50` | `#B8B0A4` | Secondary text |
| Outline | `#8B8378` | `#8F887E` | Icons, borders that must stay visible |
| Outline variant | `#ECEAE6` | `#2E2D2B` | Dividers, hairlines |
| Positive | `#1F7A50` | `#7FD6A6` | Gains, receipts, buy side (semantic extension) |
| Negative | `#B3261E` | `#FFB4AB` | Losses, pay side, destructive (semantic extension) |

Rules: semantic greens/reds come only from `ZarSemanticColors`
(`context.zarSemantic`) — buy/receive = positive, sell/pay = negative. Gold
accent is a brand/highlight color, never used to mean "profit".

## 3. Typography Rules

Font: **Vazirmatn** only (both languages/digits). All user-facing numbers are
Persian digits.

| Style | Size/height | Weight | Use |
|---|---|---|---|
| displaySmall | 32 / 44, ls -0.3 | w600 | Big cash totals |
| headlineSmall | 24 / 34 | w700 | Screen heroes |
| titleLarge | 20 / 30 | w700 | App bar / section titles |
| titleMedium | 16 / 24 | w600 | Card titles |
| titleSmall | 14 / 22 | w600 | Sub-titles |
| bodyLarge | 16 / 26 | w400 | Primary body |
| bodyMedium | 14 / 22 | w400 | Secondary body |
| bodySmall | 12 / 18 | w400 | Captions |
| labelLarge | 14 / 20 | w600 | Buttons |
| labelMedium | 12 / 16 | w600 | Chips/badges |
| labelSmall | 11 / 16 | w500 | Tiny metadata |

Never invent new sizes; pick from this scale. Amounts: integer minor units in
the domain, rendered with Persian digits and the unit label kept physically
before the number in RTL flow.

## 4. Component Stylings

- **Cards**: r16, elevation 0, margin 0 (padding comes from the parent), `card` color.
- **Inputs**: filled r14, fill `#F6F4F1` / `#242322`, no resting border, focused border accent 1.5, padding h14/v13.
- **Bottom sheets**: top radius 24, `card` color.
- **Chips**: r8, `surfaceContainer` background, selected = `secondaryContainer`, labelMedium.
- **App bar**: flat (elevation 0), scaffold background, title start-aligned (not centered).

## 5. Layout Principles

- RTL-first: TextDirection.rtl; chevrons physically point left; "start" = right.
- Minimum target width 360dp — every screen must fit without overflow.
- Touch targets ≥ 48×48dp.
- One clear section rhythm: title (titleLarge/titleMedium) → content card(s) →
  spacing 16; list paddings 16 horizontal, 8–12 vertical between rows.
- Empty states are quiet and actionable (a sentence + one button), never blank.

## 6. Depth & Elevation

Elevation 0 everywhere; hierarchy comes from surface tones
(`surfaceContainerLow` < `surfaceContainer` < `surfaceContainerHigh`) and
hairlines (`outlineVariant`), not shadows. The only shadows allowed are those
Material 3 gives sheets/dialogs natively.

## 7. Do's and Don'ts

DO: use `Theme.of(context)` / `context.zarSemantic`; keep Persian digits; keep
operational reports free of financial totals (accounting is out of scope);
test every screen at 360dp; keep ledger/deal semantics out of presentation
labels.

DON'T: hardcode colors or sizes; use English digits or LTR-only layouts;
invent new border radii (16 card / 14 input / 24 sheet / 8 chip); add shadows;
mix asset identities (a deal is one record even with multiple lines); render
customer-identifying data in notifications against the privacy setting.

## 8. Responsive Behavior

Phone-first portrait (390–360dp). The same layout must survive 600dp+ without
stretching: cap content width and keep navigation bottom-anchored. Bottom
navigation: home / سندوق / تقویم / اشخاص / تاریخچه with home selected.

## 9. Agent Prompt Guide

When asked to add or change a ZAR+ screen: "Build it with the existing
`ZarTheme` tokens, Persian digits, RTL start-aligned hierarchy, semantic
positive/negative from `ZarSemanticColors`, cards r16 without elevation, and
add widget tests that render at 360dp and assert the Persian labels."
